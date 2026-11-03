import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_example/main.dart';

/// A first launch, on a device in [deviceLocale].
Future<void> pumpApp(WidgetTester tester, Locale deviceLocale, {StoreReview? review}) async {
  final dir = Directory.systemTemp.createTempSync('example_app_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final kitState = KitStateController(directory: dir, appId: exampleConfig.slug);
  await tester.runAsync(kitState.load);
  tester.platformDispatcher.localesTestValue = [deviceLocale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  await tester.pumpWidget(buildApp(kitState: kitState, review: review ?? FakeStoreReview()));
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
  });

  testWidgets('the sample app loads in English, onboarding first', (tester) async {
    await pumpApp(tester, const Locale('en', 'US'));
    expect(find.text('Welcome'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Kit example'), findsOneWidget);
    expect(find.textContaining('never ship'), findsOneWidget);
    expect(find.text('Something went well'), findsOneWidget, reason: 'reports a good moment to the rating prompt');
  });

  test('every sample app message is in English and in French', () {
    expect(arbProblems('lib/l10n/app_en.arb', 'lib/l10n/app_fr.arb'), isEmpty);
  });
}
