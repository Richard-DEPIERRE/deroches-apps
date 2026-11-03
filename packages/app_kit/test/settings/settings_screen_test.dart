import 'dart:convert';
import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

final config = AppConfig(
  slug: 'carnet-km',
  names: const {'fr': 'Carnet', 'en': 'Logbook'},
  supportEmail: 'support@example.fr',
  legal: {
    for (final lang in kitLanguages)
      lang: LegalLinks(
        legalNotice: Uri.parse('https://example.fr/$lang/legal'),
        privacy: Uri.parse('https://example.fr/$lang/privacy'),
        terms: Uri.parse('https://example.fr/$lang/terms'),
      ),
  },
  plans: const {Plan.yearly},
);

/// What each language shows, as the tests look for it.
const texts = {
  'fr': (
    title: 'Réglages',
    device: 'Langue du téléphone',
    headers: ['Langue', 'Confidentialité', 'Achats', 'Sauvegarde', 'À propos'],
    switchDetail: 'Rien qui vous identifie. Les rapports de plantage suivent ce choix au prochain lancement.',
    switchLabel: 'Partager des statistiques d’utilisation et des rapports de plantage anonymes',
    restorePurchases: 'Restaurer les achats',
    restored: 'Achats restaurés.',
    nothing: 'Aucun achat à restaurer sur ce compte.',
    storeDown: 'Les achats n’ont pas pu être restaurés. Vérifiez votre connexion, puis réessayez.',
    export: 'Exporter une sauvegarde',
    exportDetail: 'Enregistrez‑la dans iCloud Drive, Google Drive ou ailleurs.',
    exported: 'Sauvegarde enregistrée.',
    restore: 'Restaurer une sauvegarde',
    restoreDetail: 'Remplace les données de ce téléphone par celles de la sauvegarde.',
    backupRestored: 'Sauvegarde restaurée.',
    otherApp: 'Cette sauvegarde vient d’une autre application. Vos données n’ont pas changé.',
    version: 'Version 1.2.0 (34)',
  ),
  'en': (
    title: 'Settings',
    device: 'Phone’s language',
    headers: ['Language', 'Privacy', 'Purchases', 'Backup', 'About'],
    switchDetail: 'Nothing that identifies you. Crash reports follow this choice from the next launch.',
    switchLabel: 'Share anonymous usage statistics and crash reports',
    restorePurchases: 'Restore purchases',
    restored: 'Purchases restored.',
    nothing: 'No purchases to restore on this account.',
    storeDown: 'Purchases couldn’t be restored. Check your connection, then try again.',
    export: 'Export a backup',
    exportDetail: 'Save it to iCloud Drive, Google Drive or anywhere you like.',
    exported: 'Backup saved.',
    restore: 'Restore a backup',
    restoreDetail: 'Replaces the data on this phone with the backup’s.',
    backupRestored: 'Backup restored.',
    otherApp: 'This backup comes from another app. Your data hasn’t changed.',
    version: 'Version 1.2.0 (34)',
  ),
};

