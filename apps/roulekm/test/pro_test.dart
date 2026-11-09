import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/l10n/roulekm_localizations.dart';
import 'package:roulekm/src/pro.dart';

void main() {
  /// A button that asks for the Pro action at `second_vehicle`; returns the answers and the placements asked for.
  Future<(List<bool>, List<String>)> pump(
    WidgetTester tester,
    String lang, {
    bool pro = false,
    bool trip = true,
  }) async {
    final answers = <bool>[];
    final paywalls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(lang),
        localizationsDelegates: RoulekmLocalizations.localizationsDelegates,
        supportedLocales: RoulekmLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => answers.add(
                await proAction(
                  context,
                  placement: 'second_vehicle',
                  pro: pro,
                  tripSaved: trip,
                  openPaywall: (_, placement) async {
                    paywalls.add(placement);
                    return true;
                  },
                ),
              ),
              child: const ProTag(),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pro'));
    await tester.pump();
    return (answers, paywalls);
  }

  for (final (lang, snackbar) in [
    ('fr', 'Disponible avec Roulekm Pro, après votre premier trajet.'),
    ('en', 'Part of Roulekm Pro, once you’ve saved your first trip.'),
  ]) {
    testWidgets('before the first trip ($lang): the snackbar, no paywall, no price', (tester) async {
      final (answers, paywalls) = await pump(tester, lang, trip: false);
      expect(find.text(snackbar), findsOneWidget);
      expect(answers, [false]);
      expect(paywalls, isEmpty);
    });
  }

  testWidgets("after it: the paywall at the action's placement decides", (tester) async {
    final (answers, paywalls) = await pump(tester, 'en');
    expect(paywalls, ['second_vehicle']);
    expect(answers, [true]);
  });

  testWidgets('with Pro: at once, nothing shown', (tester) async {
    final (answers, paywalls) = await pump(tester, 'en', pro: true, trip: false);
    expect(answers, [true]);
    expect(paywalls, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });
}
