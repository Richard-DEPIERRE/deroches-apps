/// Test helpers and fakes for apps built on the kit. Import from tests only.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'app_kit.dart';

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
