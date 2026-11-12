import 'dart:async';

import 'package:app_kit/app_kit.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'l10n/roulekm_localizations.dart';
import 'src/data/log_controller.dart';
import 'src/data/logbook.dart';
import 'src/home/home_screen.dart';
import 'src/onboarding/first_launch.dart';
import 'src/sources/sources_screen.dart';
import 'src/vehicles/vehicles_screen.dart';

/// Roulekm's config, from app-setup A1 (DAPP-133). The Sentry DSN, PostHog key, RevenueCat keys and App Store id stay
/// empty until those exist: until then the app sends nothing and sells nothing.
final roulekmConfig = AppConfig(
  slug: roulekmAppId,
  names: const {'fr': 'Roulekm – frais kilométriques', 'en': 'Roulekm – Mileage Log'},
  supportEmail: 'support@roulekm.fr',
  legal: {
    'fr': LegalLinks(
      legalNotice: Uri.parse('https://roulekm.fr/mentions-legales/'),
      privacy: Uri.parse('https://roulekm.fr/confidentialite/'),
      terms: Uri.parse('https://roulekm.fr/conditions/'),
    ),
    'en': LegalLinks(
      legalNotice: Uri.parse('https://roulekm.fr/en/legal-notice/'),
      privacy: Uri.parse('https://roulekm.fr/en/privacy/'),
      terms: Uri.parse('https://roulekm.fr/en/terms/'),
    ),
  },
  plans: const {Plan.weekly, Plan.yearly, Plan.lifetime},
);

/// The app: onboarding on the first launch, then the home screen (DAPP-141).
Widget buildApp({
  CrashReporter crashReporter = const NoopCrashReporter(),
  required KitStateController kitState,
  required Analytics analytics,
  required RoulekmData data,
  Purchases? purchases,
}) {
  // A log that can't be read is never shown as empty: the error goes to crash reporting and the screens wait.
  final log = LogController(data.log);
  unawaited(log.open());
  final pro = purchases?.entitled ?? ValueNotifier(false);
  return KitApp(
    config: roulekmConfig,
    crashReporter: crashReporter,
    kitState: kitState,
    seedColor: const Color(0xFFC4511A), // DAPP-141 §0
    fontFamily: 'Barlow',
    localizationsDelegates: const [RoulekmLocalizations.delegate],
    home: (context) => FirstLaunch(
      kitState: kitState,
      analytics: analytics,
      log: log,
      home: HomeScreen(
        log: log,
        settings: (context) => SettingsScreen(
          kitState: kitState,
          analytics: analytics,
          backup: data.backup,
          purchases: purchases,
          onBackupRestored: () => unawaited(log.open()),
          appSections: [
            _SectionHeader(RoulekmLocalizations.of(context).settingsAppSection),
            ListTile(
              title: Text(RoulekmLocalizations.of(context).vehiclesTitle),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  // The paywall's hook stays empty until DAPP-148 connects it.
                  builder: (_) => VehiclesScreen(log: log, pro: pro, openPaywall: null),
                ),
              ),
            ),
            ListTile(
              title: Text(RoulekmLocalizations.of(context).sourcesTitle),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SourcesScreen(log: log))),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The kit settings' section header (primary `titleSmall`, a header for screen readers).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationSupportDirectory();
  final kitState = KitStateController(directory: directory, appId: roulekmConfig.slug);
  // Read first: crash reporting starts only while the statistics switch is on (ADR 0005).
  await kitState.load();
  final crashReporter = await startCrashReporting(roulekmConfig, kitState: kitState);
  final analytics = await startAnalytics(
    roulekmConfig,
    kitState: kitState,
    locale: () => resolveKitLocale(WidgetsBinding.instance.platformDispatcher.locales).languageCode,
  );
  final store = await RevenueCatPurchases.start(roulekmConfig);
  final purchases = store == null ? null : Purchases(backend: store, analytics: analytics, plans: roulekmConfig.plans);
  runApp(
    buildApp(
      crashReporter: crashReporter,
      kitState: kitState,
      analytics: analytics,
      data: RoulekmData(directory),
      purchases: purchases,
    ),
  );
}
