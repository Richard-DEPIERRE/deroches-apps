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

  /// The item whose work is running: it spins, the others wait.
  _Action? _running;

  /// Runs [action]'s [work], then, if the screen is still open, says what
  /// [message] makes of it. A failure stays 8 seconds with a close button: it
  /// says what to do next. Anything that must happen anyway belongs in [work].
  Future<void> _run<T>(_Action action, Future<T> Function() work, _Said? Function(KitLocalizations, T) message) async {
    setState(() => _running = action);
    final T result;
    try {
      result = await work();
    } finally {
      if (mounted) setState(() => _running = null);
    }
    if (!mounted) return;
    final said = message(KitLocalizations.of(context), result);
    if (said == null) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(said.text),
          duration: said.failure ? const Duration(seconds: 8) : const Duration(seconds: 4),
          showCloseIcon: said.failure,
        ),
      );
  }

  /// Exports or restores, then sends its event and, after a restore, reopens
  /// the app's stores: even if the user has left the screen meanwhile, or the
  /// stores would refuse every save until the next launch.
  Future<BackupResult> _backup({required bool restore}) async {
    final result = await (restore ? widget.backup.restore() : widget.backup.export());
    switch (result) {
      case BackupDone():
        widget.analytics.track('backup.complete.${restore ? 'restore' : 'export'}');
        if (restore) widget.onBackupRestored();
      case BackupFailed(:final reason):
        final detail = reason.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
        widget.analytics.track('backup.fail.$detail');
      case BackupCancelled():
    }
    return result;
  }

  _Said? _backupMessage(KitLocalizations l10n, BackupResult result, {required bool restore}) => switch (result) {
    BackupDone() => (text: restore ? l10n.settingsBackupRestored : l10n.settingsBackupExported, failure: false),
    BackupFailed(:final reason) => (text: reason.message(l10n), failure: true),
    BackupCancelled() => null, // the user's choice: nothing to say
  };

  // A failed save keeps the choice on screen; it is asked again next launch.
  void _update(KitState Function(KitState) change) =>
      widget.kitState.update(change).catchError((Object e) => debugPrint('settings: $e'));

  @override
  Widget build(BuildContext context) {
    final l10n = KitLocalizations.of(context);
    final theme = Theme.of(context);
    final purchases = widget.purchases;
    Widget item<T>(
      _Action action,
      String title,
      Future<T> Function() work,
      _Said? Function(KitLocalizations, T) message, {
      String? subtitle,
    }) => ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      enabled: _running == null,
      trailing: _running != action
          ? null
          : SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
                semanticsLabel: l10n.settingsBusy,
              ),
            ),
      onTap: () => _run(action, work, message),
    );
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
                item(
                  _Action.restorePurchases,
                  l10n.paywallRestore,
                  purchases.restore,
                  (l10n, result) => switch (result) {
                    RestoreResult.restored => (text: l10n.paywallRestored, failure: false),
                    RestoreResult.nothingToRestore => (text: l10n.paywallNothingToRestore, failure: false),
                    RestoreResult.failed => (text: l10n.paywallRestoreFailed, failure: true),
                  },
                ),
              ],
              header(l10n.settingsBackup),
              item(
                _Action.exportBackup,
                l10n.settingsBackupExport,
                () => _backup(restore: false),
                (l10n, r) => _backupMessage(l10n, r, restore: false),
                subtitle: l10n.settingsBackupExportDetail,
              ),
              item(
                _Action.restoreBackup,
                l10n.settingsBackupRestore,
                () => _backup(restore: true),
                (l10n, r) => _backupMessage(l10n, r, restore: true),
                subtitle: l10n.settingsBackupRestoreDetail,
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

enum _Action { restorePurchases, exportBackup, restoreBackup }

/// What a message says, and whether it is a failure.
typedef _Said = ({String text, bool failure});
