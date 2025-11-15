// SPDX-License-Identifier: MPL-2.0

part of 'ecg_process.dart';

class EcgSample {
  const EcgSample({
    required this.timestamp,
    required this.voltage
  });

  final DateTime timestamp;
  final int voltage;

  int get tsMicroSecs => timestamp.microsecondsSinceEpoch;
  double get ts => tsMicroSecs / 1_000_000;
}

class Heartbeat {
  const Heartbeat({
    required this.samples,
    required this.rPeakIndex,
    required this.sPeakIndex,
    required this.qrsEndIndex,
  });

  final List<EcgSample> samples;
  final int rPeakIndex;
  final int sPeakIndex;
  final int qrsEndIndex;

  EcgSample get rPeak => samples[rPeakIndex];
  EcgSample get sPeak => samples[sPeakIndex];
  EcgSample get qrsEnd => samples[qrsEndIndex];

  int get zero => samples.first.voltage;
  int get rPeakAmplitude => rPeak.voltage - zero;
  int get sPeakAmplitude => zero - sPeak.voltage;

  double get rToSSecs => sPeak.ts - rPeak.ts;
  double get sToZeroSecs => qrsEnd.ts - sPeak.ts;
  double get fullSecs => samples.last.ts - samples.first.ts;

  int get microSecsStart => samples.first.tsMicroSecs;
  int get microSecsEnd => samples.last.tsMicroSecs;

  bool get isValid =>
    rPeakIndex > 0
      && sPeakIndex > 0
      && qrsEndIndex > 0
      && rPeakIndex < samples.length - 1
      && sPeakIndex < samples.length - 1
      && qrsEndIndex < samples.length - 1
      && rPeakAmplitude > 0
      && sPeakAmplitude > 0
      && sToZeroSecs > 0
      && fullSecs > 0
      && rToSSecs > 0;
}

enum IrregularityType {
  longFullDuration,
  highRAmplitude,
  highSAmplitude,
  lowRAmplitude,
  lowSAmplitude,
  longSToZeroDuration,
  rNotch,
}

class HeartbeatWithIrregularity {
  const HeartbeatWithIrregularity({
    required this.beat,
    required this.irregularityTypes,
  });

  final Heartbeat beat;
  final Set<IrregularityType> irregularityTypes;

  bool get isIrregular => beat.isValid && irregularityTypes.isNotEmpty;
}

class IrregularityWithContext {
  const IrregularityWithContext({
    required this.beats,
    required this.irregularBeatIndex,
  });

  final List<HeartbeatWithIrregularity> beats;
  final int irregularBeatIndex;

  Heartbeat get beat => beats[irregularBeatIndex].beat;
  Set<IrregularityType> get irregularityTypes => beats[irregularBeatIndex].irregularityTypes;
  bool get isIrregular => irregularityTypes.isNotEmpty;
}

enum DetectionStage {
  q,
  r,
  s,
  zero,
}

class AmnesicBuffer<T> {
  AmnesicBuffer(this.capacity): queue = QueueList<T>(capacity);

  final QueueList<T> queue;
  final int capacity;
  var _shift = 0;

  void add(T item) {
    if(queue.length == capacity) {
      queue.removeFirst();
      _shift++;
    }
    queue.add(item);
  }

  Iterable<T> getRange(int start, int end) {
    return queue.getRange(start - _shift, end - _shift);
  }

  T operator [](int i) => queue[i - _shift];
  int get length => queue.length + _shift;

  T getFromEnd(int i) => this[length - 1 - i];

  Iterable<T> fromEnd(int n) sync* {
    n = min(n, length);
    for(var i = 0; i < n; i++)
      yield getFromEnd(i);
  }

  A reduceFromEnd<A>(A acc, int n, A Function(A acc, T item) f) {
    for(var item in fromEnd(n))
      acc = f(acc, item);
    return acc;
  }

  R maxFromEnd<R extends num>(int n, R Function(T item) f) {
    var result = reduceFromEnd<R?>(null, n, (acc, item) {
      var val = f(item);
      if(acc == null || acc < val)
        acc = val;
      return acc;
    });
    return result!;
  }

  R minFromEnd<R extends num>(int n, R Function(T item) f) {
    var result = reduceFromEnd<R?>(null, n, (acc, item) {
      var val = f(item);
      if(acc == null || acc > val)
        acc = val;
      return acc;
    });
    return result!;
  }

