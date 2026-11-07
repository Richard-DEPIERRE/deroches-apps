import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/main.dart';
import 'package:roulekm/src/data/logbook.dart';

/// A first launch, on a device in [deviceLocale].
Future<void> pumpApp(WidgetTester tester, Locale deviceLocale) async {
  final dir = Directory.systemTemp.createTempSync('roulekm_app_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final kitState = KitStateController(directory: dir, appId: roulekmConfig.slug);
  await tester.runAsync(kitState.load);
  tester.platformDispatcher.localesTestValue = [deviceLocale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final analytics = Analytics(kitState: kitState, appId: roulekmConfig.slug, appVersion: '0.1.0', locale: () => 'en');
  await tester.pumpWidget(
    buildApp(
      kitState: kitState,
      analytics: analytics,
      data: RoulekmData(dir, files: FakeBackupFiles()),
    ),
  );
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
    await pumpApp(tester, const Locale('fr', 'FR'));
    expect(find.text('Roulekm – frais kilométriques'), findsOneWidget);
    expect(find.textContaining('arrivent bientôt'), findsOneWidget);

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
    await pumpApp(tester, const Locale('en', 'GB'));
    expect(find.text('Roulekm – Mileage Log'), findsOneWidget);
    expect(find.textContaining('coming soon'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Phone’s language'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Export a backup'), 100, scrollable: find.byType(Scrollable).first);
    expect(find.text('Export a backup'), findsOneWidget);
  });
}
