// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

import '../pages/home_page.dart';
import '../util/device.dart';
import '../util/mark_manager.dart';
import '../util/recording_manager.dart';
import '../util/settings.dart';

void appMain() {
  WidgetsFlutterBinding.ensureInitialized();
  Settings.load();
  Device.startMonitoring();
  WakelockPlus.enable();
  RecordingManager.loadList();
  MarkManager.loadList();
  runApp(App());
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark
      )
    );
  }
}