  R percentileFromEnd<R extends num>(int n, double p, R Function(T item) f) {
    var items = fromEnd(n).map(f).toList();
    items.sort();
    var middleIndex = max(0, (items.length - 1) * p).ceil();
    return items[middleIndex];
  }

  R medianFromEnd<R extends num>(int n, R Function(T item) f) {
    return percentileFromEnd(n, 0.5, f);
  }
}

Stream<Heartbeat> ecgSamplesToHeartbeats(Stream<EcgSample> ecgStream) async* {
  const sampleRate = 130;
  const bufferLenSecs = 10;
  const maxSamplesInBuf = sampleRate * bufferLenSecs;
  const maxBeatSecs = 5;
  const maxSamplesPerBeat = sampleRate * maxBeatSecs;
  const minDx = 1 / (sampleRate * 2);
  const preQSamplesCount = 5;
  const postQSamplesCount = 1 * sampleRate;
  const preRSamplesCount = 1 * sampleRate;
  const qDerivativeThreshold = 200 * sampleRate;
  const qHardDerivativeThreshold = 300 * sampleRate;
  const qTwoConsecutiveDerivativeThreshold = 200 * sampleRate;
  const sRecoveryAllowedDiff = 30;
  const sRecoveryMinSecs = 0.1;
  const qMinDerivativeMultiplier = 10;
  const samplesCountToSteadilyRiseAfterS = 5;
  const secsForAverageZero = 0.1;
  const beatsForAverageZero = 5;
  const beatsForAverageRPeak = 5;
  const minRAmplitudeThreshold = 0.75;
  var samplesForAverageZero = (secsForAverageZero * sampleRate).ceil();
  var minDerivativesRequired = max(preQSamplesCount + postQSamplesCount, samplesCountToSteadilyRiseAfterS) + 1;
  var minSamplesRequired = samplesForAverageZero + preQSamplesCount + postQSamplesCount;
  var sRecoveryMinSamples = (sampleRate * sRecoveryMinSecs).round();

  var derivatives = AmnesicBuffer<double>(minDerivativesRequired);
  var buf = AmnesicBuffer<EcgSample>(maxSamplesInBuf);
  var stage = DetectionStage.q;
  EcgSample? prevSample;

  var beatCanBeYielded = false;
  var qStartIndex = 0;
  var rPeakIndex = 0;
  var sPeakIndex = 0;
  var qrsEndIndex = 0;
  var curZero = 0;
  var rAmplitudeMedian = 0;
  var rThreshold = 0;
  var rThresholdIsDetected = false;
  var rAmplitudeBuf = AmnesicBuffer<int>(beatsForAverageZero);

  Heartbeat? generateBeat(int newQStartIndex) {
    if(newQStartIndex <= qStartIndex)
      return null;
    var samples = buf.getRange(qStartIndex, newQStartIndex).toList();
    var beatRPeakIndex = rPeakIndex - qStartIndex;
    var beatSPeakIndex = sPeakIndex - qStartIndex;
    var beatQrsEndIndex = qrsEndIndex - qStartIndex;
    var lastIndex = samples.length - 1;
    beatRPeakIndex = max(min(beatRPeakIndex, lastIndex), 0);
    beatSPeakIndex = max(min(beatSPeakIndex, lastIndex), 0);
    beatQrsEndIndex = max(min(beatQrsEndIndex, lastIndex), 0);
    var beat = Heartbeat(
      samples: samples,
      rPeakIndex: beatRPeakIndex,
      sPeakIndex: beatSPeakIndex,
      qrsEndIndex: beatQrsEndIndex,
    );
    if(beat.isValid) {
      rAmplitudeBuf.add(beat.rPeakAmplitude);
      rAmplitudeMedian = rAmplitudeBuf.medianFromEnd(min(rAmplitudeBuf.length, beatsForAverageRPeak), (x) => x);
      rThreshold = (rAmplitudeMedian * minRAmplitudeThreshold).ceil();
      rThresholdIsDetected = true;
    }
    beatCanBeYielded = false;
    return beat;
  }

  await for(var sample in ecgStream) {
    try {
      if(prevSample == null) {
        prevSample = sample;
        continue;
      }
      var dx = sample.ts - prevSample.ts;
      if(dx <= minDx)
        continue;
      buf.add(sample);
      var dy = sample.voltage - prevSample.voltage;
      var d = dy / dx;
      derivatives.add(d);
      prevSample = sample;
      if(derivatives.length < minDerivativesRequired)
        continue;
      if(buf.length < minSamplesRequired)
        continue;

      if(buf.length - qStartIndex >= maxSamplesPerBeat) {
        var newQStartIndex = buf.length - 1;
        var beat = generateBeat(newQStartIndex);
        if(beat != null)
          yield beat;
        qStartIndex = newQStartIndex;
        stage = DetectionStage.q;
      }

      switch(stage) {
        case DetectionStage.q:
          var dAvg = derivatives.medianFromEnd(preQSamplesCount, (d) => d.abs());
          var dThreshold = dAvg * qMinDerivativeMultiplier;
          for(var i = 1; i <= postQSamplesCount; i++) {
            var dIndex = buf.length - i;
            var qd = derivatives[dIndex];
            if(
              (
                (qd > dThreshold && qd > qDerivativeThreshold)
                  || qd > qHardDerivativeThreshold
                  || (derivatives.getFromEnd(0) + derivatives.getFromEnd(1)) > qTwoConsecutiveDerivativeThreshold
              )
              && (dIndex - rPeakIndex) > sRecoveryMinSamples
            ) {
              // found Q
              late int newQStartIndex;
              for(var i = 1; i <= preQSamplesCount; i++) {
                newQStartIndex = dIndex - i;
                if(derivatives[newQStartIndex] < 0)
                  break;
              }
              curZero = buf[newQStartIndex].voltage;
              if(beatCanBeYielded) {
                var beat = generateBeat(newQStartIndex);
                if(beat != null)
                  yield beat;
              }
              qStartIndex = newQStartIndex;
              stage = DetectionStage.r;
              break;
            }
          }

          // trying to detect R-peak
          if(rThresholdIsDetected && d < 0 && derivatives.getFromEnd(1) >= 0) {
            var curAmplitude = buf.getFromEnd(1).voltage - curZero;
            if(curAmplitude > rThreshold) {
              // found R
              late int newQStartIndex;
              var peakIndex = buf.length - 1;
              for(var i = 1; i <= preRSamplesCount; i++) {
                newQStartIndex = peakIndex - i;
                if(buf[newQStartIndex].voltage < curZero)
                  break;
              }
              if(beatCanBeYielded) {
                var beat = generateBeat(newQStartIndex);
                if(beat != null)
                  yield beat;
              } else {
                print(sample.ts);
              }
              qStartIndex = newQStartIndex;
              rPeakIndex = buf.length - 2;
              stage = DetectionStage.s;
            }
          }
          break;

        case DetectionStage.r:
          if(d < 0) {
            // found R
            rPeakIndex = buf.length - 2;
            stage = DetectionStage.s;
          }
          break;

        case DetectionStage.s:
          if(d > 0) {
            // found S
            sPeakIndex = buf.length - 2;
            stage = DetectionStage.zero;
          }
          break;

        case DetectionStage.zero:
          var v = buf[buf.length - 1].voltage;
          if(v > (curZero - sRecoveryAllowedDiff)) {
            // found zero
            qrsEndIndex = buf.length - 1;
            stage = DetectionStage.q;
            beatCanBeYielded = true;
          }
          break;
      }
    } catch(e) {
      print(e);
      beatCanBeYielded = false;
    }
  }
}

