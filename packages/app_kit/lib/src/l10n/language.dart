import 'dart:ui';

import '../config/app_config.dart';

/// The locales every app supports, French first (ADR 0001, section 7).
final kitLocales = [for (final lang in kitLanguages) Locale(lang)];

/// The device's language when it is French or English, English otherwise.
Locale resolveKitLocale(List<Locale>? deviceLocales) {
  final device = deviceLocales?.firstOrNull?.languageCode;
  return kitLocales.firstWhere((l) => l.languageCode == device, orElse: () => const Locale('en'));
}
