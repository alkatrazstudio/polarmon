// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';
import '../util/settings.dart';

class LocaleDropdownItem {
  const LocaleDropdownItem({
    required this.code,
    required this.name
  });

  final String code;
  final String name;
}

abstract class LocaleManager {
  const LocaleManager();

  static ValueNotifier<Locale> notifier = ValueNotifier(AppLocalizations.supportedLocales.first);

  static List<LocaleDropdownItem> get dropdownItems => [
    LocaleDropdownItem(code: 'en', name: 'English'),
    LocaleDropdownItem(code: 'ru', name: 'Русский'),
  ];

  static Locale get fallbackLocale {
    var localeCode = Platform.localeName;
    localeCode = localeCode.split('_').first;
    var locale = AppLocalizations.supportedLocales.firstWhereOrNull((loc) => loc.languageCode == localeCode);
    locale ??= AppLocalizations.supportedLocales.first;
    return locale;
  }

  static void applyFromSettings() {
    var localeCode = Settings.notifier.value.locale;
    var locale = AppLocalizations.supportedLocales.firstWhereOrNull((loc) => loc.languageCode == localeCode);
    locale ??= fallbackLocale;
    Intl.defaultLocale = locale.languageCode;
    notifier.value = locale;
  }
}

AppLocalizations L(BuildContext context) {
  return AppLocalizations.of(context)!;
}
