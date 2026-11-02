/// The DeRoches Apps app kit (ADR 0001, `docs/adr/0001-monorepo-and-app-kit.md`).
library;

export 'l10n/kit_localizations.dart';
export 'src/app/kit_app.dart';
export 'src/app/kit_error_view.dart';
export 'src/app/kit_scope.dart';
export 'src/config/app_config.dart';
export 'src/crash/crash_reporter.dart';
export 'src/crash/sentry_crash_reporter.dart' hide configureSentry;
export 'src/data/data_store.dart';
export 'src/l10n/language.dart';
