import 'dart:convert';
import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late FakeBackupFiles files;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('backup_');
    files = FakeBackupFiles();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  // Schema 1 → 2: a note's `text` becomes `body`.
  Map<String, Object?> renameText(Map<String, Object?> data) => {
    'notes': [
      for (final note in (data['notes']! as List).cast<Map<String, Object?>>())
        {'id': note['id'], 'body': note['body'] ?? note['text']},
    ],
  };

  DataStore notes({Directory? directory}) => DataStore(
    directory: directory ?? dir,
    appId: 'carnet-km',
    name: 'notes',
    migrations: [renameText],
    initial: () => {'notes': <Object?>[]},
  );
  DataStore kit() => DataStore(directory: dir, appId: 'carnet-km', name: 'kit', initial: () => {});

  BackupService service([List<DataStore>? stores]) => BackupService(
    appId: 'carnet-km',
    stores: stores ?? [notes(), kit()],
    files: files,
    now: () => DateTime.utc(2026, 11, 3, 9),
  );

  Future<void> seed(Map<String, Object?> notesData, [Map<String, Object?> kitData = const {'onboarded': true}]) async {
    for (final (store, data) in [(notes(), notesData), (kit(), kitData)]) {
      await store.open();
      await store.save(data);
    }
  }

  const before = {
    'notes': [
      {'id': 'n1', 'body': 'Pain'},
    ],
  };

  List<int> bytesOf(String name) => File('${dir.path}/$name.json').readAsBytesSync();

  /// Restores [backup] and checks it is refused for [reason] with the current data untouched.
  Future<void> expectRefused(Object backup, BackupFailure reason) async {
    await seed(before);
    final notesBefore = bytesOf('notes'), kitBefore = bytesOf('kit');
    files.picked = backup is List<int> ? backup : utf8.encode(jsonEncode(backup));
    final result = await service().restore();
    expect(result, isA<BackupFailed>().having((r) => r.reason, 'reason', reason));
    expect(bytesOf('notes'), notesBefore);
    expect(bytesOf('kit'), kitBefore);
  }

  Map<String, Object?> backupOf(Map<String, Object?> documents, {String appId = 'carnet-km'}) => {
    'format': 'deroches.data',
    'kind': 'backup',
    'app_id': appId,
    'written_at': '2026-10-01T09:00:00.000Z',
    'documents': documents,
  };

  test('export writes every document, with its schema, as one backup file', () async {
    await seed(before);
    expect(await service().export(), isA<BackupDone>());
    expect(files.saved.keys, ['carnet-km-backup-2026-11-03.json']);
    expect(jsonDecode(utf8.decode(files.saved.values.single)), {
      'format': 'deroches.data',
      'kind': 'backup',
      'app_id': 'carnet-km',
      'written_at': '2026-11-03T09:00:00.000Z',
      'documents': {
        'notes': {'schema': 2, 'data': before},
        'kit': {
          'schema': 1,
          'data': {'onboarded': true},
        },
      },
    });
  });

  test('export then restore gives equal data, and keeps a copy of what it replaced', () async {
    await seed(before);
    await service().export();
    await seed({'notes': <Object?>[]}, {'onboarded': false});

    files.picked = files.saved.values.single;
    expect(await service().restore(), isA<BackupDone>());
    expect(await notes().open(), before);
    expect(await kit().open(), {'onboarded': true});
    Object? copy(String name) => jsonDecode(File('${dir.path}/$name.json.before-restore').readAsStringSync())['data'];
    expect(copy('notes'), {'notes': <Object?>[]});
    expect(copy('kit'), {'onboarded': false});
  });

  test('a save still being written when the restore starts is in the copy it keeps', () async {
    await seed(before);
    await service().export();
    final inUse = notes();
    await inUse.open();
    final saving = inUse.save({'notes': <Object?>[]});
    files.picked = files.saved.values.single;
    expect(await service([inUse, kit()]).restore(), isA<BackupDone>());
    await saving;
    final copy = jsonDecode(File('${dir.path}/notes.json.before-restore').readAsStringSync());
    expect(copy['data'], {'notes': <Object?>[]});
    expect(await notes().open(), before);
  });

  test('an old backup restores and upgrades with the app\'s migrations', () async {
    await seed({'notes': <Object?>[]});
    files.picked = utf8.encode(
      jsonEncode(
        backupOf({
          'notes': {
            'schema': 1,
            'data': {
              'notes': [
                {'id': 'n1', 'text': 'Pain'},
              ],
            },
          },
        }),
      ),
    );
    expect(await service().restore(), isA<BackupDone>());
    expect(await notes().open(), before);
    expect(jsonDecode(File('${dir.path}/notes.json').readAsStringSync())['schema'], 2);
    expect(await kit().open(), {'onboarded': true}, reason: 'a document missing from the backup is left as it is');
  });

  test('a truncated file is refused with the current data intact', () async {
    await seed(before);
    await service().export();
    final whole = files.saved.values.single;
    await expectRefused(whole.sublist(0, whole.length ~/ 2), BackupFailure.unreadable);
  });

  test('a foreign file is refused with the current data intact', () async {
    await expectRefused([0x89, 0x50, 0x4e, 0x47, 0xff, 0xfe], BackupFailure.unreadable);
    await expectRefused({'hello': 'world'}, BackupFailure.unreadable);
    await expectRefused(backupOf({}), BackupFailure.unreadable);
    await expectRefused(backupOf({'notes': 'not a document'}), BackupFailure.unreadable);
    await expectRefused(
      backupOf({
        'notes': {'schema': 2, 'data': before},
      }, appId: 'autre-app'),
      BackupFailure.otherApp,
    );
  });

  test('a backup from a newer schema is refused with the current data intact', () async {
    await expectRefused(
      backupOf({
        'notes': {'schema': 3, 'data': before},
      }),
      BackupFailure.newerSchema,
    );
  });

  test('a backup whose later document is bad is refused before the good one is written', () async {
    await expectRefused(
      backupOf({
        'notes': {
          'schema': 2,
          'data': {'notes': <Object?>[]},
        },
        'kit': {'schema': 2, 'data': <String, Object?>{}},
      }),
      BackupFailure.newerSchema,
    );
    expect(File('${dir.path}/notes.json.before-restore').existsSync(), isFalse);
  });

  test('a backup a migration can\'t upgrade is refused with the current data intact', () async {
    await expectRefused(
      backupOf({
        'notes': {'schema': 1, 'data': <String, Object?>{}},
      }),
      BackupFailure.migrationFailed,
    );
  });

  test('a cancelled picker or save dialog changes nothing', () async {
    await seed(before);
    final notesBefore = bytesOf('notes');
    expect(await service().restore(), isA<BackupCancelled>());
    expect(bytesOf('notes'), notesBefore);
    expect(File('${dir.path}/notes.json.before-restore').existsSync(), isFalse);

    files.cancelSave = true;
    expect(await service().export(), isA<BackupCancelled>());
    expect(files.saved, isEmpty);
  });

  test('a write that fails half-way puts every document back as it was, and saving still works', () async {
    await seed(before);
    await service().export();
    await seed({'notes': <Object?>[]});
    final notesBefore = bytesOf('notes');
    final inUse = notes();
    await inUse.open();
    // The second document can't be written: its folder is a file.
    final blocked = File('${dir.path}/blocked')..writeAsStringSync('');
    files.picked = files.saved.values.single;
    final result = await service([
      inUse,
      DataStore(directory: Directory(blocked.path), appId: 'carnet-km', name: 'kit', initial: () => {}),
    ]).restore();
    expect(result, isA<BackupFailed>().having((r) => r.reason, 'reason', BackupFailure.fileError));
    expect(bytesOf('notes'), notesBefore);
    await inUse.save(before);
    expect(await notes().open(), before);
  });

  test('a file over the size limit is refused before it is read', () async {
    await expectRefused(List.filled(BackupService.maxBytes + 1, 0x20), BackupFailure.tooLarge);
  });

  test('every failure has its own message, in French and in English', () {
    for (final lang in ['fr', 'en']) {
      final l = lookupKitLocalizations(Locale(lang));
      final messages = {for (final reason in BackupFailure.values) reason.message(l)};
      expect(messages, hasLength(BackupFailure.values.length), reason: lang);
    }
  });
}
