import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/kit_localizations.dart';
import '../data/kit_state.dart';

/// The settings screen every app gets (ADR 0001, section 10): the app's own
/// [appSections] first, then language, the statistics switch and the version.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.kitState, this.appSections = const []});

  final KitStateController kitState;
  final List<Widget> appSections;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _info = PackageInfo.fromPlatform();

  // A failed save keeps the choice on screen; it is asked again next launch.
  void _update(KitState Function(KitState) change) =>
      widget.kitState.update(change).catchError((Object e) => debugPrint('settings: $e'));

  @override
  Widget build(BuildContext context) {
    final l10n = KitLocalizations.of(context);
    final theme = Theme.of(context);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListenableBuilder(
        listenable: widget.kitState,
        builder: (context, _) {
          final state = widget.kitState.state;
          return ListView(
            children: [
              ...widget.appSections,
              header(l10n.settingsLanguage),
              RadioGroup<String>(
                groupValue: state?.languageOverride ?? '',
                onChanged: (lang) => _update(
                  (s) => lang == null || lang.isEmpty
                      ? s.copyWith(clearLanguageOverride: true)
                      : s.copyWith(languageOverride: lang),
                ),
                child: Column(
                  children: [
                    for (final (value, label) in [
                      ('', l10n.settingsLanguageDevice),
                      ('fr', l10n.settingsLanguageFrench),
                      ('en', l10n.settingsLanguageEnglish),
                    ])
                      RadioListTile(value: value, title: Text(label), enabled: state != null),
                  ],
                ),
              ),
              const Divider(),
              SwitchListTile(
                title: Text(l10n.settingsStatistics),
                subtitle: Text(l10n.settingsStatisticsDetail),
                value: state?.analyticsEnabled ?? false,
                onChanged: state == null ? null : (on) => _update((s) => s.copyWith(analyticsEnabled: on)),
              ),
              header(l10n.settingsAbout),
              FutureBuilder(
                future: _info,
                builder: (context, info) => ListTile(
                  title: Text(switch (info.data) {
                    final i? => l10n.settingsVersion(i.version, i.buildNumber),
                    null => '',
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
