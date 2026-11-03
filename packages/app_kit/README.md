# app_kit

The DeRoches Apps app kit: every studio app is built on it. The decisions are in ADR 0001
(`docs/adr/0001-monorepo-and-app-kit.md`); the public API is `lib/app_kit.dart`, the test fakes and helpers
`lib/testing.dart`.

## Backup (ADR 0001, section 9)

Two layers, both through the user's own iCloud or Google account: no sign-in, no server.

**Automatic: what each app keeps in its native folders**
- Open every `DataStore` in path_provider's `getApplicationSupportDirectory()`: `Library/Application Support/` on
  iOS, the app's `files/` folder on Android. Never the cache or temporary folder, which no backup takes.
- iOS: that folder goes into the iCloud device backup by default. Never set `isExcludedFromBackup`
  (`NSURLIsExcludedFromBackupKey`) on it or on a document.
- Android: copy `res/xml/data_extraction_rules.xml` (Android 12+) and `res/xml/full_backup_content.xml` (older
  versions) from `apps/kit_example/android/app/src/main/`, and set `android:allowBackup="true"`,
  `android:dataExtractionRules` and `android:fullBackupContent` on `<application>` in `AndroidManifest.xml`, as
  kit_example does. Both include the whole `files` folder, so Auto Backup takes it to the user's Google account and
  to a new phone. Copy `test/backup_rules_test.dart` too: it checks the rules.
- Only that folder is backed up on Android: SDK state kept elsewhere (RevenueCat's, PostHog's) is not, and doesn't
  need to be. Purchases come back with "Restore purchases".

**By hand, from settings**
- One `BackupService(appId: …, stores: [every DataStore of the app])`.
- `export()` writes every document, at its schema, into one file (`"kind": "backup"`) and opens the system save
  dialog. `restore()` opens the file picker, then reads, checks and migrates the whole file before touching anything,
  keeps each current document as `<name>.json.before-restore`, and replaces it; if a write fails, every document is
  put back. A document the backup doesn't hold is left as it is.
- Both return a `BackupResult`: `BackupDone`, `BackupCancelled` or `BackupFailed` with a `BackupFailure`, whose
  `message(KitLocalizations.of(context))` tells the user why, in their language. After a restore, open the stores
  again: a store refuses to save until then, so the app's old in-memory data can't overwrite the restored data.
- Keep each released version's exported backup under `test/data_upgrade/backups/` and pass it to
  `dataUpgradeTests(backups: …, expectedBackups: …)`, as kit_example does.
