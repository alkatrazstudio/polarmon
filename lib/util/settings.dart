// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../util/file_util.dart';
import '../util/locale_manager.dart';

class Settings {
  static final notifier = ValueNotifier<Settings>(Settings(
    hrCustomMin: 50,
    hrCustomMax: 180,
    ecgMin: -700,
    ecgMax: 1100,
    hrCustomEnable: false,
    locale: LocaleManager.fallbackLocale.languageCode
  ));

  Settings({
    int? hrCustomMin,
    int? hrCustomMax,
    int? ecgMin,
    int? ecgMax,
    bool? hrCustomEnable,
    String? locale,
  }):
    hrCustomMin = hrCustomMin ?? notifier.value.hrCustomMin,
    hrCustomMax = max(hrCustomMin ?? notifier.value.hrCustomMin + 1, hrCustomMax ?? notifier.value.hrCustomMax),
    ecgMin = ecgMin ?? notifier.value.ecgMin,
    ecgMax = max(ecgMax ?? notifier.value.ecgMin + 1, ecgMax ?? notifier.value.ecgMax),
    hrCustomEnable = hrCustomEnable ?? notifier.value.hrCustomEnable,
    locale = locale ?? notifier.value.locale;

  final int hrCustomMin;
  final int hrCustomMax;
  final int ecgMin;
  final int ecgMax;
  final bool hrCustomEnable;
  final String locale;

  static Future<File> file() async {
    var file = FileUtil.file('settings.json');
    return file;
  }

  static Settings fromJson(Map<String, dynamic> json) {
    return Settings(
      hrCustomMin: json['hrCustomMin'] as int?,
      hrCustomMax: json['hrCustomMax'] as int?,
      ecgMin: json['ecgMin'] as int?,
      ecgMax: json['ecgMax'] as int?,
      hrCustomEnable: json['customHrRange'] as bool?,
      locale: json['locale'] as String?
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hrCustomMin': hrCustomMin,
      'hrCustomMax': hrCustomMax,
      'ecgMin': ecgMin,
      'ecgMax': ecgMax,
      'customHrRange': hrCustomEnable,
      'locale': locale
    };
  }

  static Future<void> load() async {
    var f = await file();
    if(!await f.exists())
      return;
    var json = await f.readAsString();
    var settings = Settings.fromJson(jsonDecode(json));
    notifier.value = settings;
  }

  Future<void> save() async {
    await FileUtil.writeJsonSafe(await file(), this);
    notifier.value = this;
  }
}
