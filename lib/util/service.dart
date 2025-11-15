// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../util/device.dart';
import '../util/ecg_process.dart';
import '../util/locale_manager.dart';
import '../util/memory_file.dart';

@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(Service());
}

class StreamWrapper<T> {
  StreamWrapper();

  StreamWrapper.init({
    required this.stream,
    required this.writeToMemoryFile,
  });

  late final Stream<T> stream;
  late final void Function(T item, MemoryFile file) writeToMemoryFile;

  void writeToMemoryFileDynamic(dynamic item, MemoryFile file) {
    var x = item as T;
    writeToMemoryFile(x, file);
  }
}

class NotifierWrapper<T> extends StreamWrapper<T> {
  NotifierWrapper({
    required this.notifier,
    required void Function(T item, MemoryFile file) writeToMemoryFile
  }):
    controller = StreamController<T>()
  {
    notifier.addListener(listener);
    controller.onCancel = () => notifier.removeListener(listener);
    controller.add(notifier.value);
    stream = controller.stream.asBroadcastStream();
    this.writeToMemoryFile = writeToMemoryFile;
  }

  StreamController<T> controller;
  ValueNotifier<T> notifier;

  void listener() {
    var value = notifier.value;
    controller.add(value);
  }

  void emitCurrentValue() {
    controller.add(notifier.value);
  }
}

class Service extends TaskHandler {
  static const btnReset = 'reset';
  static const btnStop = 'stop';

  static final _completers = <int, Completer>{};
  static final _streamControllers = <int, StreamController<MemoryFile>>{};
  static final rnd = Random();

  static Future<void>? _startFuture;
  static DeviceServer? server;

  //
  // FROM APP
  //

  static Future<void> _start(BuildContext context) async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(onReceiveTaskData);
    if(await FlutterForegroundTask.isRunningService)
      return;
    await requestPermissions();

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'polarmon',
        channelName: 'PolarMon',
        onlyAlertOnce: true,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    await FlutterForegroundTask.startService(
      serviceTypes: [
         ForegroundServiceTypes.health,
      ],
      serviceId: 1,
      notificationTitle: 'PolarMon',
      notificationText: '',
      notificationIcon: const NotificationIcon(
        metaDataName: 'net.alkatrazstudio.polarmon.NOTIFICATION_ICON',
        backgroundColor: Color.fromARGB(255, 251, 86, 59),
      ),
      notificationButtons: [
        NotificationButton(id: btnReset, text: L(context).serviceReset),
        NotificationButton(id: btnStop, text: L(context).serviceStop),
      ],
      notificationInitialRoute: '/',
      callback: _startCallback,
    );
  }

  static Future<void> start(BuildContext context) async {
    return _startFuture ??= _start(context);
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
    _startFuture = null;
  }

  static Future<void> requestPermissions() async {
    if(await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted)
      await FlutterForegroundTask.requestNotificationPermission();
    if(!await FlutterForegroundTask.isIgnoringBatteryOptimizations)
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    if(!await FlutterForegroundTask.canScheduleExactAlarms)
      await FlutterForegroundTask.openAlarmsAndRemindersSettings();
    await Device.requestPermissions();
  }

  static void onReceiveTaskData(Object data) {
    if(data is String) {
      var payload = jsonDecode(data) as Map<String, dynamic>;
      var funcId = payload['id'] as int;
      var completer = _completers[funcId];
      if(completer == null)
        return;
      if(payload.containsKey('error')) {
        var err = Exception(payload['error'] as String);
        completer.completeError(err);
        var controller = _streamControllers[funcId];
        controller?.addError(err);
      } else {
        completer.complete(payload['result']);
      }
      _completers.remove(funcId);
    } else if(data is TransferableTypedData) {
      var buffer = data.materialize();
      var memFile = MemoryFile(buffer: buffer);
      memFile.seek(-8);
      var funcId = memFile.readInt();
      var controller = _streamControllers[funcId];
      if(controller == null)
        return;
      memFile.seek(0);
      controller.add(memFile);
    }
  }

  static int randomFuncId() {
    var id = rnd.nextInt(1 << 31 - 1) * (1 << 32) + rnd.nextInt(1 << 32);
    return id;
  }

  static Future<dynamic> call(String funcName, [Map<String, dynamic>? args]) {
    var funcId = randomFuncId();
    var payload = {
      'id': funcId,
      'name': funcName,
      'args': args
    };
    var json = jsonEncode(payload);
    var completer = _completers[funcId] = Completer();
    FlutterForegroundTask.sendDataToTask(json);
    return completer.future;
  }

  static Stream<T> stream<T>(
    String funcName,
    Map<String, dynamic>? args,
    T Function(MemoryFile memFile) mapFunc,
  ) {
    var funcId = randomFuncId();
    var payload = {
      'id': funcId,
      'name': funcName,
      'args': args,
    };
    var json = jsonEncode(payload);
    var controller = _streamControllers[funcId] = StreamController<MemoryFile>();
    FlutterForegroundTask.sendDataToTask(json);
    return controller.stream.map(mapFunc).asBroadcastStream();
  }

  //
  // FROM TASK
  //

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    Device.startMonitoring();
  }

  @override
  void onNotificationButtonPressed(String id) {
    switch(id) {
      case btnReset:
        server?.resetStats();
        break;

      case btnStop:
        FlutterForegroundTask.stopService();
        break;
    }
  }

  @override
  void onReceiveData(Object data) async {
    if(data is String) {
      var payload = jsonDecode(data) as Map<String, dynamic>;
      var funcId = payload['id'] as int;
      Map<String, dynamic> response;
      try {
        var funcName = payload['name'] as String;
        var args = payload['args'] as Map<String, dynamic>? ?? {};
        dynamic result = await DeviceServer.call(funcName, args);
        if(result is StreamWrapper) {
          var memFile = MemoryFile();
          var streamResult = result;
          streamResult.stream.listen((item) {
            memFile.reset();
            streamResult.writeToMemoryFileDynamic(item, memFile);
            memFile.writeInt(funcId);
            var bytes = memFile.toUint8List();
            var trData = TransferableTypedData.fromList([bytes]);
            FlutterForegroundTask.sendDataToMain(trData);
          });
          if(streamResult is NotifierWrapper)
            streamResult.emitCurrentValue();
          result = true;
        }
        response = {
          'id': funcId,
          'result': result,
        };
      } catch(e) {
        response = {
          'id': funcId,
          'error': e.toString(),
        };
      }
      var json = jsonEncode(response);
      FlutterForegroundTask.sendDataToMain(json);
    }
  }
}

