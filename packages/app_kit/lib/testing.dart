/// Fakes and helpers for tests of the kit and of every app (ADR 0001, section 3).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app_kit.dart';

/// One error a [FakeCrashReporter] received.
typedef RecordedError = ({Object error, StackTrace? stack, bool fatal});

/// Keeps what it is given, so a test can check it.
class FakeCrashReporter implements CrashReporter {
  final errors = <RecordedError>[];
  final breadcrumbs = <String>[];

  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) =>
      errors.add((error: error, stack: stack, fatal: fatal));

  @override
  void addBreadcrumb(String message) => breadcrumbs.add(message);
}

/// Keeps what Sentry would send, instead of sending it.
class FakeSentryTransport implements Transport {
  final envelopes = <SentryEnvelope>[];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return SentryId.newId();
  }

  /// The events sent, as the JSON Sentry would receive.
  Future<List<Map<String, dynamic>>> events() async => [
    for (final envelope in envelopes)
      for (final item in envelope.items)
        if (item.header.type == 'event') jsonDecode(utf8.decode(await item.dataFactory())) as Map<String, dynamic>,
  ];
}

/// Every message of the [templatePath] ARB file that is missing or empty in [translationPath].
List<String> arbProblems(String templatePath, String translationPath) {
  Map<String, dynamic> read(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  final translation = read(translationPath);
  return [
    for (final key in read(templatePath).keys.where((k) => !k.startsWith('@')))
      if (!translation.containsKey(key))
        'missing "$key"'
      else if ((translation[key] as String).trim().isEmpty)
        'empty "$key"',
  ];
}

/// Pumps [child] in [locale] on a small phone (320 x 568 points) at twice the
/// normal text size, with the kit's localizations.
Future<void> pumpOnSmallPhone(
  WidgetTester tester,
  Locale locale,
  Widget child, {
  List<LocalizationsDelegate<Object?>> localizationsDelegates = const [],
}) async {
  tester.view
    ..physicalSize = const Size(640, 1136)
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: kitLocales,
      localizationsDelegates: [...localizationsDelegates, ...KitLocalizations.localizationsDelegates],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}
