// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/material.dart';

import '../pages/help_page.dart';
import '../pages/settings_page.dart';
import '../util/device.dart';
import '../util/ecg_process.dart';
import '../util/future_util.dart';
import '../util/locale_manager.dart';
import '../util/service.dart';
import '../widgets/app_drawer.dart';
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
  DeviceClient? device;
  Future<DeviceClient>? connectingFuture;
  Future<void>? disconnectingFuture;
  Future<void>? recFuture;
  Stream<int>? hrStream;
  Stream<HeartbeatWithIrregularity>? heartbeatStream;
  var graphType = GraphType.hr;
  var enableEcg = false;
  var prevStatus = DeviceStatus.unknown;

  void startConnecting() {
    var newConnectingFuture = DeviceClient.connectToFirst(context).showErrorToUser(context);
    setState(() {
      connectingFuture = newConnectingFuture;
    });
    newConnectingFuture.then((newDevice) => setState((){
      device = newDevice;
      hrStream = newDevice.startHrStreaming().showErrorToUser(context);
      if(enableEcg && heartbeatStream == null)
        heartbeatStream = newDevice.startHeartbeatStreaming().showErrorToUser(context);
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
      if(heartbeatStream == null && device != null)
        heartbeatStream = device!.startHeartbeatStreaming().showErrorToUser(context);
    });
  }

  void clearDevice() {
    device = null;
    if(hrStream != null)
      hrStream = const Stream.empty();
    if(heartbeatStream != null)
      heartbeatStream = const Stream.empty();
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
              child: Text(L(context).homeConnectBtn)
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
              child: Text(L(context).homeCancelBtn)
            ),
            Pad.horizontalSpace,
            Text(L(context).homeStatusConnecting)
          ],
          DeviceStatus.connected => [
            ElevatedButton(
              onPressed: disconnectingFuture != null ? null : () {
                setState(() {
                  disconnectingFuture = device?.disconnect().whenComplete(() => setState((){
                    disconnectingFuture = null;
                  })).showErrorToUser(context);
                  clearDevice();
                });
              },
              child: Text(L(context).homeDisconnect)
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
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: Text(L(context).homeMenuSettings)
            ),
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage())
              );
            },
          ),
          PopupMenuItem(
            child: ListTile(
              leading: const Icon(Icons.help),
              title: Text(L(context).homeMenuHelp)
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
          ? Text('[${L(context).homeTitleNotConnected}]')
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
              Text(device!.deviceId)
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
            if(hrStream != null && device != null)
              Visibility(
                visible: graphType == GraphType.hr,
                maintainState: true,
                child: HrStreamingGraph(
                  hrStream: hrStream,
                  recordingStatus: device!.recordingStatus,
                )
              ),
            if(heartbeatStream != null && graphType == GraphType.ecg)
              EcgStreamingGraph(
                stream: heartbeatStream!
              ),
            if(device != null)
              Pad.verticalSpace,
            if(device != null)
              SegmentedButton(
                segments: [
                  ButtonSegment(
                    value: GraphType.hr,
                    label: Text(L(context).homeHR)
                  ),
                  ButtonSegment(
                    value: GraphType.ecg,
                    label: Text(L(context).homeECG)
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

      drawer: const AppDrawer(),
    );
  }
}
