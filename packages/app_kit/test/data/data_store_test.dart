import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('data_store_'));
  tearDown(() => dir.deleteSync(recursive: true));

  DataStore store({List<Migration> migrations = const []}) => DataStore(
    directory: dir,
    appId: 'carnet-km',
    name: 'notes',
    migrations: migrations,
    initial: () => {'notes': <Object?>[]},
    now: () => DateTime.utc(2026, 11, 1, 9),
  );

  Future<DataStore> opened() async {
    final s = store();
    await s.open();
    return s;
  }

  File file([String suffix = '']) => File('${dir.path}/notes.json$suffix');

  void writeEnvelope(int schema, Map<String, Object?> data) => file().writeAsStringSync(
    jsonEncode({
      'format': 'deroches.data',
      'schema': schema,
      'app_id': 'carnet-km',
      'written_at': '2026-10-01T09:00:00.000Z',
      'data': data,
    }),
  );

  Matcher throwsProblem(DataProblem problem) =>
      throwsA(isA<DataException>().having((e) => e.problem, 'problem', problem));

  // Schema 1 → 2: rename `text` to `body`, written so a second run is harmless.
  Map<String, Object?> renameText(Map<String, Object?> data) => {
    'notes': [
      for (final note in (data['notes']! as List).cast<Map<String, Object?>>())
        {'id': note['id'], 'body': note['body'] ?? note['text']},
    ],
  };

  test('a missing file opens as the initial state', () async {
    expect(await store().open(), {'notes': <Object?>[]});
    expect(file().existsSync(), isFalse);
  });

  test('a round trip writes the envelope and reads the data back', () async {
    final data = {
      'notes': [
        {'id': 'n1', 'body': 'Pain'},
      ],
    };
    await (await opened()).save(data);

    expect(jsonDecode(file().readAsStringSync()), {
      'format': 'deroches.data',
      'schema': 1,
      'app_id': 'carnet-km',
      'written_at': '2026-11-01T09:00:00.000Z',
      'data': data,
    });
    expect(await store().open(), data);
  });

  test('a save keeps the previous good file as .bak', () async {
    await (await opened()).save({
      'notes': <Object?>['old'],
    });
    await (await opened()).save({
      'notes': <Object?>['new'],
    });

    expect(jsonDecode(file('.bak').readAsStringSync())['data'], {
      'notes': ['old'],
    });
    expect(await store().open(), {
      'notes': ['new'],
    });
  });

  test('an interrupted write leaves the old data readable', () async {
    await (await opened()).save({
      'notes': <Object?>['old'],
    });
    file('.tmp').writeAsStringSync('{"format": "deroches.da'); // crashed mid-write

    final s = store();
    expect(await s.open(), {
      'notes': ['old'],
    });
    await s.save({
      'notes': <Object?>['new'],
    });
    expect(await store().open(), {
      'notes': ['new'],
    });
  });

  test('a corrupt file is an error, never an empty app', () async {
    file().writeAsStringSync('{"format": "deroches.data", "sch');
    await expectLater(store().open(), throwsProblem(DataProblem.unreadable));

    file().writeAsStringSync('{"something": "else"}');
    await expectLater(store().open(), throwsProblem(DataProblem.unreadable));
  });

  test('another app\'s document is refused', () async {
    file().writeAsStringSync(
      jsonEncode({'format': 'deroches.data', 'schema': 1, 'app_id': 'other', 'data': <String, Object?>{}}),
    );
    await expectLater(store().open(), throwsProblem(DataProblem.unreadable));
  });

  test('a newer schema is refused and never overwritten', () async {
    writeEnvelope(3, {'notes': <Object?>[]});
    final before = file().readAsBytesSync();

    final refused = store(migrations: [renameText]);
    await expectLater(refused.open(), throwsProblem(DataProblem.newerSchema));
    await expectLater(refused.save({'notes': <Object?>[]}), throwsStateError);
    expect(file().readAsBytesSync(), before);
  });

  test('an older schema is migrated on open, written, and the old file kept', () async {
    writeEnvelope(1, {
      'notes': [
        {'id': 'n1', 'text': 'Pain'},
      ],
    });
    final upgraded = {
      'notes': [
        {'id': 'n1', 'body': 'Pain'},
      ],
    };

    expect(await store(migrations: [renameText]).open(), upgraded);
    final saved = jsonDecode(file().readAsStringSync()) as Map;
    expect(saved['schema'], 2);
    expect(saved['data'], upgraded);
    expect(jsonDecode(file('.bak').readAsStringSync())['schema'], 1);
  });

  test('a failing migration leaves the file byte-identical', () async {
    writeEnvelope(1, {'notes': <Object?>[]});
    final before = file().readAsBytesSync();

    await expectLater(
      store(migrations: [(_) => throw const FormatException('bad')]).open(),
      throwsProblem(DataProblem.migrationFailed),
    );
    expect(file().readAsBytesSync(), before);
    expect(file('.bak').existsSync(), isFalse);
  });

  test('a migration run twice does no harm', () async {
    writeEnvelope(1, {
      'notes': [
        {'id': 'n1', 'text': 'Pain'},
      ],
    });
    final original = file().readAsStringSync();
    var runs = 0;
    Map<String, Object?> counted(Map<String, Object?> data) {
      runs++;
      return renameText(data);
    }

    final first = await store(migrations: [counted]).open();
    expect(await store(migrations: [counted]).open(), first);
    expect(runs, 1, reason: 'an upgraded file is not migrated again');

    // A crash before the upgraded file replaced the old one: it runs again.
    file().writeAsStringSync(original);
    expect(await store(migrations: [counted]).open(), first);
    expect(renameText(first), first, reason: 'the migration is idempotent');
  });

  test('two saves without an await keep the document readable', () async {
    final s = await opened();
    final big = {'notes': List<Object?>.filled(2000, 'a long note')};
    final small = {
      'notes': <Object?>['last'],
    };

    await Future.wait([s.save(big), s.save(small)]);
    expect(await store().open(), small);
  });

  test('a reopen waits for saves still in the queue', () async {
    final s = await opened();
    final latest = {
      'notes': <Object?>['saved without an await'],
    };

    unawaited(s.save(latest));
    expect(await s.open(), latest);
  });

  test('a failed reopen forbids saving over a newer document', () async {
    final s = await opened();
    writeEnvelope(9, {'notes': <Object?>[]});
    final before = file().readAsBytesSync();

    await expectLater(s.open(), throwsProblem(DataProblem.newerSchema));
    await expectLater(s.save({'notes': <Object?>[]}), throwsStateError);
    expect(file().readAsBytesSync(), before);
  });

  test('a file that is not UTF-8 is unreadable', () async {
    file().writeAsBytesSync([0xff, 0xfe, 0x00, 0xc3]);
    await expectLater(store().open(), throwsProblem(DataProblem.unreadable));
  });

  test('read upgrades an older document without saving it', () async {
    writeEnvelope(1, {
      'notes': [
        {'id': 'n1', 'text': 'Pain'},
      ],
    });
    final before = file().readAsBytesSync();
    expect(await store(migrations: [renameText]).read(), {
      'notes': [
        {'id': 'n1', 'body': 'Pain'},
      ],
    });
    expect(file().readAsBytesSync(), before);
  });

  test('replace overwrites an unreadable file, then saving waits for a reopen', () async {
    final s = await opened();
    file().writeAsStringSync('{"cut short');
    await s.replace({'notes': <Object?>[]});
    await expectLater(s.save({'notes': <Object?>[]}), throwsStateError);
    expect(await s.open(), {'notes': <Object?>[]});
  });
}
