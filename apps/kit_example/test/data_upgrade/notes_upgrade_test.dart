import 'package:app_kit/testing.dart';
import 'package:kit_example/notes.dart';

void main() {
  dataUpgradeTests(
    fixtures: 'test/data_upgrade/fixtures',
    appId: notesAppId,
    name: notesDocument,
    migrations: notesMigrations,
    decode: Note.decodeAll,
    expected: {
      'notes.schema1.json': [
        Note(id: 'n1', body: 'Acheter du pain', created: DateTime.utc(2026, 10, 28, 8, 15)),
        Note(id: 'n2', body: 'Rappeler le garage', created: DateTime.utc(2026, 10, 30, 17, 40)),
        Note(id: 'n3', body: 'Arroser les tomates', created: DateTime.utc(2026, 10, 31, 19, 5)),
      ],
    },
    backups: 'test/data_upgrade/backups',
    expectedBackups: {
      'kit-example-backup.schema1.json': [
        Note(id: 'n1', body: 'Acheter du pain', created: DateTime.utc(2026, 10, 28, 8, 15)),
        Note(id: 'n2', body: 'Rappeler le garage', created: DateTime.utc(2026, 10, 30, 17, 40)),
      ],
    },
  );
}
