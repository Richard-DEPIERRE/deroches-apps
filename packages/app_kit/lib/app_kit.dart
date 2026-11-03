/// The DeRoches Apps app kit (ADR 0001, `docs/adr/0001-monorepo-and-app-kit.md`).
library;

export 'l10n/kit_localizations.dart';
export 'src/analytics/analytics.dart';
export 'src/analytics/events.dart';
export 'src/analytics/posthog_backend.dart' hide postHogConfig;
export 'src/app/kit_app.dart';
export 'src/app/kit_error_view.dart';
export 'src/app/kit_scope.dart';
export 'src/config/app_config.dart';
export 'src/crash/crash_reporter.dart';
export 'src/crash/sentry_crash_reporter.dart' hide configureSentry;
export 'src/data/backup_service.dart';
export 'src/data/data_store.dart';
export 'src/data/kit_state.dart';
export 'src/l10n/language.dart';
export 'src/onboarding/onboarding_flow.dart';
export 'src/purchases/paywall_gate.dart';
export 'src/purchases/purchases.dart';
export 'src/purchases/revenuecat_purchases.dart' show RevenueCatPurchases;