class BpmWithTimestamp {
  const BpmWithTimestamp({
    required this.bpm,
    required this.timestamp,
  });

  final int bpm;
  final DateTime timestamp;
}

class DeviceServer {
  static final Map<String, DeviceServer> _servers = {};

  static const _irrWeights = {
    IrregularityType.highRAmplitude: 1,
    IrregularityType.longSToZeroDuration: 1,
    IrregularityType.longFullDuration: 2
  };
  static const _minWeightToDetect = 2;
  static const _notificationUpdateIntervalSecs = 3;

  DeviceServer(this.device) {
    _irrStream = device.startHeartbeatStream();
    _irrStream.listen((beat) {
      if(!beat.beat.isValid)
        return;
      beatsCount++;
      var irrTotalWeight = 0;
      for(var irr in beat.irregularityTypes)
        irrTotalWeight += _irrWeights[irr] ?? 0;
      if(irrTotalWeight >= _minWeightToDetect)
        irrTimestamps.add(beat.beat.samples.first.timestamp);
    });
    _hrStream = device.startHrStreaming();
    _hrStream.listen((rate) {
      bpms.add(BpmWithTimestamp(bpm: rate, timestamp: DateTime.now()));
    });

    Stream.periodic(const Duration(seconds: _notificationUpdateIntervalSecs)).listen((_) {
      if(Service.server == this)
        updateNotification();
    });

    Service.server = this;
    updateNotification();
  }

  Device device;
  NotifierWrapper<DeviceStatus>? _statusNotifierWrapper;
  NotifierWrapper<DeviceRecordingStatus?>? _recordingStatusNotifierWrapper;
  late Stream<int> _hrStream;
  late Stream<HeartbeatWithIrregularity> _irrStream;
  var irrTimestamps = <DateTime>[];
  var beatsCount = 0;
  var bpms = <BpmWithTimestamp>[];
  var startedAt = DateTime.now();

  int irrCountSince(DateTime from) {
    var irrs = irrTimestamps.reversed.takeWhile((dt) => dt.microsecondsSinceEpoch > from.microsecondsSinceEpoch);
    return irrs.length;
  }

  (int, int, int) bpmPercentileSince(DateTime from) {
    var latestBpms = bpms.reversed.takeWhile((bpm) => bpm.timestamp.microsecondsSinceEpoch > from.microsecondsSinceEpoch).toList();
    if(latestBpms.isEmpty)
      return (0, 0, 0);
    latestBpms = latestBpms.sortedBy((bpm) => bpm.bpm);
    var midIndex = max(0, latestBpms.length / 2).floor();
    return (latestBpms.first.bpm, latestBpms[midIndex].bpm, latestBpms.last.bpm);
  }

