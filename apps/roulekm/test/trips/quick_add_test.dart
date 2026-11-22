import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:roulekm/l10n/roulekm_localizations.dart';
import 'package:roulekm/src/data/log_controller.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/home/home_screen.dart';
import 'package:roulekm/src/rates/rates.dart';

import '../home/home_lists_test.dart' show route;
import '../home/home_screen_test.dart' show civic, clio;
import 'trip_screen_test.dart' show settle;

const _nbsp = '\u00a0';

/// The home in [lang] on Wednesday 11 November 2026 with one favourite; [saved] counts the first-value calls.
Future<LogController> openWithFavourite(
  WidgetTester tester,
  String lang,
  VehicleRecord vehicle,
  TripRoute favourite, {
  List<int>? saved,
  Size size = const Size(390, 844),
}) async {
  final dir = Directory.systemTemp.createTempSync('roulekm_quick_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final data = RoulekmData(dir);
  final log = LogController(data.log);
  final logbook = Logbook(
    vehicles: [vehicle],
    favourites: [FavouriteTrip(id: 'f1', route: favourite)],
  );
  await tester.runAsync(() => data.log.replace(logbook.toJson()));
  await tester.runAsync(log.open);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: const [...RoulekmLocalizations.localizationsDelegates, KitLocalizations.delegate],
      supportedLocales: RoulekmLocalizations.supportedLocales,
      home: HomeScreen(
        log: log,
        settings: (_) => const Text('settings'),
        tripSaved: () async => saved?.add(1),
        now: () => DateTime(2026, 11, 11, 9),
      ),
    ),
  );
  return log;
}

final _bron = route('Domicile', 'Chantier Bron', 34, clio, purpose: 'Suivi de chantier', back: true);
final _site = route('Home', 'Job site', 21, civic, purpose: 'Site visit', back: true);

Future<void> tapFavourite(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add_circle_outline));
  await tester.pumpAndSettle();
}

