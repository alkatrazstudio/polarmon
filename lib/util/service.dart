// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../util/device.dart';
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
  static const btnStop = 'stop';

  static final _completers = <int, Completer>{};
  static final _streamControllers = <int, StreamController<MemoryFile>>{};
  static final rnd = Random();

  static Future<void>? _startFuture;

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
    if(id == btnStop)
      FlutterForegroundTask.stopService();
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

class DeviceServer {
  static final Map<String, DeviceServer> _servers = {};

  DeviceServer(this.device);

  Device device;
  NotifierWrapper<DeviceStatus>? _statusNotifierWrapper;
  NotifierWrapper<DeviceRecordingStatus?>? _recordingStatusNotifierWrapper;

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
        var stream = server.device.startHrStreaming();
        return StreamWrapper.init(
          stream: stream,
          writeToMemoryFile: (hr, f) => f.writeUint8(hr)
        );

      case 'startEcgStreaming':
        var stream = server.device.startEcgStreaming();
        return StreamWrapper.init(
          stream: stream,
          writeToMemoryFile: (ecgs, f) {
            var items = ecgs.toList();
            f.writeInt(items.length);
            for(var item in items) {
              f.writeInt(item.timestamp.microsecondsSinceEpoch);
              f.writeInt16(item.voltage);
            }
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

  Stream<List<EcgSample>> startEcgStreaming() {
    return Service.stream(
      'startEcgStreaming',
      {'deviceId': deviceId},
      (memFile) {
        var itemsCount = memFile.readInt();
        var items = List.generate(itemsCount, (_) {
          var microSecs = memFile.readInt();
          var timestamp = DateTime.fromMicrosecondsSinceEpoch(microSecs);
          var voltage = memFile.readInt16();
          return EcgSample(
            timestamp: timestamp,
            voltage: voltage,
          );
        });
        return items;
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