  void updateNotification() {
    var duration = DateTime.now().difference(startedAt);
    var durationHours = duration.inHours;
    var durationMinutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    var latestBpm = bpms.lastOrNull?.bpm ?? 0;
    var notificationTitle = '$durationHours:$durationMinutes - $latestBpm';

    var irrCount = irrTimestamps.length;
    var beatsPerIrr = irrCount == 0 ? 0 : (beatsCount / irrCount).ceil();
    var notificationText = '$irrCount / $beatsCount${beatsPerIrr == 0 ? '' : ' (1 / $beatsPerIrr)'}';

    var now = DateTime.now();
    var prev10min = now.subtract(const Duration(minutes: 10));
    if(prev10min.microsecondsSinceEpoch > startedAt.microsecondsSinceEpoch) {
      var (last10MinutesMinHr, last10MinutesMedHr, last10MinutesMaxHr) = bpmPercentileSince(prev10min);
      var last10MinutesIrrCount = irrCountSince(prev10min);
      notificationTitle += '; 10M: $last10MinutesMinHr-$last10MinutesMedHr-$last10MinutesMaxHr';
      notificationText += '; 10M: $last10MinutesIrrCount';
      var prev1hour = now.subtract(const Duration(hours: 1));
      if(prev1hour.microsecondsSinceEpoch > startedAt.microsecondsSinceEpoch) {
        var (lastHourMinHr, lastHourMedHr, lastHourMaxHr) = bpmPercentileSince(prev1hour);
        var lastHourIrrCount = irrCountSince(prev1hour);
        notificationTitle += '; 1H: $lastHourMinHr-$lastHourMedHr-$lastHourMaxHr';
        notificationText += '; 1H: $lastHourIrrCount';
        var prev6hours = now.subtract(const Duration(hours: 6));
        if(prev6hours.microsecondsSinceEpoch > startedAt.microsecondsSinceEpoch) {
          var last6HoursIrrCount = irrCountSince(prev6hours);
          notificationText += '; 6H: $last6HoursIrrCount';
        }
      }
    }

    FlutterForegroundTask.updateService(
      notificationTitle: notificationTitle,
      notificationText: notificationText,
    );
  }

  void resetStats() {
    irrTimestamps = [];
    beatsCount = 0;
    bpms = [];
    startedAt = DateTime.now();
    updateNotification();
  }

  static Future<dynamic> call(String funcName, Map<String, dynamic> args) async {
    if(funcName == 'connectToFirst') {
      var device = await Device.connectToFirst();
      var deviceId = device.dev.deviceId;
      _servers[deviceId] ??= DeviceServer(device);
      return deviceId;
    }

    var deviceId = args['deviceId'] as String;
    var server = _servers[deviceId];
    if(server == null)
      throw Exception('Device $deviceId is not initialized.');

    switch(funcName) {
      case 'startRecording':
        await server.device.startRecording();
        break;

      case 'stopRecording':
        await server.device.stopRecording();
        break;

      case 'getRecording':
        var rec = await server.device.getRecording();
        return rec;

      case 'deleteRecording':
        await server.device.deleteRecording();
        break;

      case 'refreshRecordingStatus':
        var status = await server.device.refreshRecordingStatus();
        return status;

      case 'startHrStreaming':
        return StreamWrapper.init(
          stream: server._hrStream,
          writeToMemoryFile: (hr, f) => f.writeUint8(hr)
        );

      case 'startHeartbeatStreaming':
        return StreamWrapper.init(
          stream: server._irrStream,
          writeToMemoryFile: (beat, f) {
            f.writeInt(beat.beat.samples.length);
            for(var sample in beat.beat.samples) {
              f.writeInt(sample.tsMicroSecs);
              f.writeInt16(sample.voltage);
            }
            f.writeInt(beat.beat.rPeakIndex);
            f.writeInt(beat.beat.sPeakIndex);
            f.writeInt(beat.beat.qrsEndIndex);
            f.writeUint8(beat.irregularityTypes.length);
            for(var irr in beat.irregularityTypes)
              f.writeUint8(irr.index);
          }
        );

      case 'statusNotifier':
        return server._statusNotifierWrapper ??= NotifierWrapper(
          notifier: server.device.statusNotifier,
          writeToMemoryFile: (status, f) => f.writeUint8(status.index)
        );

      case 'recordingStatus':
        return server._recordingStatusNotifierWrapper ??= NotifierWrapper(
            notifier: server.device.recordingStatus,
            writeToMemoryFile: (status, f) {
              if(status == null) {
                f.writeBool(false);
              } else {
                f.writeBool(true);
                f.writeInt(status.startedAt?.microsecondsSinceEpoch ?? 0);
                f.writeBool(status.isOngoing);
              }
            }
        );

      case 'batteryLevel':
        var stream = server.device.batteryLevel;
        return StreamWrapper.init(
          stream: stream,
          writeToMemoryFile: (level, f) => f.writeUint8(level)
        );

      case 'disconnect':
        await server.device.disconnect();
        return true;

      default: throw Exception('Unsupported function name: funcName');
    }
  }
}

