import 'package:app_kit/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_example/main.dart';

Future<void> pumpApp(WidgetTester tester, Locale deviceLocale) async {
  tester.platformDispatcher.localesTestValue = [deviceLocale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  await tester.pumpWidget(buildApp());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the sample app loads in French', (tester) async {
    await pumpApp(tester, const Locale('fr', 'FR'));
    expect(find.text('Exemple du kit'), findsOneWidget);
    expect(find.textContaining('ne sont jamais publiés'), findsOneWidget);
  });

  testWidgets('the sample app loads in English', (tester) async {
    await pumpApp(tester, const Locale('en', 'US'));
    expect(find.text('Kit example'), findsOneWidget);
    expect(find.textContaining('never ship'), findsOneWidget);
  });

  test('every sample app message is in English and in French', () {
    expect(arbProblems('lib/l10n/app_en.arb', 'lib/l10n/app_fr.arb'), isEmpty);
  });
}
