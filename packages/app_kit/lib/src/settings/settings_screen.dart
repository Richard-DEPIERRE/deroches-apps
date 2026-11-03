import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/kit_localizations.dart';
import '../analytics/analytics.dart';
import '../data/backup_service.dart';
import '../data/kit_state.dart';
import '../purchases/purchases.dart';

/// The settings screen every app gets (ADR 0001, section 10): the app's own
/// [appSections] first, then language, the statistics switch, restore
/// purchases, backup and the version. Results show in plain words.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.kitState,
    required this.analytics,
    required this.backup,
    required this.onBackupRestored,
    this.purchases,
    this.appSections = const [],
  });

  final KitStateController kitState;
  final Analytics analytics;
  final BackupService backup;

  /// After a restored backup: the app opens its data stores again, which
  /// refuse to save until then.
  final VoidCallback onBackupRestored;

  /// `null` when the app sells nothing on this platform: no Restore purchases.
  final Purchases? purchases;

  final List<Widget> appSections;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _info = PackageInfo.fromPlatform();
  bool _busy = false;

  /// Runs [work] with the buttons off, then says what [message] makes of it.
  Future<void> _run<T>(Future<T> Function() work, String? Function(KitLocalizations, T) message) async {
    setState(() => _busy = true);
    final T result;
    try {
      result = await work();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    final text = message(KitLocalizations.of(context), result);
    if (text == null) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
  }

  String? _backupMessage(KitLocalizations l10n, BackupResult result, {required bool restore}) {
    switch (result) {
      case BackupDone():
        widget.analytics.track('backup.complete.${restore ? 'restore' : 'export'}');
        if (restore) widget.onBackupRestored();
        return restore ? l10n.settingsBackupRestored : l10n.settingsBackupExported;
      case BackupFailed(:final reason):
        final detail = reason.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
        widget.analytics.track('backup.fail.$detail');
        return reason.message(l10n);
      case BackupCancelled(): // the user's choice: nothing to say
        return null;
    }
  }

  // A failed save keeps the choice on screen; it is asked again next launch.
  void _update(KitState Function(KitState) change) =>
      widget.kitState.update(change).catchError((Object e) => debugPrint('settings: $e'));

  @override
  Widget build(BuildContext context) {
    final l10n = KitLocalizations.of(context);
    final theme = Theme.of(context);
    final purchases = widget.purchases;
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
      ),
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
              header(l10n.settingsPrivacy),
              SwitchListTile(
                title: Text(l10n.settingsStatistics),
                subtitle: Text(l10n.settingsStatisticsDetail),
                value: state?.analyticsEnabled ?? false,
                onChanged: state == null ? null : (on) => _update((s) => s.copyWith(analyticsEnabled: on)),
              ),
              if (purchases != null) ...[
                header(l10n.settingsPurchases),
                ListTile(
                  title: Text(l10n.paywallRestore),
                  enabled: !_busy,
                  onTap: () => _run(
                    purchases.restore,
                    (l10n, result) => switch (result) {
                      RestoreResult.restored => l10n.paywallRestored,
                      RestoreResult.nothingToRestore => l10n.paywallNothingToRestore,
                      RestoreResult.failed => l10n.paywallRestoreFailed,
                    },
                  ),
                ),
              ],
              header(l10n.settingsBackup),
              ListTile(
                title: Text(l10n.settingsBackupExport),
                subtitle: Text(l10n.settingsBackupExportDetail),
                enabled: !_busy,
                onTap: () => _run(widget.backup.export, (l10n, r) => _backupMessage(l10n, r, restore: false)),
              ),
              ListTile(
                title: Text(l10n.settingsBackupRestore),
                subtitle: Text(l10n.settingsBackupRestoreDetail),
                enabled: !_busy,
                onTap: () => _run(widget.backup.restore, (l10n, r) => _backupMessage(l10n, r, restore: true)),
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
