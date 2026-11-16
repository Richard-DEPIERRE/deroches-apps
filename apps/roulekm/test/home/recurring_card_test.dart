import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/data/log_controller.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/home/home_screen.dart';

import 'home_lists_test.dart' show route, tall;
import 'home_screen_test.dart' show change, civic, clio, openHome;

/// Monday to Friday from Monday 9 November: on the home's Wednesday 11, three days wait.
RecurringTrip weekdays(VehicleRecord vehicle, {DateTime? checkedThrough, bool paused = false}) => RecurringTrip(
  id: 'r1',
  route: route('Home', 'Job site', 21, vehicle, back: true),
  weekdays: const [1, 2, 3, 4, 5],
  startDate: DateTime.utc(2026, 11, 9),
  checkedThrough: checkedThrough,
  paused: paused,
);

/// The home over [vehicle] and [pattern], with Pro owned or not; [saved] counts the first-value calls.
Future<LogController> openWithPattern(
  WidgetTester tester,
  String lang,
  VehicleRecord vehicle,
  RecurringTrip pattern, {
  bool pro = true,
  List<int>? saved,
}) async {
  tall(tester);
  final log = await openHome(tester, lang, [vehicle]);
  await change(tester, () => log.saveRecurring(pattern));
  final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
  final home = app.home! as HomeScreen;
  await tester.pumpWidget(
    MaterialApp(
      locale: app.locale,
      localizationsDelegates: app.localizationsDelegates,
      supportedLocales: app.supportedLocales,
      home: HomeScreen(
        log: log,
        settings: home.settings,
        now: home.now,
        pro: ValueNotifier(pro),
        tripSaved: () async => saved?.add(1),
      ),
    ),
  );
  return log;
}

