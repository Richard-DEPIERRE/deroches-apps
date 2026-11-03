import 'dart:io';

import 'package:app_kit/app_kit.dart';
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
    switchLabel: 'Partager des statistiques d’utilisation et des rapports de plantage anonymes',
    version: 'Version 1.2.0 (34)',
  ),
  'en': (
    title: 'Settings',
    device: 'Phone’s language',
    switchLabel: 'Share anonymous usage statistics and crash reports',
    version: 'Version 1.2.0 (34)',
  ),
};

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('settings_');
    addTearDown(() => dir.deleteSync(recursive: true));
    PackageInfo.setMockInitialValues(
      appName: 'Logbook',
      packageName: 'fr.example.carnet',
      version: '1.2.0',
      buildNumber: '34',
      buildSignature: '',
    );
  });

  /// The app as a launch opens it, kit state read from disk, on its settings
  /// screen: a small phone at twice the text size.
  Future<KitStateController> launch(WidgetTester tester, Locale device) async {
    final kit = KitStateController(directory: dir, appId: 'carnet-km');
    await tester.runAsync(kit.load);
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
          appSections: const [ListTile(title: Text('App section'))],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return kit;
  }

  /// Taps [label], scrolled into view, and lets the real file work run.
  Future<void> tapAndWait(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(find.text(label), 100, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pumpAndSettle();
    }
  }

  Future<void> expectVisible(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 100, scrollable: find.byType(Scrollable).first);
    expect(find.text(text), findsOneWidget);
  }

  for (final MapEntry(key: lang, value: t) in texts.entries) {
    final device = Locale(lang);

    testWidgets('$lang: every item is there, on a small phone at large text', (tester) async {
      await launch(tester, device);
      expect(find.text(t.title), findsOneWidget);
      for (final text in ['App section', t.device, 'Français', 'English', t.switchLabel, t.version]) {
        await expectVisible(tester, text);
      }
      expect(tester.takeException(), isNull, reason: 'no overflow at twice the text size');
    });

    testWidgets('$lang: the statistics switch is saved', (tester) async {
      final kit = await launch(tester, device);
      await tapAndWait(tester, t.switchLabel);
      expect(kit.state!.analyticsEnabled, isFalse);
      expect((await launch(tester, device)).state!.analyticsEnabled, isFalse);
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