void main() {
  test('the picked day reads as on the home screen, with its year when it is not this year', () async {
    await initializeDateFormatting();
    final nov3 = DateTime.utc(2026, 11, 3);
    final dec31 = DateTime.utc(2025, 12, 31);
    // dart format off
    for (final (lang, system, day, text) in [
      ('fr', RateSystem.france, nov3, 'Mar. 3 nov.'),
      ('fr', RateSystem.france, dec31, 'Mer. 31 déc. 2025'),
      ('en', RateSystem.uk, nov3, 'Tue 3 Nov'),
      ('en', RateSystem.uk, dec31, 'Wed 31 Dec 2025'),
      ('en', RateSystem.us, nov3, 'Tue, Nov 3'),
      ('en', RateSystem.us, dec31, 'Wed, Dec 31, 2025'),
    ]) {
      expect(shortDay(lang, system, day, thisYear: 2026), text.replaceAll(' ', _nbsp), reason: '$lang $system $day');
    }
    // dart format on
  });

  testWidgets('in French: two taps add the favourite today, and Annuler deletes that trip', (tester) async {
    final saved = <int>[];
    final log = await openWithFavourite(tester, 'fr', clio, _bron, saved: saved);
    expect(find.text('0${_nbsp}km cette année'), findsOneWidget);

    await tapFavourite(tester);
    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.bySemanticsLabel('Domicile vers Chantier Bron')), findsOneWidget);
    expect(
      find.text('Suivi de chantier$_nbsp· Clio$_nbsp· 34${_nbsp}km aller-retour$_nbsp= 68${_nbsp}km'),
      findsOneWidget,
    );
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Aujourd’hui')).selected, isTrue);
    expect(find.widgetWithText(ChoiceChip, 'Hier'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Autre date'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Modifier avant d’ajouter'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter le trajet'));
    await settle(tester, until: () => saved.length == 1);
    expect(find.byType(BottomSheet), findsNothing, reason: 'the sheet closes');
    final trip = log.logbook!.trips.single;
    expect(trip.date, DateTime.utc(2026, 11, 11));
    expect(trip.route, _bron);
    expect(saved, [1], reason: 'the first trip saved is the first useful moment');
    expect(find.text('68${_nbsp}km cette année'), findsOneWidget, reason: 'the total updates');
    expect(find.text('Trajet ajouté$_nbsp· 68${_nbsp}km'), findsOneWidget);

    await tester.tap(find.widgetWithText(SnackBarAction, 'Annuler'));
    await settle(tester);
    expect(log.logbook!.trips, isEmpty, reason: 'Undo deletes that trip');
    expect(log.logbook!.favourites, hasLength(1), reason: 'and keeps the favourite');
    expect(find.text('0${_nbsp}km cette année'), findsOneWidget);
  });

  testWidgets('in English: yesterday, then another date from the picker', (tester) async {
    final saved = <int>[];
    final log = await openWithFavourite(tester, 'en', civic, _site, saved: saved);
    await tapFavourite(tester);
    expect(
      find.text('Site visit$_nbsp· Civic$_nbsp· 21${_nbsp}mi round${_nbsp}trip$_nbsp= 42${_nbsp}mi'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ChoiceChip, 'Today'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Edit before adding'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Yesterday'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add trip'));
    await settle(tester, until: () => saved.length == 1);
    expect(log.logbook!.trips.single.date, DateTime.utc(2026, 11, 10));
    expect(find.text('Trip added$_nbsp· 42${_nbsp}mi'), findsOneWidget);

    await tapFavourite(tester);
    final calendar = find.byIcon(Icons.calendar_today_outlined);
    expect(find.descendant(of: find.widgetWithText(ChoiceChip, 'Other date'), matching: calendar), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Other date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Tue,${_nbsp}Nov${_nbsp}3')).selected, isTrue);
    await tester.tap(find.widgetWithText(FilledButton, 'Add trip'));
    await settle(tester, until: () => saved.length == 2);
    expect([for (final t in log.logbook!.latestFirst) t.date], [DateTime.utc(2026, 11, 10), DateTime.utc(2026, 11, 3)]);
    expect(saved, [1, 1]);
  });

  testWidgets('a one-way favourite shows its distance only', (tester) async {
    await openWithFavourite(tester, 'fr', clio, route('Agence', 'Vénissieux', 18, clio, purpose: ''));
    await tapFavourite(tester);
    expect(find.text('Clio$_nbsp· 18${_nbsp}km'), findsOneWidget);
  });

  testWidgets('"Modifier avant d’ajouter" opens the new-trip form filled in, on the day picked', (tester) async {
    final saved = <int>[];
    final log = await openWithFavourite(tester, 'fr', clio, _bron, saved: saved, size: const Size(390, 1600));
    await tapFavourite(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Hier'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Modifier avant d’ajouter'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Nouveau trajet'), findsOneWidget);
    expect(find.text('Supprimer le trajet'), findsNothing);
    expect(find.text('Mardi 10 novembre 2026'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Domicile'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Chantier Bron'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '34'), '36');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer$_nbsp· 72${_nbsp}km'));
    await settle(tester, until: () => saved.length == 1);

    final trip = log.logbook!.trips.single;
    expect(trip.date, DateTime.utc(2026, 11, 10));
    expect(trip.route.distance.value, 36);
    expect(trip.route.purpose, 'Suivi de chantier');
    expect(log.logbook!.favourites.single.route, _bron, reason: 'the favourite itself is unchanged');
    expect(saved, [1]);
  });

  testWidgets('at 2× text on a 360 × 640 phone the main action is on screen', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openWithFavourite(tester, 'fr', clio, _bron, size: const Size(360, 640));
    await tester.scrollUntilVisible(
      find.byIcon(Icons.add_circle_outline),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    await tapFavourite(tester);
    expect(find.widgetWithText(FilledButton, 'Ajouter le trajet').hitTestable(), findsOneWidget);
    final button = tester.getRect(find.widgetWithText(FilledButton, 'Ajouter le trajet'));
    expect(button.bottom, lessThanOrEqualTo(640));
  });
}