/// Taps [label] and lets the saves it starts finish outside the test's fake time.
Future<void> tapAndSave(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

List<DateTime> tripDays(LogController log) => [for (final t in log.logbook!.trips) t.date]..sort();

void main() {
  for (final (why, pattern) in [
    ('all seen through today', weekdays(clio, checkedThrough: DateTime.utc(2026, 11, 11))),
    ('paused', weekdays(clio, paused: true)),
  ]) {
    testWidgets('no card and nothing counted when no day waits ($why)', (tester) async {
      final log = await openWithPattern(tester, 'fr', clio, pattern);
      expect(find.textContaining('à confirmer'), findsNothing);
      expect(log.logbook!.trips, isEmpty);
    });
  }

  testWidgets('without Pro: no card, nothing counted, and the pattern stays saved', (tester) async {
    final log = await openWithPattern(tester, 'fr', clio, weekdays(clio), pro: false);
    expect(find.textContaining('à confirmer'), findsNothing);
    expect(log.logbook!.trips, isEmpty);
    expect(log.logbook!.recurring.single.checkedThrough, isNull);
  });

  testWidgets('in French: the card names the route and days; "Tout confirmer" counts them all once', (tester) async {
    final saved = <int>[];
    final log = await openWithPattern(tester, 'fr', clio, weekdays(clio), saved: saved);
    expect(find.text('3\u00a0trajets réguliers à confirmer'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'\nHome vers Job site\n')), findsOneWidget, reason: 'read as one card');
    expect(find.textContaining('Du lundi au vendredi'), findsOneWidget);
    expect(find.text('3\u00a0jours\u00a0· Lun.\u00a09\u00a0nov.\u00a0– Mer.\u00a011\u00a0nov.'), findsOneWidget);
    expect(log.logbook!.trips, isEmpty, reason: 'nothing counted until confirmed');
    expect(
      tester.getRect(find.widgetWithText(FilledButton, 'Tout confirmer')).right,
      400 - 16 - 16,
      reason: 'the actions end on the card text edge',
    );

    await tapAndSave(tester, 'Tout confirmer');
    expect(tripDays(log), [DateTime.utc(2026, 11, 9), DateTime.utc(2026, 11, 10), DateTime.utc(2026, 11, 11)]);
    expect(log.logbook!.trips.every((t) => t.route == weekdays(clio).route), isTrue);
    expect(log.logbook!.recurring.single.checkedThrough, DateTime.utc(2026, 11, 11));
    expect(saved, isNotEmpty, reason: 'a confirmed trip is a trip saved');
    expect(find.text('3\u00a0trajets ajoutés'), findsOneWidget);
    expect(find.textContaining('à confirmer'), findsNothing, reason: 'never offered again');

    await tapAndSave(tester, 'Annuler');
    expect(log.logbook!.trips, isEmpty, reason: 'Undo removes the trips just added');
    expect(log.logbook!.recurring.single.checkedThrough, isNull);
    expect(find.text('3\u00a0trajets réguliers à confirmer'), findsOneWidget, reason: 'the card is back as it was');
  });

  testWidgets('a double tap on "Tout confirmer" adds each day once', (tester) async {
    final log = await openWithPattern(tester, 'fr', clio, weekdays(clio));
    await tester.tap(find.text('Tout confirmer'));
    await tapAndSave(tester, 'Tout confirmer');
    expect(tripDays(log), [DateTime.utc(2026, 11, 9), DateTime.utc(2026, 11, 10), DateTime.utc(2026, 11, 11)]);
    expect(find.text('3\u00a0trajets ajoutés'), findsOneWidget);
  });

  testWidgets('in English: "Review" confirms the days left ticked and never offers the others again', (tester) async {
    final log = await openWithPattern(tester, 'en', civic, weekdays(civic));
    expect(find.text('3\u00a0regular trips to confirm'), findsOneWidget);
    expect(find.textContaining('Monday to Friday'), findsOneWidget);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Uncheck the days'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(3));
    expect(find.text('Confirm 3\u00a0trips'), findsOneWidget);
    await tester.tap(find.text('Tue,\u00a0Nov\u00a010'));
    await tester.pump();

    await tapAndSave(tester, 'Confirm 2\u00a0trips');
    expect(tripDays(log), [DateTime.utc(2026, 11, 9), DateTime.utc(2026, 11, 11)]);
    expect(log.logbook!.recurring.single.checkedThrough, DateTime.utc(2026, 11, 11));
    expect(find.text('2\u00a0trips added'), findsOneWidget);
    expect(find.textContaining('to confirm'), findsNothing);

    await tapAndSave(tester, 'Undo');
    expect(log.logbook!.trips, isEmpty);
    expect(log.logbook!.recurring.single.checkedThrough, isNull, reason: 'the skipped day comes back too');
    expect(find.text('3\u00a0regular trips to confirm'), findsOneWidget);
  });

  testWidgets('skip: with every day unchecked, nothing is counted and the days are never offered again', (
    tester,
  ) async {
    final saved = <int>[];
    final log = await openWithPattern(tester, 'en', civic, weekdays(civic), saved: saved);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    for (final day in ['Mon,\u00a0Nov\u00a09', 'Tue,\u00a0Nov\u00a010', 'Wed,\u00a0Nov\u00a011']) {
      await tester.tap(find.text(day));
      await tester.pump();
    }

    await tapAndSave(tester, 'Skip these days');
    expect(log.logbook!.trips, isEmpty);
    expect(log.logbook!.recurring.single.checkedThrough, DateTime.utc(2026, 11, 11));
    expect(saved, isEmpty);
    expect(find.textContaining('to confirm'), findsNothing);
    expect(find.text('3\u00a0days skipped'), findsOneWidget, reason: 'never closed without a word');
    expect(log.logbook!.recurring.single.waitingDays(DateTime(2026, 11, 12)), [DateTime.utc(2026, 11, 12)]);

    await tapAndSave(tester, 'Undo');
    expect(log.logbook!.recurring.single.checkedThrough, isNull);
    expect(find.text('3\u00a0regular trips to confirm'), findsOneWidget);
  });
}
