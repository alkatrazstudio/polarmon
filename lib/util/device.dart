// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:polar/polar.dart';

import '../util/ecg_process.dart';
import '../util/time_util.dart';

class DeviceRecording {
  const DeviceRecording({
    required this.startedAt,
    required this.samples
  });

  final DateTime startedAt;
  final List<int> samples;

  DateTime get finishedAt => startedAt.add(Duration(seconds: samples.length));

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'samples': samples,
  };

  static DeviceRecording fromJson(Map<String, dynamic> json) => DeviceRecording(
    startedAt: DateTime.parse(json['startedAt'] as String),
    samples: (json['samples'] as List<dynamic>).map((s) => s as int).toList(),
  );
}

class DeviceRecordingStatus {
  const DeviceRecordingStatus({
    required this.startedAt,
    required this.isOngoing
  });

  final DateTime? startedAt;
  final bool isOngoing;

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt?.toIso8601String(),
    'isOngoing': isOngoing,
  };

  static DeviceRecordingStatus fromJson(Map<String, dynamic> json) => DeviceRecordingStatus(
    startedAt: json['startedAt'] == null ? null : DateTime.tryParse(json['startedAt'] as String),
    isOngoing: json['isOngoing'] as bool,
  );
}

enum DeviceStatus {
  unknown,
  disconnected,
  connecting,
  connected
}

class PolarState {
  var polar = Polar();
  var features = <String, Map<PolarSdkFeature, Completer<void>>>{};
  var statuses = <String, ValueNotifier<DeviceStatus>>{};

  static PolarState? _instance;

  static PolarState get instance => _instance ??= PolarState();
}

class Device {
  static const exerciseIdPrefix = 'polarMon_';

  Device(this.dev) {
    refreshRecordingStatus();
  }

  final PolarDeviceInfo dev;
  final recordingStatus = ValueNotifier<DeviceRecordingStatus?>(null);

  static Completer<void> getFeatureCompleter(String deviceId, PolarSdkFeature feature) {
    var deviceFeatures = PolarState.instance.features.putIfAbsent(deviceId, () => {});
    var featureCompleter = deviceFeatures.putIfAbsent(feature, () => Completer<void>());
    return featureCompleter;
  }

  static ValueNotifier<DeviceStatus> getStatusNotifier(String deviceId) {
    var statusNotifier = PolarState.instance.statuses.putIfAbsent(deviceId, () => ValueNotifier(DeviceStatus.disconnected));
    return statusNotifier;
  }

  static void setStatus(String deviceId, DeviceStatus status) {
    var statusNotifier = getStatusNotifier(deviceId);
    statusNotifier.value = status;
  }

  static void startMonitoring() {
    PolarState.instance.polar.sdkFeatureReady.listen((event) {
      var featureCompleter = getFeatureCompleter(event.identifier, event.feature);
      if(!featureCompleter.isCompleted)
        featureCompleter.complete();
      if(kDebugMode)
        print('FEATURE: ${event.feature.name}');
    });

    PolarState.instance.polar.deviceConnecting.listen((event) {
      if(kDebugMode)
        print('CONNECTING: ${event.deviceId}');
      setStatus(event.deviceId, DeviceStatus.connecting);
    });
    PolarState.instance.polar.deviceConnected.listen((event) {
      if(kDebugMode)
        print('CONNECTED: ${event.deviceId}');
      setStatus(event.deviceId, DeviceStatus.connected);
    });
    PolarState.instance.polar.deviceDisconnected.listen((event) {
      if(kDebugMode)
        print('DISCONNECTED: ${event.info.deviceId}');
      setStatus(event.info.deviceId, DeviceStatus.disconnected);
      PolarState.instance.features.remove(event.info.deviceId);
    });
  }

  Future<void> waitForFeature(PolarSdkFeature feature) async {
    var featureCompleter = getFeatureCompleter(dev.deviceId, feature);
    return featureCompleter.future;
  }

  static Future<void> requestPermissions() async {
    // copy-paste from Polar::requestPermissions()
    // to not create the Polar singleton
    if (Platform.isAndroid) {
      final androidDeviceInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidDeviceInfo.version.sdkInt;

      // If we are on Android M+
      if (sdkInt >= 23) {
        // If we are on an Android version before S
        if (sdkInt < 31) {
          await Permission.location.request();
        }
        // If we are on Android S+
        if (sdkInt >= 31) {
          await Permission.bluetoothScan.request();
          await Permission.bluetoothConnect.request();
        }
      }
    }
  }

