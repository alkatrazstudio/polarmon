// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:polar/polar.dart';

import '../util/time_util.dart';

class DeviceRecording {
  const DeviceRecording({
    required this.startedAt,
    required this.samples
  });
  
  final DateTime startedAt;
  final List<int> samples;
}

class DeviceRecordingStatus {
  const DeviceRecordingStatus({
    required this.startedAt,
    required this.isOngoing
  });

  final DateTime? startedAt;
  final bool isOngoing;
}

class EcgSample {
  const EcgSample({
    required this.timestamp,
    required this.voltage
  });

  final DateTime timestamp;
  final int voltage;
}

enum DeviceStatus {
  unknown,
  disconnected,
  connecting,
  connected
}

class Device {
  static final polar = Polar();
  static final features = <String, Map<PolarSdkFeature, Completer<void>>>{};
  static final statuses = <String, ValueNotifier<DeviceStatus>>{};
  static const exerciseIdPrefix = 'polarMon_';

  Device(this.dev) {
    refreshRecordingStatus();
  }

  final PolarDeviceInfo dev;
  final recordingStatus = ValueNotifier<DeviceRecordingStatus?>(null);

  static Completer<void> getFeatureCompleter(String deviceId, PolarSdkFeature feature) {
    var deviceFeatures = features.putIfAbsent(deviceId, () => {});
    var featureCompleter = deviceFeatures.putIfAbsent(feature, () => Completer<void>());
    return featureCompleter;
  }

  static ValueNotifier<DeviceStatus> getStatusNotifier(String deviceId) {
    var statusNotifier = statuses.putIfAbsent(deviceId, () => ValueNotifier(DeviceStatus.disconnected));
    return statusNotifier;
  }

  static void setStatus(String deviceId, DeviceStatus status) {
    var statusNotifier = getStatusNotifier(deviceId);
    statusNotifier.value = status;
  }

  static void startMonitoring() async {
    polar.sdkFeatureReady.listen((event) {
      var featureCompleter = getFeatureCompleter(event.identifier, event.feature);
      featureCompleter.complete();
      if(kDebugMode)
        print('FEATURE: ${event.feature.name}');
    });

    polar.deviceConnecting.listen((event) {
      if(kDebugMode)
        print('CONNECTING: ${event.deviceId}');
      setStatus(event.deviceId, DeviceStatus.connecting);
    });
    polar.deviceConnected.listen((event) {
      if(kDebugMode)
        print('CONNECTED: ${event.deviceId}');
      setStatus(event.deviceId, DeviceStatus.connected);
    });
    polar.deviceDisconnected.listen((event) {
      if(kDebugMode)
        print('DISCONNECTED: ${event.info.deviceId}');
      setStatus(event.info.deviceId, DeviceStatus.disconnected);
      features.remove(event.info.deviceId);
    });
  }

  Future<void> waitForFeature(PolarSdkFeature feature) async {
    var featureCompleter = getFeatureCompleter(dev.deviceId, feature);
    return featureCompleter.future;
  }

  static Future<Device> connectToFirst() async {
    await polar.requestPermissions();
    var dev = await polar.searchForDevice().first;
    await polar.connectToDevice(dev.deviceId);
    var device = Device(dev);
    return device;
  }
  
  static DateTime? timestampFromExerciseId(String exerciseId) {
    if(!exerciseId.startsWith(exerciseIdPrefix))
      return null;
    var dateStr = exerciseId.substring(exerciseIdPrefix.length);
    var timestamp = TimeUtil.strToTime(dateStr);
    return timestamp;
  }

  ///

  ValueNotifier<DeviceStatus> get statusNotifier => getStatusNotifier(dev.deviceId);

  Future<void> disconnect() async {
    await polar.disconnectFromDevice(dev.deviceId);
  }

  Stream<int> get batteryLevel async* {
    await waitForFeature(PolarSdkFeature.batteryInfo);
    yield* polar.batteryLevel.where((event) => event.identifier == dev.deviceId).map((event) => event.level);
  }

