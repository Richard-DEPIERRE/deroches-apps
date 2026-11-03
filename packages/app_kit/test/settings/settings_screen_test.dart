import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

AppConfig makeConfig({String? appStoreId = '6478123456'}) => AppConfig(
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
  appStoreId: appStoreId,
);
final config = makeConfig();

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
    busy: 'En cours',
    rate: 'Noter l’application',
    support: 'Contacter l’assistance',
    legalNotice: 'Mentions légales',
    privacyPolicy: 'Politique de confidentialité',
    terms: 'Conditions d’utilisation',
    mailBody: '\n\n—\nApplication\u00a0: 1.2.0 (34)\nSystème\u00a0: {system}\nLangue\u00a0: fr',
    noMailApp: 'Aucune application de messagerie. Écrivez à support@example.fr.',
    copy: 'Copier',
    copied: 'Adresse copiée.',
    linkFailed: 'La page n’a pas pu s’ouvrir. Réessayez plus tard.',
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
    busy: 'In progress',
    rate: 'Rate the app',
    support: 'Contact support',
    legalNotice: 'Legal notice',
    privacyPolicy: 'Privacy policy',
    terms: 'Terms of use',
    mailBody: '\n\n—\nApp: 1.2.0 (34)\nSystem: {system}\nLanguage: en',
    noMailApp: 'No email app found. Write to support@example.fr.',
    copy: 'Copy',
    copied: 'Address copied.',
    linkFailed: 'The page couldn’t be opened. Try again later.',
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
  late List<Uri> opened;
  late bool linksOpen;
  Completer<void>? holdLink;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('settings_');
    addTearDown(() => dir.deleteSync(recursive: true));
    sent = FakeAnalyticsBackend();
    store = FakePurchasesBackend();
    files = FakeBackupFiles();
    notes = DataStore(directory: dir, appId: 'carnet-km', name: 'notes', initial: () => {'notes': <Object?>[]});
    restores = 0;
    opened = [];
    linksOpen = true;
    holdLink = null;
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
  Future<KitStateController> launch(
    WidgetTester tester,
    Locale device, {
    bool sells = true,
    bool pushed = false,
    AppConfig? appConfig,
  }) async {
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
        config: appConfig ?? config,
        seedColor: Colors.teal,
        kitState: kit,
        home: (_) {
          final settings = SettingsScreen(
            kitState: kit,
            analytics: analytics,
            purchases: sells ? Purchases(backend: store, analytics: analytics, plans: config.plans) : null,
            backup: BackupService(appId: 'carnet-km', stores: [notes], files: files),
            onBackupRestored: () => restores++,
            appSections: const [ListTile(title: Text('App section'))],
            openLink: (uri) async {
              opened.add(uri);
              await holdLink?.future;
              return linksOpen;
            },
          );
          // [pushed]: settings opened from the app's home, as apps do.
          return !pushed
              ? settings
              : Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => settings)),
                      child: const Text('Open settings'),
                    ),
                  ),
                );
        },
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
    // A spinner turns until the work is done: only then can the screen settle.
    final spinning = find.byType(CircularProgressIndicator);
    for (var i = 0; i < 100 && (i < 10 || spinning.evaluate().isNotEmpty); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  /// A failure stays 8 seconds with a close button; anything else, the default 4 without.
  void expectMessage(WidgetTester tester, {required bool failure}) {
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.duration, failure ? const Duration(seconds: 8) : const Duration(seconds: 4));
    expect(bar.showCloseIcon, failure);
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
        t.privacyPolicy,
        t.headers[2],
        t.restorePurchases,
        t.headers[3],
        t.export,
        t.exportDetail,
        t.restore,
        t.restoreDetail,
        t.headers[4],
        t.support,
        t.rate,
        t.legalNotice,
        t.terms,
        t.version,
      ]) {
        await expectVisible(tester, text);
      }
      expect(tester.takeException(), isNull, reason: 'no overflow at twice the text size');
    });

    testWidgets('$lang: the legal links open the site’s pages in this language', (tester) async {
      await launch(tester, device);
      // The privacy policy sits under the statistics switch it explains.
      for (final text in [t.privacyPolicy, t.legalNotice, t.terms]) {
        await tapAndWait(tester, text);
      }
      final legal = config.legal[lang]!;
      expect(opened, [legal.privacy, legal.legalNotice, legal.terms]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('$lang: Rate the app opens the App Store’s review page on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await launch(tester, device);
      await tapAndWait(tester, t.rate);
      expect(opened, [Uri.parse('https://apps.apple.com/app/id6478123456?action=write-review')]);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('$lang: Rate the app is hidden on iOS without an App Store id', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await launch(tester, device, appConfig: makeConfig(appStoreId: null));
      await expectVisible(tester, t.version);
      expect(find.text(t.rate), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('$lang: Rate the app opens the Play page for the package on Android', (tester) async {
      await launch(tester, device, appConfig: makeConfig(appStoreId: null));
      await tapAndWait(tester, t.rate);
      expect(opened, [Uri.parse('https://play.google.com/store/apps/details?id=fr.example.carnet')]);
    });

    testWidgets('$lang: Contact support writes to the app’s address, with no identifier', (tester) async {
      await launch(tester, device);
      await tapAndWait(tester, t.support);
      final mail = opened.single;
      expect(mail.scheme, 'mailto');
      expect(mail.path, 'support@example.fr');
      expect(mail.queryParameters.keys, ['subject', 'body']);
      expect(mail.queryParameters['subject'], '${config.names[lang]} 1.2.0 (34)');
      // Exactly the version, the system and the language: no install id, package or anything else.
      final system = describeSystem(Platform.operatingSystem, Platform.operatingSystemVersion);
      expect(mail.queryParameters['body'], t.mailBody.replaceAll('{system}', system));
      expect(mail.toString(), isNot(contains('+')), reason: 'spaces as %20: mail apps show a + as is');
      expect(events(), contains('support.tap.email'));
    });

    testWidgets('$lang: without an email app, Contact support gives the address to copy', (tester) async {
      final copied = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text']);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await launch(tester, device);
      linksOpen = false;
      await tapAndWait(tester, t.support);
      expect(find.text(t.noMailApp), findsOneWidget);
      // It stays until the user copies or closes it: the address is the content.
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect((bar.persist, bar.showCloseIcon), (true, true));
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(find.text(t.noMailApp), findsOneWidget, reason: 'still there after 9 s');

      // Pressed, not tapped: the test font's square glyphs push the action below a
      // 320 pt screen at twice the text size, which Roboto doesn't (design review shots).
      tester.widget<SnackBarAction>(find.widgetWithText(SnackBarAction, t.copy)).onPressed();
      await tester.pumpAndSettle();
      expect(copied, ['support@example.fr']);
      expect(find.text(t.copied), findsOneWidget);
      expectMessage(tester, failure: false);

      await tapAndWait(tester, t.terms);
      expect(find.text(t.linkFailed), findsOneWidget);
      expectMessage(tester, failure: true);
    });

    testWidgets('$lang: rows that leave the app say so; the running one spins instead', (tester) async {
      final semantics = tester.ensureSemantics();
      await launch(tester, device);
      tester.view.physicalSize = const Size(640, 10000); // every row built, at twice the text size
      await tester.pumpAndSettle();
      Finder icon(String row) =>
          find.descendant(of: find.widgetWithText(ListTile, row), matching: find.byIcon(Icons.open_in_new));
      for (final row in [t.privacyPolicy, t.support, t.rate, t.legalNotice, t.terms]) {
        expect(icon(row), findsOneWidget, reason: row);
        final glyph = tester.widget<Icon>(icon(row));
        expect((glyph.size, glyph.semanticLabel), (20, null), reason: 'decorative: the row is the button');
      }
      expect(icon(t.version), findsNothing);
      expect(find.byIcon(Icons.open_in_new), findsNWidgets(5));
      expect(tester.getSemantics(find.widgetWithText(ListTile, t.terms)).label, t.terms);

      holdLink = Completer();
      await tester.tap(find.text(t.terms));
      await tester.pump();
      expect(icon(t.terms), findsNothing);
      expect(
        find.descendant(of: find.widgetWithText(ListTile, t.terms), matching: find.byType(CircularProgressIndicator)),
        findsOneWidget,
      );
      holdLink!.complete();
      await tester.pumpAndSettle();
      expect(icon(t.terms), findsOneWidget);
      semantics.dispose();
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
      expectMessage(tester, failure: true);

      store.failRestore = false;
      await tapAndWait(tester, t.restorePurchases);
      expect(find.text(t.nothing), findsOneWidget);
      expectMessage(tester, failure: false);

      store.ownedOnStore = true;
      await tapAndWait(tester, t.restorePurchases);
      expect(find.text(t.restored), findsOneWidget);
      expectMessage(tester, failure: false);
      expect(store.entitled.value, isTrue);
    });

    testWidgets('$lang: the running item spins, named for screen readers, the others wait', (tester) async {
      final semantics = tester.ensureSemantics();
      await launch(tester, device);
      // A tall phone: every item is built, no scrolling while the spinner turns.
      tester.view.physicalSize = const Size(640, 4000);
      await tester.pumpAndSettle();
      store.holdRestore = Completer();
      await tester.scrollUntilVisible(find.text(t.restorePurchases), 100, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.restorePurchases));
      await tester.pump();

      final tile = find.widgetWithText(ListTile, t.restorePurchases);
      expect(find.descendant(of: tile, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: 'only on the item that runs');
      // The tile reads its title, then the spinner's label.
      expect(tester.getSemantics(find.byType(CircularProgressIndicator)).label, '${t.restorePurchases}\n${t.busy}');
      for (final other in [t.restorePurchases, t.export, t.restore]) {
        expect(tester.widget<ListTile>(find.widgetWithText(ListTile, other)).enabled, isFalse, reason: other);
      }

      store.holdRestore!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<ListTile>(find.widgetWithText(ListTile, t.export)).enabled, isTrue);
      semantics.dispose();
    });

    testWidgets('$lang: a backup is exported, then restored', (tester) async {
      await launch(tester, device);
      await tapAndWait(tester, t.export);
      expect(find.text(t.exported), findsOneWidget);
      expectMessage(tester, failure: false);
      expect(files.saved, hasLength(1));

      files.picked = files.saved.values.single;
      await tapAndWait(tester, t.restore);
      expect(find.text(t.backupRestored), findsOneWidget);
      expect(restores, 1, reason: 'the app opens its data again');
      expect(events(), containsAllInOrder(['backup.complete.export', 'backup.complete.restore']));
    });

    testWidgets('$lang: a restore that ends after the screen closed still reopens the data', (tester) async {
      await launch(tester, device);
      await tapAndWait(tester, t.export);
      files
        ..picked = files.saved.values.single
        ..holdPick = Completer();
      await tester.scrollUntilVisible(find.text(t.restore), 100, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.restore));
      await tester.pump();

      await tester.pumpWidget(const SizedBox()); // the user leaves settings
      files.holdPick!.complete();
      for (var i = 0; i < 50 && restores == 0; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      }
      expect(restores, 1, reason: 'otherwise the stores stay closed and every save fails');
      expect(events(), contains('backup.complete.restore'));
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
      expectMessage(tester, failure: true);
      expect(restores, 0);
      expect(events(), contains('backup.fail.other_app'));
    });
  }

  test('the email names the system as support reads it: no build or kernel string', () {
    expect(describeSystem('ios', 'Version 18.1 (Build 22B83)'), 'iOS 18.1');
    expect(describeSystem('android', 'Linux 5.10.43-android12-9 #1 SMP PREEMPT', androidRelease: '14'), 'Android 14');
    expect(describeSystem('android', 'Linux 5.10.43 #1 SMP PREEMPT'), 'Android', reason: 'release unknown: no kernel');
    expect(describeSystem('macos', 'Version 15.1 (Build 24B83)'), 'macos Version 15.1 (Build 24B83)');
  });

  test('a copy is confirmed except on Android 13 and later, which confirms it itself', () {
    expect(confirmsCopy(android: false), isTrue, reason: 'iPhone');
    expect(confirmsCopy(android: true, sdk: 32), isTrue, reason: 'Android 12L');
    expect(confirmsCopy(android: true, sdk: 33), isFalse, reason: 'Android 13');
    expect(confirmsCopy(android: true, sdk: 35), isFalse);
    expect(confirmsCopy(android: true), isTrue, reason: 'level unknown: two confirmations beat none');
  });

  testWidgets('settings’ messages leave with the screen: none follows the user home', (tester) async {
    await launch(tester, const Locale('en'), pushed: true);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    linksOpen = false;
    await tapAndWait(tester, 'Contact support');
    expect(find.text('No email app found. Write to support@example.fr.'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.text('No email app found. Write to support@example.fr.'), findsNothing);
  });

  testWidgets('a message without an action still leaves on its own', (tester) async {
    await launch(tester, const Locale('en'));
    linksOpen = false;
    await tapAndWait(tester, 'Terms of use');
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isFalse);
  });

  testWidgets('the legal links follow the language chosen in settings', (tester) async {
    await launch(tester, const Locale('fr'));
    await tapAndWait(tester, 'English');
    await tapAndWait(tester, 'Legal notice');
    expect(opened, [config.legal['en']!.legalNotice]);
  });

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
