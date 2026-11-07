import 'package:app_kit/app_kit.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'l10n/roulekm_localizations.dart';
import 'src/data/logbook.dart';

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

/// The app. Its home is a placeholder until DAPP-144 to DAPP-147 bring the Designer's screens (DAPP-141).
Widget buildApp({
  CrashReporter crashReporter = const NoopCrashReporter(),
  required KitStateController kitState,
  required Analytics analytics,
  required RoulekmData data,
  Purchases? purchases,
}) => KitApp(
  config: roulekmConfig,
  crashReporter: crashReporter,
  kitState: kitState,
  seedColor: const Color(0xFF8E4D31), // the site's accent (sites/roulekm/site.json) until the Designer's theme
  localizationsDelegates: const [RoulekmLocalizations.delegate],
  home: (context) => PlaceholderHome(
    settings: (_) => SettingsScreen(
      kitState: kitState,
      analytics: analytics,
      backup: data.backup,
      purchases: purchases,
      onBackupRestored: () => data.log.open().ignore(),
    ),
  ),
);

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

/// Never ships: the app's name, one line, and the kit's settings (language, backup, legal links, support).
class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key, required this.settings});

  final WidgetBuilder settings;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(KitScope.of(context).config.names[lang]!),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: KitLocalizations.of(context).settingsTitle,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: settings)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(RoulekmLocalizations.of(context).roulekmPlaceholderBody),
        ),
      ),
    );
  }
}
