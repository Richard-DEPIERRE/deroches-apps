import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/data/logbook.dart';

import '../data_upgrade/sample.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('roulekm_data_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('a new install opens an empty logbook, and what is saved reads back', () async {
    final data = RoulekmData(dir);
    expect(Logbook.fromJson(await data.log.open()), const Logbook());

    await data.log.save(schema1Logbook.toJson());
    expect(Logbook.fromJson(await RoulekmData(dir).log.open()), schema1Logbook);
  });

  test('the backup restores into the store the app saves through', () async {
    final files = FakeBackupFiles()
      ..picked = File('test/data_upgrade/backups/roulekm-backup.schema1.json').readAsBytesSync();
    final data = RoulekmData(dir, files: files);
    await data.log.open();

    expect(await data.backup.restore(), isA<BackupDone>());

    // The app's in-memory log is stale now: saving it must not overwrite the restore.
    expect(() => data.log.save(Logbook.empty), throwsStateError);
    expect(Logbook.fromJson(await data.log.open()), schema1Logbook);
  });
}