void main() {
  late Directory dir;
  late FakeAnalyticsBackend sent;
  late FakePurchasesBackend store;
  late FakeBackupFiles files;
  late DataStore notes;
  late int restores;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('settings_');
    addTearDown(() => dir.deleteSync(recursive: true));
    sent = FakeAnalyticsBackend();
    store = FakePurchasesBackend();
    files = FakeBackupFiles();
    notes = DataStore(directory: dir, appId: 'carnet-km', name: 'notes', initial: () => {'notes': <Object?>[]});
    restores = 0;
    PackageInfo.setMockInitialValues(
      appName: 'Logbook',
      packageName: 'fr.example.carnet',
      version: '1.2.0',
      buildNumber: '34',
      buildSignature: '',
    );
  });

  /// The app as a launch opens it, kit state read from disk, on its settings
  /// screen: a small phone at twice the text size. [sells] false: the app
  /// sells nothing on this platform.
  Future<KitStateController> launch(WidgetTester tester, Locale device, {bool sells = true}) async {
    final kit = KitStateController(directory: dir, appId: 'carnet-km');
    await tester.runAsync(kit.load);
    final analytics = Analytics(
      backend: sent,
      kitState: kit,
      appId: 'carnet-km',
      appVersion: '1.2.0',
      locale: () => 'en',
    );
    tester.platformDispatcher.localesTestValue = [device];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view
      ..physicalSize = const Size(640, 1136)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      KitApp(
        config: config,
        seedColor: Colors.teal,
        kitState: kit,
        home: (_) => SettingsScreen(
          kitState: kit,
          analytics: analytics,
          purchases: sells ? Purchases(backend: store, analytics: analytics, plans: config.plans) : null,
          backup: BackupService(appId: 'carnet-km', stores: [notes], files: files),
          onBackupRestored: () => restores++,
          appSections: const [ListTile(title: Text('App section'))],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return kit;
  }

  /// Taps [label], scrolled into view, and lets the real file and store work run.
  /// The last message goes first, as its 4 seconds would: at twice the text
  /// size it covers most of a small phone.
  Future<void> tapAndWait(WidgetTester tester, String label) async {
    ScaffoldMessenger.of(tester.element(find.byType(ListView))).removeCurrentSnackBar();
    await tester.scrollUntilVisible(find.text(label), 100, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pumpAndSettle();
    }
  }

  List<String> events() => [for (final e in sent.events) e.name];

  Future<void> expectVisible(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 100, scrollable: find.byType(Scrollable).first);
    expect(find.text(text), findsOneWidget);
  }

  for (final MapEntry(key: lang, value: t) in texts.entries) {
    final device = Locale(lang);

    // In screen order: scrollUntilVisible only scrolls down.
    testWidgets('$lang: every item is there, on a small phone at large text', (tester) async {
      await launch(tester, device);
      expect(find.text(t.title), findsOneWidget);
      for (final text in [
        'App section',
        t.headers[0],
        t.device,
        'Français',
        'English',
        t.headers[1],
        t.switchLabel,
        t.switchDetail,
        t.headers[2],
        t.restorePurchases,
        t.headers[3],
        t.export,
        t.exportDetail,
        t.restore,
        t.restoreDetail,
        t.headers[4],
        t.version,
      ]) {
        await expectVisible(tester, text);
      }
      expect(tester.takeException(), isNull, reason: 'no overflow at twice the text size');
    });

    testWidgets('$lang: section headers are headings for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await launch(tester, device);
      for (final text in t.headers) {
        await expectVisible(tester, text);
        expect(tester.getSemantics(find.text(text)), matchesSemantics(label: text, isHeader: true));
      }
      expect(find.byType(Divider), findsNothing);
      semantics.dispose();
    });

    testWidgets('$lang: the statistics switch is saved', (tester) async {
      final kit = await launch(tester, device);
      await tapAndWait(tester, t.switchLabel);
      expect(kit.state!.analyticsEnabled, isFalse);
      expect((await launch(tester, device)).state!.analyticsEnabled, isFalse);
    });

    testWidgets('$lang: an app that sells nothing has no Purchases section', (tester) async {
      await launch(tester, device, sells: false);
      await expectVisible(tester, t.version);
      expect(find.text(t.headers[2]), findsNothing);
      expect(find.text(t.restorePurchases), findsNothing);
    });

    testWidgets('$lang: Restore purchases says what happened', (tester) async {
      await launch(tester, device);
      store.failRestore = true;
      await tapAndWait(tester, t.restorePurchases);
      expect(find.text(t.storeDown), findsOneWidget);

      store.failRestore = false;
      await tapAndWait(tester, t.restorePurchases);
      expect(find.text(t.nothing), findsOneWidget);

      store.ownedOnStore = true;
      await tapAndWait(tester, t.restorePurchases);
      expect(find.text(t.restored), findsOneWidget);
      expect(store.entitled.value, isTrue);
    });

    testWidgets('$lang: a backup is exported, then restored', (tester) async {
      await launch(tester, device);
      await tapAndWait(tester, t.export);
      expect(find.text(t.exported), findsOneWidget);
      expect(files.saved, hasLength(1));

      files.picked = files.saved.values.single;
      await tapAndWait(tester, t.restore);
      expect(find.text(t.backupRestored), findsOneWidget);
      expect(restores, 1, reason: 'the app opens its data again');
      expect(events(), containsAllInOrder(['backup.complete.export', 'backup.complete.restore']));
    });

    testWidgets('$lang: a cancelled save dialog says nothing and sends nothing', (tester) async {
      await launch(tester, device);
      files.cancelSave = true;
      await tapAndWait(tester, t.export);
      expect(find.byType(SnackBar), findsNothing);
      expect(events().where((e) => e.startsWith('backup.')), isEmpty);
    });

    testWidgets('$lang: a failed restore shows its reason', (tester) async {
      await launch(tester, device);
      files.picked = utf8.encode(
        jsonEncode({'format': 'deroches.data', 'kind': 'backup', 'app_id': 'other-app', 'documents': <String, Object?>{}}),
      );
      await tapAndWait(tester, t.restore);
      expect(find.text(t.otherApp), findsOneWidget);
      expect(restores, 0);
      expect(events(), contains('backup.fail.other_app'));
    });
  }

  testWidgets('a language change re-renders the app at once and survives a restart', (tester) async {
    await launch(tester, const Locale('fr'));
    await tapAndWait(tester, 'English');
    expect(find.text('Settings'), findsOneWidget);

    final kit = await launch(tester, const Locale('fr'));
    expect(kit.state!.languageOverride, 'en');
    expect(find.text('Settings'), findsOneWidget);

    await tapAndWait(tester, 'Phone’s language');
    expect(find.text('Réglages'), findsOneWidget);
    expect((await launch(tester, const Locale('fr'))).state!.languageOverride, isNull);
  });
}
