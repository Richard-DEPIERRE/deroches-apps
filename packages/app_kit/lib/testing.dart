/// Fakes and helpers for tests of the kit and of every app (ADR 0001, section 3).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

/// One event a [FakeAnalyticsBackend] received, envelope included.
typedef SentEvent = ({String name, Map<String, Object> properties});

/// Keeps the events [Analytics] would send, instead of sending them.
class FakeAnalyticsBackend implements AnalyticsBackend {
  final events = <SentEvent>[];
  bool started = false;

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> stop() async => started = false;

  @override
  Future<void> capture(String event, Map<String, Object> properties) async =>
      events.add((name: event, properties: properties));
}

/// Counts the rating prompts the kit asked the platform for.
class FakeStoreReview implements StoreReview {
  /// False plays a platform without the store's prompt.
  bool available = true;
  int requests = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => requests++;
}

/// Plays the system save dialog and file picker: keeps what was saved, and
/// hands back [picked] (null: the user cancels the picker).
class FakeBackupFiles implements BackupFiles {
  List<int>? picked;

  /// The user cancels the save dialog.
  bool cancelSave = false;

  /// File name → bytes.
  final saved = <String, Uint8List>{};

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    if (!cancelSave) saved[fileName] = bytes;
    return !cancelSave;
  }

  @override
  Future<Uint8List?> pick() async => switch (picked) {
    final bytes? => Uint8List.fromList(bytes),
    null => null,
  };
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

/// The data-upgrade test (ADR 0001, section 8). Call it from the app's
/// `test/data_upgrade/` test's `main`.
///
/// Every `*.json` file in [fixtures] is a document written by a released
/// version's own code, with made-up content. Each one is opened through
/// [DataStore] as document [name], upgraded with [migrations], decoded with
/// [decode] into a list of items, and must equal `expected[<file name>]`
/// item for item, with the same count: nothing silently dropped. It is then
/// opened a second time, from the upgraded file, and must read back the same.
void dataUpgradeTests<T>({
  required String fixtures,
  required String appId,
  required String name,
  required List<Migration> migrations,
  required List<T> Function(Map<String, Object?> data) decode,
  required Map<String, List<T>> expected,
}) {
  final files = Directory(fixtures)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();
  String fileName(File f) => f.uri.pathSegments.last;

  test('every fixture has its expected items, and every expectation a fixture', () {
    expect(files, isNotEmpty, reason: 'no fixture in $fixtures');
    expect(files.map(fileName).toSet(), expected.keys.toSet());
  });

  for (final fixture in files) {
    test('${fileName(fixture)} upgrades to schema ${migrations.length + 1} with nothing lost', () async {
      final want = expected[fileName(fixture)];
      if (want == null) fail('no expected items for ${fileName(fixture)}');
      final dir = Directory.systemTemp.createTempSync('data_upgrade_');
      addTearDown(() => dir.deleteSync(recursive: true));
      fixture.copySync('${dir.path}/$name.json');

      DataStore store() => DataStore(
        directory: dir,
        appId: appId,
        name: name,
        migrations: migrations,
        initial: () => fail('${fileName(fixture)} opened as an empty state'),
      );

      for (final pass in ['upgraded', 'read back']) {
        final items = decode(await store().open());
        expect(items.length, want.length, reason: '${fileName(fixture)}, $pass: item count');
        expect(items, want, reason: '${fileName(fixture)}, $pass');
      }
    });
  }
}