class DeviceClient {
  DeviceClient(this.deviceId);

  String deviceId;
  ValueNotifier<DeviceStatus>? _statusNotifier;
  ValueNotifier<DeviceRecordingStatus?>? _recordingStatus;

  static ValueNotifier<T> streamToNotifier<T>(Stream<T> stream, T initialValue) {
    var notifier = ValueNotifier<T>(initialValue);
    stream.listen((status) => notifier.value = status);
    return notifier;
  }

  static Future<DeviceClient> connectToFirst(BuildContext context) async {
    await Service.start(context);
    var deviceId = await Service.call('connectToFirst') as String;
    return DeviceClient(deviceId);
  }

  Future<void> startRecording() async {
    await Service.call('startRecording', {'deviceId': deviceId});
  }

  Future<void> stopRecording() async {
    await Service.call('stopRecording', {'deviceId': deviceId});
  }

  Future<DeviceRecording?> getRecording() async {
    var json = await Service.call('getRecording', {'deviceId': deviceId}) as Map<String, dynamic>?;
    var result = json == null ? null : DeviceRecording.fromJson(json);
    return result;
  }

  Future<void> deleteRecording() async {
    await Service.call('deleteRecording', {'deviceId': deviceId});
  }

  Future<DeviceRecordingStatus> refreshRecordingStatus() async {
    var json = await Service.call('refreshRecordingStatus', {'deviceId': deviceId}) as Map<String, dynamic>;
    var result = DeviceRecordingStatus.fromJson(json);
    return result;
  }

  Stream<int> startHrStreaming() {
    return Service.stream(
      'startHrStreaming',
      {'deviceId': deviceId},
      (memFile) => memFile.readUint8()
    );
  }

  Stream<HeartbeatWithIrregularity> startHeartbeatStreaming() {
    return Service.stream(
      'startHeartbeatStreaming',
      {'deviceId': deviceId},
      (memFile) {
        var samplesCount = memFile.readInt();
        var samples = List.generate(samplesCount, (_) {
          var microSecs = memFile.readInt();
          var timestamp = DateTime.fromMicrosecondsSinceEpoch(microSecs);
          var voltage = memFile.readInt16();
          return EcgSample(
            timestamp: timestamp,
            voltage: voltage,
          );
        });
        var rPeakIndex = memFile.readInt();
        var sPeakIndex = memFile.readInt();
        var qrsEndIndex = memFile.readInt();
        var irrCount = memFile.readUint8();
        var irregularityTypes = <IrregularityType>{};
        for(var a = 0; a < irrCount; a++) {
          var irrTypeIndex = memFile.readUint8();
          var irrType = IrregularityType.values[irrTypeIndex];
          irregularityTypes.add(irrType);
        }
        return HeartbeatWithIrregularity(
          beat: Heartbeat(
            samples: samples,
            rPeakIndex: rPeakIndex,
            sPeakIndex: sPeakIndex,
            qrsEndIndex: qrsEndIndex,
            //medianZero: medianZero
          ),
          irregularityTypes: irregularityTypes
        );
      }
    );
  }

  ValueNotifier<DeviceStatus>? get statusNotifier {
    return _statusNotifier ??= streamToNotifier(
      Service.stream('statusNotifier', {'deviceId': deviceId}, (memFile) {
        var index = memFile.readUint8();
        var status = DeviceStatus.values[index];
        return status;
      }),
      DeviceStatus.unknown
    );
  }

  ValueNotifier<DeviceRecordingStatus?> get recordingStatus {
    return _recordingStatus ??= streamToNotifier(
      Service.stream('recordingStatus', {'deviceId': deviceId}, (memFile) {
        if(!memFile.readBool())
          return null;
        var startedAtTS = memFile.readInt();
        var isOngoing = memFile.readBool();
        return DeviceRecordingStatus(
          startedAt: startedAtTS == 0 ? null : DateTime.fromMicrosecondsSinceEpoch(startedAtTS),
          isOngoing: isOngoing,
        );
      }),
      null
    );
  }

  Stream<int>? get batteryLevel => Service.stream(
    'batteryLevel',
    {'deviceId': deviceId},
    (memFile) {
      var level = memFile.readUint8();
      return level;
    }
  );

  Future<void> disconnect() async {
    await Service.call('disconnect', {'deviceId': deviceId});
    await Service.stop();
  }
}
