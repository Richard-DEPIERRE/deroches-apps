import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/roulekm_localizations.dart';
import '../data/log_controller.dart';
import '../data/totals.dart';
import '../rates/rates.dart';

/// Where the rates come from (DAPP-141 §8): one card per rate table in use, with its official page and the day it
/// was read (DAPP-137), France's line on next year's barème, and the "not affiliated, not tax advice" footer.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key, required this.log, this.now = DateTime.now, this.openLink = _launch});

  final LogController log;
  final DateTime Function() now;

  /// Opens the official page outside the app; false when nothing opened it.
  final Future<bool> Function(Uri) openLink;

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication).catchError((Object _) => false);

  @override
  Widget build(BuildContext context) {
    final l10n = RoulekmLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final today = now();
    final inUse = {for (final v in log.inUse) v.rates};
    // With no vehicle in use yet, every table the app knows.
    final systems = inUse.isEmpty ? RateSystem.values : inUse;
    final france = systems.contains(RateSystem.france) ? ratesFor(RateSystem.france, today) : null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sourcesTitle)),
      body: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
        children: [
          for (final system in systems)
            if (ratesFor(system, today) case final rates?)
              _SourceCard(
                name: switch (system) {
                  RateSystem.france => l10n.sourcesFrance(system.label(rates.year)),
                  // A word joiner keeps "2026–27" on one line.
                  RateSystem.uk => l10n.sourcesUk(system.label(rates.year).replaceAll('–', '–\u2060')),
                  RateSystem.us => l10n.sourcesUs(system.label(rates.year)),
                },
                covers: switch (system) {
                  RateSystem.france => l10n.sourcesFranceCovers('${rates.year}'),
                  RateSystem.uk => l10n.sourcesUkCovers,
                  RateSystem.us => l10n.sourcesUsCovers,
                },
                link: l10n.sourcesLink(
                  rates.source.title,
                  rates.source.site,
                  // One line: "5 nov. 2026" never breaks.
                  DateFormat.yMMMd(lang).format(DateTime.parse(rates.source.readOn)).replaceAll(' ', '\u00a0'),
                ),
                onTap: () => openLink(Uri.parse(rates.source.url)),
              ),
          if (france != null && france.year != france.period)
            _Paragraph(l10n.sourcesNextYear('${france.period}', '${france.period + 1}'), theme.textTheme.bodyMedium),
          _Paragraph(l10n.sourcesFooter, theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.name, required this.covers, required this.link, required this.onTap});

  final String name;
  final String covers;
  final String link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card.filled(
      color: scheme.surfaceContainer,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(covers, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Semantics(
              link: true,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.open_in_new,
                          // Grows with the text, up to 1.5× like the home's icons.
                          size: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5).scale(16),
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(link, style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text, this.style);

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Text(text, style: style),
  );
}
