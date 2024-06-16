// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import '../pages/help_page.dart';
import '../pages/recording_page.dart';
import '../pages/settings_page.dart';
import '../util/device.dart';
import '../util/future_util.dart';
import '../util/recording_manager.dart';
import '../widgets/ecg_streaming_graph.dart';
import '../widgets/hr_display.dart';
import '../widgets/hr_streaming_graph.dart';
import '../widgets/pad.dart';
import '../widgets/recording_panel.dart';

enum GraphType {
  hr,
  ecg
}

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Device? device;
  Future<Device>? connectingFuture;
  Future<void>? disconnectingFuture;
  Future<void>? recFuture;
  Stream<int>? hrStream;
  Stream<Iterable<EcgSample>>? ecgStream;
  var graphType = GraphType.hr;
  var enableEcg = false;
  var prevStatus = DeviceStatus.unknown;

  void startConnecting() {
    var newConnectingFuture = Device.connectToFirst().showErrorToUser(context);
    setState(() {
      connectingFuture = newConnectingFuture;
    });
    newConnectingFuture.then((newDevice) => setState((){
      device = newDevice;
      hrStream = newDevice.startHrStreaming().showErrorToUser(context);
      if(enableEcg && ecgStream == null)
        ecgStream = newDevice.startEcgStreaming().showErrorToUser(context);
      prevStatus = DeviceStatus.unknown;
    })).onError((error, stackTrace) => setState((){
      device = null;
    })).whenComplete(() => setState(() {
      connectingFuture = null;
    }));
  }

  void startEcgStreaming() {
    setState(() {
      enableEcg = true;
      if(ecgStream == null && device != null)
        ecgStream = device!.startEcgStreaming().showErrorToUser(context);
    });
  }

  void clearDevice() {
    device = null;
    if(hrStream != null)
      hrStream = const Stream.empty();
    if(ecgStream != null)
      ecgStream = const Stream.empty();
  }

  Widget connectionWidget() {
    return ValueListenableBuilder(
      valueListenable: device?.statusNotifier ?? ValueNotifier(DeviceStatus.unknown),
      builder: (context, status, child) {
        if(connectingFuture != null && (status == DeviceStatus.disconnected || status == DeviceStatus.unknown))
          status = DeviceStatus.connecting;
        var oldStatus = prevStatus;
        prevStatus = status;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if(oldStatus != DeviceStatus.unknown && status == DeviceStatus.disconnected) {
            if(device != null) {
              setState(() {
                clearDevice();
              });
            }
          }
        });
        var children = switch(status) {
          DeviceStatus.unknown || DeviceStatus.disconnected => [
            ElevatedButton(
              onPressed: () => startConnecting(),
              child: const Text('Connect')
            ),
            Pad.horizontalSpace
          ],
          DeviceStatus.connecting => [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  connectingFuture?.timeout(Duration.zero);
                  connectingFuture = null;
                });
              },
              child: const Text('Cancel')
            ),
            Pad.horizontalSpace,
            const Text('Connecting')
          ],
          DeviceStatus.connected => [
            ElevatedButton(
              onPressed: disconnectingFuture != null ? null : () {
                setState(() {
                  clearDevice();
                  disconnectingFuture = device?.disconnect().whenComplete(() => setState((){
                    disconnectingFuture = null;
                  })).showErrorToUser(context);
                });
              },
              child: const Text('Disconnect')
            ),
            Pad.horizontalSpace
          ],
        };
        return Row(
          children: children
        );
      },
    );
  }

  Widget mainMenu() {
    return PopupMenuButton(
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            child: const ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings')
            ),
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage())
              );
            },
          ),
          PopupMenuItem(
            child: const ListTile(
                leading: Icon(Icons.help),
                title: Text('Help')
            ),
            onTap: () {
              openHelpPage(context);
            },
          )
        ];
      },
    );
  }

  @override
  void initState() {
    super.initState();
    startConnecting();
  }

  @override
  Widget build(context) {
    return Scaffold(
      appBar: AppBar(
        title: device == null
          ? const Text('[not connected]')
          : Row(
            children: [
              StreamBuilder(
                stream: device?.batteryLevel,
                builder: (context, snapshot) {
                  var level = snapshot.data;
                  if(level == null)
                    return const SizedBox();
                  return Text('[$level%] ');
                },
              ),
              Text(device!.dev.deviceId)
            ]
          ),
        actions: [
          mainMenu()
        ],
      ),

      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              height: 65,
              child: Row(
                children: [
                  Pad.horizontalSpace,
                  connectionWidget(),
                  const Spacer(),
                  if(device != null)
                    HrDisplay(
                        hrStream: hrStream
                    )
                ],
              ),
            ),
            if(hrStream != null)
              Visibility(
                visible: graphType == GraphType.hr,
                maintainState: true,
                child: HrStreamingGraph(
                  hrStream: hrStream
                )
              ),
            if(ecgStream != null && graphType == GraphType.ecg)
              EcgStreamingGraph(
                stream: ecgStream!
              ),
            if(device != null)
              Pad.verticalSpace,
            if(device != null)
              SegmentedButton(
                segments: const [
                  ButtonSegment(
                    value: GraphType.hr,
                    label: Text('HR')
                  ),
                  ButtonSegment(
                    value: GraphType.ecg,
                    label: Text('ECG')
                  )
                ],
                selected: {graphType},
                showSelectedIcon: false,
                onSelectionChanged: (sel) {
                  setState(() {
                    graphType = sel.first;
                    if(graphType == GraphType.ecg)
                      startEcgStreaming();
                  });
                },
              ),
            if(device != null)
              RecordingPanel(device: device!)
          ]
        )
      ),

      drawer: Drawer(
        child: Builder(
          builder: (context) {
            return ValueListenableBuilder(
              valueListenable: RecordingManager.notifier,
              builder: (context, items, child) {
                return ListView(
                  children: items.reversed.map((item) => ListTile(
                    title: Text(item.timeString),
                    subtitle: item.title.isEmpty ? null : Text(
                      item.title,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic
                      )
                    ),
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute(builder: (context) => RecordingPage(rec: item))
                      );
                    },
                  )).toList(),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