  Stream<int> _startHrStreaming() async* {
    await waitForFeature(PolarSdkFeature.onlineStreaming);
    try {
      await for(var data in polar.startHrStreaming(dev.deviceId)) {
        for(var sample in data.samples)
          yield sample.hr;
      }
    } catch(e) {
      //
    }
  }

  Stream<int> startHrStreaming() => _startHrStreaming().asBroadcastStream();

  Stream<Iterable<EcgSample>> _startEcgStreaming() async* {
    await waitForFeature(PolarSdkFeature.onlineStreaming);
    int? initialOffset;
    var allSettings = await polar.requestStreamSettings(dev.deviceId, PolarDataType.ecg);
    var maxSettings = allSettings.maxSettings();
    try {
      await for(var data in polar.startEcgStreaming(dev.deviceId, settings: maxSettings)) {
        initialOffset ??= DateTime.now().microsecondsSinceEpoch - data.samples.first.timeStamp.microsecondsSinceEpoch;
        var samples = data.samples.map(
          (sample) => EcgSample(
            timestamp: DateTime.fromMicrosecondsSinceEpoch(sample.timeStamp.microsecondsSinceEpoch + initialOffset!),
            voltage: sample.voltage
          )
        );
        yield samples;
      }
    } catch(e) {
      //
    }
  }

  Stream<Iterable<EcgSample>> startEcgStreaming() => _startEcgStreaming().asBroadcastStream();

  Future<PolarExerciseEntry?> getCurrentExercise() async {
    await waitForFeature(PolarSdkFeature.h10ExerciseRecording);
    var recs = await polar.listExercises(dev.deviceId);
    var rec = recs.firstOrNull;
    return rec;
  }

  Future<DeviceRecordingStatus> refreshRecordingStatus() async {
    await waitForFeature(PolarSdkFeature.h10ExerciseRecording);
    var recStatus = await polar.requestRecordingStatus(dev.deviceId);
    var startedAt = timestampFromExerciseId(recStatus.entryId);
    var status = DeviceRecordingStatus(
      startedAt: startedAt,
      isOngoing: recStatus.ongoing
    );
    recordingStatus.value = status;
    return status;
  }

  Future<void> deleteRecording() async {
    await waitForFeature(PolarSdkFeature.h10ExerciseRecording);
    var rec = await getCurrentExercise();
    if(rec != null)
      await polar.removeExercise(dev.deviceId, rec);
    await refreshRecordingStatus();
  }

  Future<void> startRecording() async {
    await waitForFeature(PolarSdkFeature.h10ExerciseRecording);
    await deleteRecording();
    var dateStr = TimeUtil.timeToStr(DateTime.now());
    var exerciseId = exerciseIdPrefix + dateStr;
    await polar.startRecording(
      dev.deviceId,
      exerciseId: exerciseId,
      interval: RecordingInterval.interval_1s,
      sampleType: SampleType.hr
    );
    await refreshRecordingStatus();
  }

  Future<void> stopRecording() async {
    await waitForFeature(PolarSdkFeature.h10ExerciseRecording);
    var status = await refreshRecordingStatus();
    if(status.isOngoing)
      await polar.stopRecording(dev.deviceId);
    await refreshRecordingStatus();
  }

  Future<DeviceRecording?> getRecording() async {
    await waitForFeature(PolarSdkFeature.h10ExerciseRecording);
    var rec = await getCurrentExercise();
    if(rec == null)
      return null;
    var recData = await polar.fetchExercise(dev.deviceId, rec);
    if(recData.samples.where((hr) => hr > 0).take(2).length < 2)
      return null;
    var startedAt = timestampFromExerciseId(rec.entryId);
    if(startedAt == null)
      return null;
    return DeviceRecording(
      startedAt: startedAt,
      samples: recData.samples
    );
  }
}
