import 'dart:async';

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

Widget buildApp({CrashReporter crashReporter = const NoopCrashReporter(), required KitStateController kitState}) {
  // No backend: the sample app has no PostHog key, so it sends nothing.
  final analytics = Analytics(
    kitState: kitState,
    appId: exampleConfig.slug,
    appVersion: '0.1.0',
    locale: () => resolveKitLocale(WidgetsBinding.instance.platformDispatcher.locales).languageCode,
    appEvents: notesEvents,
  );
  return KitApp(
    config: exampleConfig,
    crashReporter: crashReporter,
    seedColor: Colors.indigo,
    localizationsDelegates: const [ExampleLocalizations.delegate],
    home: (context) {
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
        child: const PlaceholderHome(),
      );
    },
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sends nothing here: the sample app has no Sentry DSN, and debug builds never send.
  final crashReporter = await startCrashReporting(exampleConfig);
  final kitState = KitStateController(directory: await getApplicationSupportDirectory(), appId: exampleConfig.slug);
  unawaited(kitState.load());
  runApp(buildApp(crashReporter: crashReporter, kitState: kitState));
}

class _Art extends StatelessWidget {
  const _Art(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Icon(icon, size: 96, color: Theme.of(context).colorScheme.primary);
}

/// Shows the wiring works: the app's name from its config, its own strings.
class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(KitScope.of(context).config.names[lang]!)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Text(ExampleLocalizations.of(context).exampleHomeBody, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
    );
  }
}
