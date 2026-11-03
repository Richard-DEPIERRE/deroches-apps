import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/kit_localizations.dart';
import '../analytics/analytics.dart';
import '../app/kit_scope.dart';
import '../data/backup_service.dart';
import '../data/kit_state.dart';
import '../purchases/purchases.dart';

/// The settings screen every app gets (ADR 0001, section 10): the app's own
/// [appSections] first, then language, the statistics switch with the privacy
/// policy, restore purchases, backup, then "Contact support", "Rate the app"
/// (the store page, not the prompt), the legal notice and terms, and the
/// version. Legal pages follow the language shown. Results show in plain words.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.kitState,
    required this.analytics,
    required this.backup,
    required this.onBackupRestored,
    this.purchases,
    this.appSections = const [],
    this.openLink = _launch,
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

  /// Opens a store page, the support email or a legal page; false when nothing
  /// opened it. Outside the app, so store pages open in the store app.
  final Future<bool> Function(Uri) openLink;

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication).catchError((Object _) => false);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _info = PackageInfo.fromPlatform();

  /// The item whose work is running: it spins, the others wait.
  _Action? _running;

  /// Runs [action]'s [work], then, if the screen is still open, says what
  /// [message] makes of it. A failure stays 8 seconds with a close button: it
  /// says what to do next; one with an action stays until the user acts or
  /// closes it. Anything that must happen anyway belongs in [work].
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
    if (said != null) _say(said);
  }

  void _say(_Said said) => ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(said.text),
        duration: said.failure ? const Duration(seconds: 8) : const Duration(seconds: 4),
        showCloseIcon: said.failure,
        action: said.action,
        persist: said.action != null,
      ),
    );

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
    BackupDone() => _Said(restore ? l10n.settingsBackupRestored : l10n.settingsBackupExported),
    BackupFailed(:final reason) => _Said(reason.message(l10n), failure: true),
    BackupCancelled() => null, // the user's choice: nothing to say
  };

  /// The store page to rate the app on this platform; null hides the item.
  Future<Uri> Function()? _ratePage(String? appStoreId) => switch (defaultTargetPlatform) {
    TargetPlatform.iOS when appStoreId != null => () async =>
        Uri.parse('https://apps.apple.com/app/id$appStoreId?action=write-review'),
    TargetPlatform.android => () async =>
        Uri.https('play.google.com', '/store/apps/details', {'id': (await _info).packageName}),
    _ => null,
  };

  /// The support email: the app's name and version as subject; the version,
  /// the system and the language under the user's words. No identifier, ever.
  Future<Uri> _supportMail(String email, String name, String language, KitLocalizations l10n) async {
    final info = await _info;
    final version = '${info.version} (${info.buildNumber})';
    final body = l10n.settingsSupportBody(version, await _system(), language);
    // Encoded by hand: Uri's query encoding writes spaces as +, which mail apps show.
    return Uri.parse(
      'mailto:$email?subject=${Uri.encodeComponent('$name $version')}&body=${Uri.encodeComponent(body)}',
    );
  }

  /// The system for the support email. Dart gives a build string on iOS and the
  /// kernel's on Android, so Android's release comes from its build property.
  static Future<String> _system() async => describeSystem(
    Platform.operatingSystem,
    Platform.operatingSystemVersion,
    androidRelease: await _androidProperty('ro.build.version.release'),
  );

  /// An Android build property, such as `ro.build.version.sdk`; null elsewhere or unreadable.
  static Future<String?> _androidProperty(String name) async {
    if (!Platform.isAndroid) return null;
    try {
      final value = '${(await Process.run('getprop', [name])).stdout}'.trim();
      return value.isEmpty ? null : value;
    } on Object catch (e) {
      debugPrint('settings: no $name: $e');
      return null;
    }
  }

  /// Copies the support address, and says so unless the system already does.
  Future<void> _copy(String email, String copied) async {
    await Clipboard.setData(ClipboardData(text: email));
    final sdk = int.tryParse(await _androidProperty('ro.build.version.sdk') ?? '');
    if (mounted && confirmsCopy(android: Platform.isAndroid, sdk: sdk)) _say(_Said(copied));
  }

  // A failed save keeps the choice on screen; it is asked again next launch.
  void _update(KitState Function(KitState) change) =>
      widget.kitState.update(change).catchError((Object e) => debugPrint('settings: $e'));

  @override
  Widget build(BuildContext context) {
    final l10n = KitLocalizations.of(context);
    final theme = Theme.of(context);
    final purchases = widget.purchases;
    final config = KitScope.of(context).config;
    final language = Localizations.localeOf(context).languageCode;
    final legal = config.legal[language]!;
    final ratePage = _ratePage(config.appStoreId);
    Widget item<T>(
      _Action action,
      String title,
      Future<T> Function() work,
      _Said? Function(KitLocalizations, T) message, {
      String? subtitle,
      Widget? trailing,
    }) => ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      enabled: _running == null,
      trailing: _running != action
          ? trailing
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
    // A row that leaves the app says so; the icon is decorative, the row is the button.
    final leaves = Icon(Icons.open_in_new, size: 20, color: theme.colorScheme.onSurfaceVariant);
    Widget link(_Action action, String title, Future<Uri> Function() page, {_Said? failed}) => item(
      action,
      title,
      () async => widget.openLink(await page()),
      (l10n, bool opened) => opened ? null : failed ?? _Said(l10n.settingsLinkFailed, failure: true),
      trailing: leaves,
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
              link(_Action.privacy, l10n.settingsPrivacyPolicy, () async => legal.privacy),
              if (purchases != null) ...[
                header(l10n.settingsPurchases),
                item(
                  _Action.restorePurchases,
                  l10n.paywallRestore,
                  purchases.restore,
                  (l10n, result) => switch (result) {
                    RestoreResult.restored => _Said(l10n.paywallRestored),
                    RestoreResult.nothingToRestore => _Said(l10n.paywallNothingToRestore),
                    RestoreResult.failed => _Said(l10n.paywallRestoreFailed, failure: true),
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
              link(
                _Action.support,
                l10n.settingsSupport,
                () {
                  widget.analytics.track('support.tap.email');
                  return _supportMail(config.supportEmail, config.names[language]!, language, l10n);
                },
                // A floating message can't be selected: the address is one tap to copy.
                failed: _Said(
                  l10n.settingsSupportNoMailApp(config.supportEmail),
                  failure: true,
                  action: SnackBarAction(
                    label: l10n.settingsSupportCopy,
                    onPressed: () => _copy(config.supportEmail, l10n.settingsSupportCopied),
                  ),
                ),
              ),
              if (ratePage != null) link(_Action.rate, l10n.settingsRate, ratePage),
              link(_Action.legalNotice, l10n.settingsLegalNotice, () async => legal.legalNotice),
              link(_Action.terms, l10n.settingsTerms, () async => legal.terms),
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

enum _Action { restorePurchases, exportBackup, restoreBackup, rate, support, legalNotice, privacy, terms }

/// "iOS 18.1", "Android 14": the system as support reads it, from Dart's
/// [os] and [version] and, on Android, the release; never a build or kernel string.
@visibleForTesting
String describeSystem(String os, String version, {String? androidRelease}) => switch (os) {
  'ios' => 'iOS ${RegExp(r'\d+(\.\d+)*').firstMatch(version)?[0] ?? ''}'.trim(),
  'android' => 'Android ${androidRelease ?? ''}'.trim(),
  _ => '$os $version',
};

/// Whether the app confirms a copy: Android 13 (API 33) and later show their
/// own confirmation, and a second one is noise. An unknown level confirms.
@visibleForTesting
bool confirmsCopy({required bool android, int? sdk}) => !android || sdk == null || sdk < 33;

/// What a message says, whether it is a failure, and what it offers to do.
class _Said {
  const _Said(this.text, {this.failure = false, this.action});

  final String text;
  final bool failure;
  final SnackBarAction? action;
}
