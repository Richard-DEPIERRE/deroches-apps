import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_example/main.dart';
import 'package:kit_example/notes.dart';

/// A first launch, on a device in [deviceLocale].
Future<void> pumpApp(WidgetTester tester, Locale deviceLocale, {StoreReview? review}) async {
  final dir = Directory.systemTemp.createTempSync('example_app_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final kitState = KitStateController(directory: dir, appId: exampleConfig.slug);
  await tester.runAsync(kitState.load);
  tester.platformDispatcher.localesTestValue = [deviceLocale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final analytics = Analytics(kitState: kitState, appId: exampleConfig.slug, appVersion: '0.1.0', locale: () => 'en');
  final purchases = Purchases(backend: FakePurchasesBackend(), analytics: analytics, plans: exampleConfig.plans);
  await tester.pumpWidget(
    buildApp(
      kitState: kitState,
      analytics: analytics,
      data: ExampleData(dir, files: FakeBackupFiles()),
      purchases: purchases,
      review: review ?? FakeStoreReview(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the sample app loads in French, onboarding first', (tester) async {
    await pumpApp(tester, const Locale('fr', 'FR'));
    expect(find.text('Bienvenue'), findsOneWidget);
    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();
    expect(find.text('Exemple du kit'), findsOneWidget);
    expect(find.textContaining('ne sont jamais publiés'), findsOneWidget);

    await tester.tap(find.byTooltip('Réglages'));
    await tester.pumpAndSettle();
    expect(find.text('Langue du téléphone'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Exporter une sauvegarde'), 100, scrollable: find.byType(Scrollable).first);
    expect(find.text('Exporter une sauvegarde'), findsOneWidget);
  });

  testWidgets('the sample app loads in English, onboarding first', (tester) async {
    await pumpApp(tester, const Locale('en', 'US'));
    expect(find.text('Welcome'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Kit example'), findsOneWidget);
    expect(find.textContaining('never ship'), findsOneWidget);
    expect(find.text('Something went well'), findsOneWidget, reason: 'reports a good moment to the rating prompt');

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Phone’s language'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Export a backup'), 100, scrollable: find.byType(Scrollable).first);
    expect(find.text('Export a backup'), findsOneWidget);
  });

  testWidgets('the plans show only after the first useful moment, then open and close', (tester) async {
    await pumpApp(tester, const Locale('en', 'US'));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('See the plans'), findsNothing, reason: 'no paywall before the first useful moment');

    await tester.tap(find.text('Something went well'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('See the plans')).dx,
      tester.getTopLeft(find.textContaining('never ship')).dx,
      reason: 'the label lines up with the body text (DAPP-105)',
    );
    await tester.tap(find.text('See the plans'));
    await tester.pumpAndSettle();
    expect(find.text('Unlimited notes and exports'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Unlimited notes and exports'), findsNothing);
    expect(find.text('See the plans'), findsOneWidget);
  });

  test('every sample app message is in English and in French', () {
    expect(arbProblems('lib/l10n/app_en.arb', 'lib/l10n/app_fr.arb'), isEmpty);
  });
}
