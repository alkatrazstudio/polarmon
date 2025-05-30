// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n/generated/app_localizations.dart';
import '../pages/home_page.dart';
import '../util/device.dart';
import '../util/locale_manager.dart';
import '../util/mark_manager.dart';
import '../util/recording_manager.dart';
import '../util/settings.dart';

Future<void> appMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  var settingsFuture = Settings.load();
  Device.startMonitoring();
  WakelockPlus.enable();
  RecordingManager.loadList();
  MarkManager.loadList();
  await settingsFuture;
  LocaleManager.applyFromSettings();
  runApp(App());
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: LocaleManager.notifier,
      builder: (context, locale, child) {
        return MaterialApp(
          home: HomePage(),
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData(
            brightness: Brightness.dark
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
        );
      },
    );
  }
}
