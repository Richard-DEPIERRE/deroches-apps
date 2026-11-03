import 'package:app_kit/app_kit.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'l10n/example_localizations.dart';
import 'notes.dart';

/// The kit's sample app (ADR 0001, section 2). Its screens never ship.
final exampleConfig = AppConfig(
  slug: 'kit-example',
  names: const {'fr': 'Exemple du kit', 'en': 'Kit example'},
  supportEmail: 'support@example.com',
  legal: {
    for (final lang in kitLanguages)
      lang: LegalLinks(
        legalNotice: Uri.parse('https://example.com/$lang/legal-notice'),
        privacy: Uri.parse('https://example.com/$lang/privacy'),
        terms: Uri.parse('https://example.com/$lang/terms'),
      ),
  },
  plans: const {Plan.weekly, Plan.yearly, Plan.lifetime},
);

/// The sample app. [screen], for screenshots, replaces its home (onboarding first).
/// Without [purchases] (no RevenueCat key) it sells nothing.
Widget buildApp({
  WidgetBuilder? screen,
  CrashReporter crashReporter = const NoopCrashReporter(),
  required KitStateController kitState,
  required Analytics analytics,
  required ExampleData data,
  Purchases? purchases,
  StoreReview review = const InAppStoreReview(),
}) {
  final rating = RatingPrompt(kitState: kitState, review: review, analytics: analytics);
  final gate = PaywallGate(kitState);
  return KitApp(
    config: exampleConfig,
    crashReporter: crashReporter,
    kitState: kitState,
    seedColor: Colors.indigo,
    localizationsDelegates: const [ExampleLocalizations.delegate],
    home: (context) {
      if (screen != null) return screen(context);
      final l10n = ExampleLocalizations.of(context);
      return OnboardingFlow(
        kitState: kitState,
        analytics: analytics,
        pages: [
          OnboardingPage(
            title: l10n.exampleOnboarding1Title,
            body: l10n.exampleOnboarding1Body,
            illustration: const _Art(Icons.waving_hand),
          ),
          OnboardingPage(
            title: l10n.exampleOnboarding2Title,
            body: l10n.exampleOnboarding2Body,
            illustration: const _Art(Icons.lock),
          ),
        ],
        child: PlaceholderHome(
          rating: rating,
          gate: gate,
          kitState: kitState,
          purchases: purchases,
          settings: (_) => SettingsScreen(
            kitState: kitState,
            analytics: analytics,
            backup: data.backup,
            purchases: purchases,
            onBackupRestored: () => data.notes.open().ignore(),
          ),
        ),
      );
    },
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationSupportDirectory();
  final kitState = KitStateController(directory: directory, appId: exampleConfig.slug);
  // Read first: crash reporting starts only while the statistics switch is on (ADR 0005).
  await kitState.load();
  // Sends nothing here: the sample app has no Sentry DSN, and debug builds never send.
  final crashReporter = await startCrashReporting(exampleConfig, kitState: kitState);
  // Sends nothing here either: the sample app has no PostHog key.
  final analytics = await startAnalytics(
    exampleConfig,
    kitState: kitState,
    locale: () => resolveKitLocale(WidgetsBinding.instance.platformDispatcher.locales).languageCode,
    appEvents: notesEvents,
  );
  // Null here: the sample app has no RevenueCat key, so it sells nothing.
  final store = await RevenueCatPurchases.start(exampleConfig);
  final purchases = store == null ? null : Purchases(backend: store, analytics: analytics, plans: exampleConfig.plans);
  runApp(
    buildApp(
      crashReporter: crashReporter,
      kitState: kitState,
      analytics: analytics,
      data: ExampleData(directory),
      purchases: purchases,
    ),
  );
}

class _Art extends StatelessWidget {
  const _Art(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(shape: BoxShape.circle, color: colors.primaryContainer),
      child: Icon(icon, size: 96, color: colors.onPrimaryContainer),
    );
  }
}

/// Shows the wiring works: the app's name from its config, its own strings,
/// a good moment reported to the rating prompt and the paywall gate, and the
/// plans once the gate allows them.
class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({
    super.key,
    required this.rating,
    required this.gate,
    required this.kitState,
    required this.settings,
    this.purchases,
  });

  final RatingPrompt rating;
  final PaywallGate gate;
  final KitStateController kitState;
  final Purchases? purchases;
  final WidgetBuilder settings;

  static const placement = 'home';

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ExampleLocalizations.of(context).exampleHomeBody, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              FilledButton(
                // In a real app: the first note saved.
                onPressed: () {
                  gate.markFirstValue();
                  rating.goodMoment();
                },
                child: Text(ExampleLocalizations.of(context).exampleGoodMoment),
              ),
              ListenableBuilder(
                listenable: kitState,
                builder: (context, _) {
                  final purchases = this.purchases;
                  if (purchases == null || !gate.canShow(placement)) return const SizedBox.shrink();
                  final l10n = ExampleLocalizations.of(context);
                  // The label lines up with the text above; the pressed highlight spills into the margin.
                  final rtl = Directionality.of(context) == TextDirection.rtl;
                  return Transform.translate(
                    offset: Offset(rtl ? 12 : -12, 0),
                    child: TextButton(
                      onPressed: () => showPaywall(
                        context,
                        placement: placement,
                        gate: gate,
                        purchases: purchases,
                        header: Text(l10n.examplePaywallHeader),
                      ),
                      child: Text(l10n.exampleSeePlans),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
