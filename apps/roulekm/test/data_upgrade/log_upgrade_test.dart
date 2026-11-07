import 'package:app_kit/testing.dart';
import 'package:roulekm/src/data/logbook.dart';

import 'sample.dart';

/// Every released version's saved log and backup, upgraded and read back (ADR 0001, section 8).
void main() {
  dataUpgradeTests(
    fixtures: 'test/data_upgrade/fixtures',
    appId: roulekmAppId,
    name: logDocument,
    migrations: logMigrations,
    decode: (data) => Logbook.fromJson(data).items,
    expected: {'log.schema1.json': schema1Logbook.items},
    backups: 'test/data_upgrade/backups',
    expectedBackups: {'roulekm-backup.schema1.json': schema1Logbook.items},
  );
}
