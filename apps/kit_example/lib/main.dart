import 'package:app_kit/app_kit.dart';
import 'package:flutter/material.dart';

import 'l10n/example_localizations.dart';

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

Widget buildApp() => KitApp(
  config: exampleConfig,
  seedColor: Colors.indigo,
  localizationsDelegates: const [ExampleLocalizations.delegate],
  home: (_) => const PlaceholderHome(),
);

void main() => runApp(buildApp());

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
