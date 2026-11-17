import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/l10n/roulekm_localizations.dart';
import 'package:roulekm/src/data/log_controller.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/trips/recurring_screen.dart';

import '../home/home_lists_test.dart' show route, tall;
import '../home/home_screen_test.dart' show civic, clio;
import '../home/recurring_card_test.dart' show tapAndSave, weekdays;

const _nbsp = '\u00a0';

/// Saturdays to Home → Gym, after the weekdays one.
RecurringTrip saturdays(VehicleRecord vehicle) => RecurringTrip(
  id: 'r2',
  route: route('Domicile', 'Salle', 6, vehicle),
  weekdays: const [6],
  startDate: DateTime.utc(2026, 11, 7),
);

/// The recurring trips screen on Wednesday 11 November 2026 over [patterns]; [paywall] records the placements opened.
Future<LogController> openList(
  WidgetTester tester,
  String lang,
  List<VehicleRecord> vehicles,
  List<RecurringTrip> patterns, {
  bool pro = true,
  List<String>? paywall,
  bool pushed = false,
}) async {
  final screen = _screen(pro, paywall);
  tall(tester);
  final dir = Directory.systemTemp.createTempSync('roulekm_recurring_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final data = RoulekmData(dir);
  final log = LogController(data.log);
  final trip = TripRecord(id: 't1', date: DateTime.utc(2026, 11, 2), route: patterns.first.route);
  await tester.runAsync(
    () => data.log.replace(Logbook(vehicles: vehicles, trips: [trip], recurring: patterns).toJson()),
  );
  await tester.runAsync(log.open);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: const [...RoulekmLocalizations.localizationsDelegates, KitLocalizations.delegate],
      supportedLocales: RoulekmLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => pushed
            ? Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen(log))),
                  child: const Text('open'),
                ),
              )
            : screen(log),
      ),
    ),
  );
  if (pushed) {
    await tester.tap(find.text('open'));
  }
  await tester.pumpAndSettle();
  return log;
}

RecurringScreen Function(LogController) _screen(bool pro, List<String>? paywall) =>
    (log) => RecurringScreen(
      log: log,
      pro: ValueNotifier(pro),
      openPaywall: (_, placement) async {
        paywall?.add(placement);
        return false;
      },
      now: () => DateTime(2026, 11, 11, 9),
    );

/// Opens row [index]'s menu.
Future<void> menu(WidgetTester tester, [int index = 0]) async {
  await tester.tap(find.byIcon(Icons.more_vert).at(index));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('one row per pattern: route, days and distance; a paused one says so (fr)', (tester) async {
    await openList(tester, 'fr', [clio], [weekdays(clio), saturdays(clio).copyWith(paused: true)]);
    expect(find.widgetWithText(AppBar, 'Trajets récurrents'), findsOneWidget);
    expect(find.text('Du lundi au vendredi$_nbsp· 21${_nbsp}km$_nbsp· aller-retour'), findsOneWidget);
    expect(find.text('Le samedi$_nbsp· 6${_nbsp}km'), findsOneWidget);
    expect(find.text('En pause$_nbsp: aucun jour proposé pendant la pause'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNWidgets(2));
  });

  testWidgets('the menu in English: pause, change the days, delete', (tester) async {
    await openList(tester, 'en', [civic], [weekdays(civic)]);
    expect(find.widgetWithText(AppBar, 'Recurring trips'), findsOneWidget);
    expect(find.text('Monday to Friday$_nbsp· 21${_nbsp}mi$_nbsp· round trip'), findsOneWidget);
    await menu(tester);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Change the days'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  for (final pro in [true, false]) {
    testWidgets('pause, then resume: the paused days stay skipped (free: ${!pro})', (tester) async {
      final log = await openList(tester, 'fr', [clio], [weekdays(clio)], pro: pro);
      await menu(tester);
      await tapAndSave(tester, 'Mettre en pause');
      expect(log.logbook!.recurring.single.paused, isTrue);
      expect(find.textContaining('En pause'), findsOneWidget);

      await menu(tester);
      await tapAndSave(tester, 'Reprendre');
      final resumed = log.logbook!.recurring.single;
      expect(resumed.paused, isFalse);
      expect(
        resumed.waitingDays(DateTime(2026, 11, 11)),
        [DateTime.utc(2026, 11, 9), DateTime.utc(2026, 11, 10), DateTime.utc(2026, 11, 11)],
        reason: 'paused and resumed the same day: every day waiting before the pause still waits',
      );
      expect(find.textContaining('En pause'), findsNothing);
    });

    testWidgets('delete, then Undo puts it back in its place (free: ${!pro})', (tester) async {
      final log = await openList(tester, 'fr', [clio], [weekdays(clio), saturdays(clio)], pro: pro);
      await menu(tester);
      await tapAndSave(tester, 'Supprimer');
      expect([for (final r in log.logbook!.recurring) r.id], ['r2']);
      expect(log.logbook!.trips, hasLength(1), reason: 'trips already added stay');
      expect(find.text('Trajet récurrent supprimé. Les trajets déjà ajoutés sont conservés.'), findsOneWidget);

      await tapAndSave(tester, 'Annuler');
      expect(log.logbook!.recurring, [weekdays(clio), saturdays(clio)]);
    });
  }

  testWidgets('after Back, the delete snackbar stays with the screen it came from', (tester) async {
    final log = await openList(tester, 'fr', [clio], [weekdays(clio)], pushed: true);
    await menu(tester);
    await tapAndSave(tester, 'Supprimer');
    expect(find.byType(SnackBar), findsOneWidget);
    Navigator.of(tester.element(find.byType(RecurringScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(log.logbook!.recurring, isEmpty);
  });

  testWidgets('the last one deleted: the screen says how to make one', (tester) async {
    final log = await openList(tester, 'fr', [clio], [weekdays(clio)]);
    await menu(tester);
    await tapAndSave(tester, 'Supprimer');
    expect(log.logbook!.recurring, isEmpty);
    expect(find.textContaining('touchez «${_nbsp}Répéter ce trajet$_nbsp»'), findsOneWidget);
  });

  testWidgets('with Pro, "Modifier les jours" opens the repeat sheet and saves the new days', (tester) async {
    final log = await openList(tester, 'fr', [clio], [weekdays(clio)]);
    await menu(tester);
    expect(find.text('Pro'), findsNothing);
    await tester.tap(find.text('Modifier les jours'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier les jours'), findsOneWidget, reason: "the sheet's title");
    expect(find.text('Répéter ce trajet'), findsNothing);
    expect(find.textContaining('partir'), findsNothing, reason: "the first day can't change");
    await tester.tap(find.bySemanticsLabel('mercredi'));
    await tester.pump();
    await tapAndSave(tester, 'Répéter lundi, mardi, jeudi et vendredi');
    expect(log.logbook!.recurring.single.weekdays, [1, 2, 4, 5]);
    expect(log.logbook!.recurring.single.startDate, DateTime.utc(2026, 11, 9));
  });

  testWidgets('without Pro, "Modifier les jours" is tagged Pro and opens the paywall, not the sheet', (tester) async {
    final paywall = <String>[];
    final log = await openList(tester, 'fr', [clio], [weekdays(clio)], pro: false, paywall: paywall);
    await menu(tester);
    expect(find.text('Pro'), findsOneWidget);
    await tester.tap(find.text('Modifier les jours'));
    await tester.pumpAndSettle();
    expect(paywall, ['recurring_trip']);
    expect(find.text('Répéter ce trajet'), findsNothing);
    expect(log.logbook!.recurring.single, weekdays(clio));
  });
}
