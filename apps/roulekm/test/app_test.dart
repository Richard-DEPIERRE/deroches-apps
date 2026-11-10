import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/main.dart';
import 'package:roulekm/src/data/logbook.dart';

/// Launches the app on a device in [deviceLocale]: its first launch, or a later one once [onboarded].
Future<RoulekmData> pumpApp(WidgetTester tester, Locale deviceLocale, {bool onboarded = false}) async {
  final dir = Directory.systemTemp.createTempSync('roulekm_app_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final kitState = KitStateController(directory: dir, appId: roulekmConfig.slug);
  await tester.runAsync(kitState.load);
  if (onboarded) await tester.runAsync(() => kitState.update((s) => s.copyWith(onboardingCompleted: true)));
  tester.platformDispatcher.localesTestValue = [deviceLocale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final analytics = Analytics(kitState: kitState, appId: roulekmConfig.slug, appVersion: '0.1.0', locale: () => 'en');
  final data = RoulekmData(dir, files: FakeBackupFiles());
  await tester.pumpWidget(buildApp(kitState: kitState, analytics: analytics, data: data));
  await tester.pumpAndSettle();
  return data;
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// Taps [label] and waits until the log is on disk (the save runs in the test's fake time).
Future<void> save(WidgetTester tester, RoulekmData data, String label) async {
  await tester.tap(find.text(label));
  var saved = false;
  unawaited(data.log.flush().then((_) => saved = true));
  for (var i = 0; !saved; i++) {
    if (i == 1000) fail('the log was still saving after 10 seconds');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  test('the config is app-setup A1, with no key until the services exist', () {
    expect(roulekmConfig.problems, isEmpty);
    expect(roulekmConfig.slug, 'roulekm');
    expect(roulekmConfig.slug, roulekmAppId, reason: 'the data documents carry the same app id');
    expect(roulekmConfig.names, {'fr': 'Roulekm – frais kilométriques', 'en': 'Roulekm – Mileage Log'});
    expect(roulekmConfig.supportEmail, 'support@roulekm.fr');
    expect(roulekmConfig.plans, {Plan.weekly, Plan.yearly, Plan.lifetime});
    expect(roulekmConfig.legal['fr']!.all.map((u) => '$u'), [
      'https://roulekm.fr/mentions-legales/',
      'https://roulekm.fr/confidentialite/',
      'https://roulekm.fr/conditions/',
    ]);
    expect(roulekmConfig.legal['en']!.all.map((u) => '$u'), [
      'https://roulekm.fr/en/legal-notice/',
      'https://roulekm.fr/en/privacy/',
      'https://roulekm.fr/en/terms/',
    ]);
    for (final key in [
      roulekmConfig.sentryDsn,
      roulekmConfig.postHogKey,
      roulekmConfig.revenueCatAppleKey,
      roulekmConfig.revenueCatGoogleKey,
      roulekmConfig.appStoreId,
    ]) {
      expect(key, isNull);
    }
  });

  testWidgets('Roulekm loads in French, settings with backup included', (tester) async {
    await pumpApp(tester, const Locale('fr', 'FR'), onboarded: true);
    expect(find.text('Roulekm – frais kilométriques'), findsOneWidget);
    expect(find.textContaining('arrivent bientôt'), findsOneWidget);
    expect(find.text('Vos kilomètres, en euros'), findsNothing, reason: 'onboarding shows once');
    expect(find.text('Votre véhicule'), findsNothing, reason: 'so does the first-vehicle step');

    await tester.tap(find.byTooltip('Réglages'));
    await tester.pumpAndSettle();
    expect(find.text('Langue du téléphone'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Exporter une sauvegarde'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Exporter une sauvegarde'), findsOneWidget);
  });

  testWidgets('Roulekm loads in English, settings with backup included', (tester) async {
    await pumpApp(tester, const Locale('en', 'GB'), onboarded: true);
    expect(find.text('Roulekm – Mileage Log'), findsOneWidget);
    expect(find.textContaining('coming soon'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Phone’s language'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Export a backup'), 100, scrollable: find.byType(Scrollable).first);
    expect(find.text('Export a backup'), findsOneWidget);
  });

  for (final (device, section, title) in [
    (const Locale('fr', 'FR'), 'Véhicules', 'Véhicules'),
    (const Locale('en', 'GB'), 'Vehicles', 'Vehicles'),
  ]) {
    testWidgets('Settings → Roulekm → $section opens the vehicles list (${device.languageCode})', (tester) async {
      await pumpApp(tester, device, onboarded: true);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Roulekm'), findsOneWidget, reason: "the app's own section comes first");
      await tester.tap(find.text(section));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, title), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget, reason: 'the add button, free with no vehicle in use');
    });
  }

  // DAPP-141 §0: the seed and Barlow's four weights, bundled with their licence.
  testWidgets("Roulekm's brand: seed #C4511A and Barlow", (tester) async {
    await pumpApp(tester, const Locale('fr', 'FR'), onboarded: true);
    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(theme.colorScheme.primary, ColorScheme.fromSeed(seedColor: const Color(0xFFC4511A)).primary);
    expect(theme.textTheme.bodyLarge!.fontFamily, 'Barlow');
    final manifest = await tester.runAsync(() => rootBundle.loadString('FontManifest.json'));
    final barlow = (jsonDecode(manifest!) as List).cast<Map<String, Object?>>().singleWhere(
      (f) => f['family'] == 'Barlow',
    );
    expect([for (final f in barlow['fonts']! as List) (f as Map)['weight']], [400, 500, 600, 700]);
    expect(File('assets/fonts/OFL.txt').readAsStringSync(), startsWith('Copyright 2017 The Barlow Project Authors'));
  });

  // DAPP-140 §3, word for word; DAPP-141 §6.
  for (final (device, t) in [
    (
      const Locale('fr', 'FR'),
      (
        page1: 'Vos kilomètres, en euros',
        page2: 'Pas de compte, pas de GPS',
        page3: 'Trajets illimités, Pro sans abonnement obligatoire',
        money: Icons.euro,
        skip: 'Passer',
        next: 'Suivant',
        add: 'Ajouter mon véhicule',
        title: 'Votre véhicule',
        line: 'Pour appliquer le bon barème. Vous pourrez en ajouter d’autres ensuite.',
        later: 'Plus tard',
        done: 'C’est parti',
        name: 'Nom',
        pick: '5\u00A0CV',
        settings: 'Réglages',
        vehicles: 'Véhicules',
      ),
    ),
    (
      const Locale('en', 'GB'),
      (
        page1: 'Your miles, in money',
        page2: 'No account, no GPS',
        page3: 'Unlimited trips. Pro, no subscription required',
        money: Icons.currency_pound,
        skip: 'Skip',
        next: 'Next',
        add: 'Add my vehicle',
        title: 'Your vehicle',
        line: 'So the right rate applies. You can add more later.',
        later: 'Later',
        done: 'Done',
        name: 'Name',
        pick: 'Car or van',
        settings: 'Settings',
        vehicles: 'Vehicles',
      ),
    ),
  ]) {
    final lang = device.languageCode;

    testWidgets('first launch: three pages, then "${t.title}"; the first vehicle is saved ($lang)', (tester) async {
      final data = await pumpApp(tester, device);
      expect(find.text(t.page1), findsOneWidget);
      expect(find.byIcon(t.money), findsOneWidget, reason: "page 1's badge is the region's money");
      expect(find.text(t.skip), findsOneWidget, reason: 'skippable from page 1');
      await tapText(tester, t.next);
      expect(find.text(t.page2), findsOneWidget);
      await tapText(tester, t.next);
      expect(find.text(t.page3), findsOneWidget);
      await tapText(tester, t.add);

      expect(find.text(t.title), findsOneWidget);
      expect(find.text(t.line), findsOneWidget);
      expect(find.widgetWithText(AppBar, t.later), findsOneWidget);
      expect(find.widgetWithText(FilledButton, t.done), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, t.name), 'Clio');
      await tapText(tester, t.pick);
      await save(tester, data, t.done);

      expect(find.text(t.title), findsNothing);
      await tester.tap(find.byTooltip(t.settings));
      await tester.pumpAndSettle();
      await tapText(tester, t.vehicles);
      expect(find.text('Clio'), findsOneWidget);
    });

    testWidgets('first launch: skip, then "${t.later}" leads home with nothing saved ($lang)', (tester) async {
      final data = await pumpApp(tester, device);
      await tapText(tester, t.skip);
      expect(find.text(t.title), findsOneWidget, reason: 'skipping the pages still asks for the vehicle');
      await tapText(tester, t.later);
      expect(find.text(t.title), findsNothing);
      expect(find.byTooltip(t.settings), findsOneWidget);
      final log = await tester.runAsync(data.log.read);
      expect(log?['vehicles'] ?? [], isEmpty);
    });
  }
}
