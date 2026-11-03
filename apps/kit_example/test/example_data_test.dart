import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_example/notes.dart';

void main() {
  test('the backup restores into the store the app saves through', () async {
    final dir = Directory.systemTemp.createTempSync('example_data_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final files = FakeBackupFiles()
      ..picked = File('test/data_upgrade/backups/kit-example-backup.schema1.json').readAsBytesSync();
    final data = ExampleData(dir, files: files);
    await data.notes.open();
    await data.notes.save({'notes': <Object?>[]});

    expect(await data.backup.restore(), isA<BackupDone>());

    // The app's in-memory notes are stale now: saving them must not overwrite the restore.
    expect(() => data.notes.save({'notes': <Object?>[]}), throwsStateError);
    expect(Note.decodeAll(await data.notes.open()), hasLength(2));
  });
}