  static Future<Device> connectToFirst() async {
    var dev = await PolarState.instance.polar.searchForDevice().first;
    await PolarState.instance.polar.connectToDevice(dev.deviceId, requestPermissions: false);
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
    await PolarState.instance.polar.disconnectFromDevice(dev.deviceId);
  }

  Stream<int> get batteryLevel async* {
    await waitForFeature(PolarSdkFeature.batteryInfo);
    yield* PolarState.instance.polar.batteryLevel.where((event) => event.identifier == dev.deviceId).map((event) => event.level);
  }

  Stream<int> _startHrStreaming() async* {
    await waitForFeature(PolarSdkFeature.onlineStreaming);
    try {
      await for(var data in PolarState.instance.polar.startHrStreaming(dev.deviceId)) {
        for(var sample in data.samples)
          yield sample.hr;
      }
    } catch(e) {
      //
    }
  }

  Stream<int> startHrStreaming() => _startHrStreaming().asBroadcastStream();

  Stream<EcgSample> _startEcgStreaming() async* {
    await waitForFeature(PolarSdkFeature.onlineStreaming);
    int? initialOffset;
    var allSettings = await PolarState.instance.polar.requestStreamSettings(dev.deviceId, PolarDataType.ecg);
    var maxSettings = allSettings.maxSettings();
    try {
      await for(var data in PolarState.instance.polar.startEcgStreaming(dev.deviceId, settings: maxSettings)) {
        initialOffset ??= DateTime.now().microsecondsSinceEpoch - data.samples.first.timeStamp.microsecondsSinceEpoch;
        for(var rawSample in data.samples) {
          var ecgSample = EcgSample(
            timestamp: DateTime.fromMicrosecondsSinceEpoch(rawSample.timeStamp.microsecondsSinceEpoch + initialOffset),
            voltage: rawSample.voltage,
          );
          yield ecgSample;
        }
      }
    } catch(e) {
      //
    }
  }

  Stream<HeartbeatWithIrregularity> _startHeartbeatStream() {
    var ecgStream = _startEcgStreaming();
    var beatsStream = ecgSamplesToHeartbeats(ecgStream);
    var irrBeatsStream = detectIrregularities(beatsStream);
    return irrBeatsStream;
  }

  Stream<HeartbeatWithIrregularity> startHeartbeatStream() => _startHeartbeatStream().asBroadcastStream();

  Future<PolarExerciseEntry?> getCurrentExercise() async {
    await waitForFeature(PolarSdkFeature.h10ExerciseRecording);
    await waitForFeature(PolarSdkFeature.fileTransfer);
    var recs = await PolarState.instance.polar.listExercises(dev.deviceId);
    var rec = recs.firstOrNull;
    return rec;
  }

  Future<DeviceRecordingStatus> refreshRecordingStatus() async {
    await waitForFeature(PolarSdkFeature.h10ExerciseRecording);
    await waitForFeature(PolarSdkFeature.fileTransfer);
    var recStatus = await PolarState.instance.polar.requestRecordingStatus(dev.deviceId);
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
    await waitForFeature(PolarSdkFeature.fileTransfer);
    var rec = await getCurrentExercise();
    if(rec != null)
      await PolarState.instance.polar.removeExercise(dev.deviceId, rec);
    await refreshRecordingStatus();
  }

  Future<void> startRecording() async {
    await waitForFeature(PolarSdkFeature.h10ExerciseRecording);
    await waitForFeature(PolarSdkFeature.fileTransfer);
    await deleteRecording();
    var dateStr = TimeUtil.timeToStr(DateTime.now());
    var exerciseId = exerciseIdPrefix + dateStr;
    await PolarState.instance.polar.startRecording(
      dev.deviceId,
      exerciseId: exerciseId,
      interval: RecordingInterval.interval_1s,
      sampleType: SampleType.hr
    );
    await refreshRecordingStatus();
  }

  Future<void> stopRecording() async {
    await waitForFeature(PolarSdkFeature.h10ExerciseRecording);
    await waitForFeature(PolarSdkFeature.fileTransfer);
    var status = await refreshRecordingStatus();
    if(status.isOngoing)
      await PolarState.instance.polar.stopRecording(dev.deviceId);
    await refreshRecordingStatus();
  }

  Future<DeviceRecording?> getRecording() async {
    await waitForFeature(PolarSdkFeature.h10ExerciseRecording);
    await waitForFeature(PolarSdkFeature.fileTransfer);
    var rec = await getCurrentExercise();
    if(rec == null)
      return null;
    var recData = await PolarState.instance.polar.fetchExercise(dev.deviceId, rec);
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