Stream<HeartbeatWithIrregularity> detectIrregularities(Stream<Heartbeat> beatsStream) async* {
  const normalizationBeatsCountToTestAgainst = 5;
  const normalizationBeatsCountToTest = 3;
  const beatsCountForAverage = 20;
  const highRAmplitudeThreshold = 1.25;
  const highSAmplitudeThreshold = 1.5;
  const lowAmplitudeThreshold = 0.75;
  const sToZeroDurationThreshold = 2.5;
  const fullDurationThreshold = 1.5;

  var beatsBufferLen = max(normalizationBeatsCountToTestAgainst, beatsCountForAverage);
  var buf = AmnesicBuffer<Heartbeat>(beatsBufferLen);

  late bool isNormalized;
  late int normalizationBeatsLeft;
  late int normalizationBeatsLeftToTest;
  late int maxRPeakForNormalizationTest;
  late int minSPeakForNormalizationTest;
  late bool peaksForNormalizationAreSet;

  void requireNormalization() {
    isNormalized = false;
    normalizationBeatsLeft = normalizationBeatsCountToTestAgainst;
    normalizationBeatsLeftToTest = normalizationBeatsCountToTest;
    peaksForNormalizationAreSet = false;
  }

  Set<IrregularityType> detect(Heartbeat beat) {
    if(!beat.isValid) {
      requireNormalization();
      return {};
    }
    if(!isNormalized) {
      if(normalizationBeatsLeft > 0) {
        normalizationBeatsLeft--;
        return {};
      } else {
        if(!peaksForNormalizationAreSet) {
          maxRPeakForNormalizationTest = buf.maxFromEnd(normalizationBeatsCountToTestAgainst, (beat) => beat.rPeak.voltage);
          minSPeakForNormalizationTest = buf.minFromEnd(normalizationBeatsCountToTestAgainst, (beat) => beat.sPeak.voltage);
        }
      }
      if(beat.rPeak.voltage > maxRPeakForNormalizationTest || beat.sPeak.voltage < minSPeakForNormalizationTest) {
        requireNormalization();
        return {};
      }
      normalizationBeatsLeftToTest--;
      if(normalizationBeatsLeftToTest == 0) {
        isNormalized = true;
      }
    }

    var irregularities = <IrregularityType>{};
    late int rPeakMaxCmp;
    late int rPeakMinCmp;
    late int sPeakMaxCmp;
    late int sPeakMinCmp;
    late double sToZeroDurationCmp;
    late double fullDurationCmp;
    var cmpIsReady = false;
    if(buf.length >= beatsCountForAverage) {
      rPeakMaxCmp = buf.percentileFromEnd(beatsCountForAverage, 0.75, (beat) => beat.rPeakAmplitude);
      rPeakMinCmp = buf.percentileFromEnd(beatsCountForAverage, 0.25, (beat) => beat.rPeakAmplitude);
      sPeakMaxCmp = buf.percentileFromEnd(beatsCountForAverage, 0.75, (beat) => beat.sPeakAmplitude);
      sPeakMinCmp = buf.percentileFromEnd(beatsCountForAverage, 0.25, (beat) => beat.sPeakAmplitude);
      sToZeroDurationCmp = buf.percentileFromEnd(beatsCountForAverage, 0.75, (beat) => beat.sToZeroSecs);
      fullDurationCmp = buf.percentileFromEnd(beatsCountForAverage, 0.75, (beat) => beat.fullSecs);
      cmpIsReady = true;
    }
    if(cmpIsReady) {
      if(beat.rPeakAmplitude > rPeakMaxCmp * highRAmplitudeThreshold)
        irregularities.add(IrregularityType.highRAmplitude);
      else if(beat.rPeakAmplitude < rPeakMinCmp * lowAmplitudeThreshold)
        irregularities.add(IrregularityType.lowRAmplitude);
      if(beat.sPeakAmplitude > sPeakMaxCmp * highSAmplitudeThreshold)
        irregularities.add(IrregularityType.highSAmplitude);
      else if(beat.sPeakAmplitude < sPeakMinCmp * lowAmplitudeThreshold)
        irregularities.add(IrregularityType.lowSAmplitude);
      if(beat.sToZeroSecs > sToZeroDurationCmp * sToZeroDurationThreshold)
        irregularities.add(IrregularityType.longSToZeroDuration);
      if(beat.fullSecs > fullDurationCmp * fullDurationThreshold)
        irregularities.add(IrregularityType.longFullDuration);
    }
    for(var i = 1; i < beat.rPeakIndex; i++) {
      var d = beat.samples[i].voltage - beat.samples[i - 1].voltage;
      if(d < 0) {
        irregularities.add(IrregularityType.rNotch);
        break;
      }
    }

    return irregularities;
  }

  requireNormalization();
  await for(var beat in beatsStream) {
    try {
      var irregularityTypes = detect(beat);
      if(beat.isValid)
        buf.add(beat);
      yield HeartbeatWithIrregularity(
        beat: beat,
        irregularityTypes: irregularityTypes
      );
    } catch(e) {
      print(e);
      requireNormalization();
    }
  }
}
