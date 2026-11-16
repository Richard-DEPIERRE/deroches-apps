import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_screen_test.dart';

/// "Répéter ce trajet" on the trip form (DAPP-141 §3–4): the trip is saved first, the pattern only with Pro.
void main() {
  Future<void> fill(WidgetTester tester) async {
    await type(tester, 'From', 'Home');
    await type(tester, 'To', 'Job site');
    await type(tester, 'One-way distance', '21');
  }

  Future<void> openSheet(WidgetTester tester, String row) async {
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
  }

  Future<void> tapDay(WidgetTester tester, String day) async {
    await tester.tap(find.bySemanticsLabel(day));
    await tester.pump();
  }

  testWidgets('free, before the first trip: a Pro tag, and a tap shows the snackbar, not the sheet', (tester) async {
    await openTrip(tester, const Locale('fr', 'FR'));
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Jamais'), findsOneWidget);
    await openSheet(tester, 'Répéter ce trajet');
    expect(find.text('Disponible avec Roulekm Pro, après votre premier trajet.'), findsOneWidget);
    expect(find.text('Répéter du lundi au vendredi'), findsNothing);
  });

  testWidgets('the sheet in French: seven days read in full, Monday to Friday on, from the trip day', (tester) async {
    await openTrip(tester, const Locale('fr', 'FR'), pro: true);
    expect(find.text('Pro'), findsNothing, reason: 'no tag with Pro');
    await openSheet(tester, 'Répéter ce trajet');
    for (final (day, on) in [('lundi', true), ('vendredi', true), ('samedi', false), ('dimanche', false)]) {
      expect(tester.getSemantics(find.bySemanticsLabel(day)), isSemantics(isButton: true, isSelected: on), reason: day);
    }
    expect(find.text('À\u00a0partir\u00a0du'), findsOneWidget, reason: 'never broken across lines');
    expect(find.text('Jeu. 5 nov.'), findsOneWidget);
    expect(find.textContaining('Rien n’est compté sans votre confirmation'), findsOneWidget);
    expect(find.text('Répéter du lundi au vendredi'), findsOneWidget);
    await tapDay(tester, 'mercredi');
    expect(find.text('Répéter lundi, mardi, jeudi et vendredi'), findsOneWidget);
    for (final day in ['mardi', 'jeudi', 'vendredi']) {
      await tapDay(tester, day);
    }
    expect(find.text('Répéter le lundi'), findsOneWidget);
    await tapDay(tester, 'lundi');
    final none = find.widgetWithText(FilledButton, 'Choisissez au moins un jour');
    expect(tester.widget<FilledButton>(none).onPressed, isNull);
  });

  testWidgets('with Pro: the trip, then its pattern from the trip day, which waits only after it', (tester) async {
    final log = await openTrip(tester, const Locale('en', 'US'), vehicles: [pickup], pro: true);
    await fill(tester);
    await openSheet(tester, 'Repeat this trip');
    await tapDay(tester, 'Saturday');
    await tapDay(tester, 'Sunday');
    expect(find.text('Repeat every day'), findsOneWidget);
    for (final day in ['Saturday', 'Sunday', 'Friday']) {
      await tapDay(tester, day);
    }
    await tester.tap(find.text('Repeat Monday to Thursday'));
    await tester.pumpAndSettle();
    expect(find.text('Monday to Thursday'), findsOneWidget, reason: 'the row says what was picked');
    await tapSave(tester, 'Save\u00a0· 21\u00a0mi');

    final trip = log.logbook!.trips.single;
    final pattern = log.logbook!.recurring.single;
    expect(pattern.route, trip.route);
    expect(pattern.weekdays, [1, 2, 3, 4]);
    expect(pattern.startDate, DateTime.utc(2026, 11, 5));
    expect(pattern.waitingDays(today), isEmpty, reason: 'the trip just saved is that day');
    expect(pattern.waitingDays(DateTime(2026, 11, 9)), [DateTime.utc(2026, 11, 9)]);
  });

  for (final bought in [false, true]) {
    testWidgets('free after the first trip: the trip is saved, then the paywall; pattern only if bought ($bought)', (
      tester,
    ) async {
      final paywalls = <String>[];
      final log = await openTrip(
        tester,
        const Locale('en', 'US'),
        vehicles: [pickup],
        trips: [later],
        openPaywall: (_, placement) async {
          paywalls.add(placement);
          return bought;
        },
      );
      expect(find.text('Pro'), findsOneWidget);
      await fill(tester);
      await openSheet(tester, 'Repeat this trip');
      await tester.tap(find.text('Repeat Monday to Friday'));
      await tester.pumpAndSettle();
      await tapSave(tester, 'Save\u00a0· 21\u00a0mi');

      expect(paywalls, ['recurring_trip']);
      expect(log.logbook!.trips, hasLength(2), reason: 'saved whatever happens');
      expect(log.logbook!.recurring, hasLength(bought ? 1 : 0));
      expect(find.text('New trip'), findsNothing, reason: 'the form closes either way');
    });
  }

  testWidgets('no repeat: no paywall; editing a trip has no repeat row', (tester) async {
    final paywalls = <String>[];
    final log = await openTrip(
      tester,
      const Locale('en', 'US'),
      vehicles: [pickup],
      trips: [later],
      openPaywall: (_, placement) async {
        paywalls.add(placement);
        return false;
      },
    );
    await fill(tester);
    await tapSave(tester, 'Save\u00a0· 21\u00a0mi');
    expect(paywalls, isEmpty);
    expect(log.logbook!.recurring, isEmpty);

    await openTrip(tester, const Locale('en', 'US'), trip: later);
    expect(find.text('Repeat this trip'), findsNothing);
  });

  testWidgets('a trip day in another year shows its year', (tester) async {
    await openTrip(tester, const Locale('fr', 'FR'), pro: true, date: DateTime.utc(2025, 12, 30));
    await openSheet(tester, 'Répéter ce trajet');
    expect(find.text('Mar.\u00a030\u00a0déc.\u00a02025'), findsOneWidget);
  });
}
