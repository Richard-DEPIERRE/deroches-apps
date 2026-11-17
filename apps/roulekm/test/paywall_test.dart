import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/rates/distance.dart';
import 'package:roulekm/src/rates/french_bareme.dart';
import 'package:roulekm/src/rates/rates.dart';
import 'package:roulekm/src/vehicles/vehicle_screen.dart';

import 'app_test.dart' show pumpApp, save, tapText;

// DAPP-148: the gate's hook opens the kit's paywall with Roulekm's header (DAPP-140 §1 and §2), with the kit's fake
// store. Each screen's own tests cover its Pro action with and without Pro, before and after the first trip.

const clio = VehicleRecord(id: 'v1', name: 'Clio', rates: RateSystem.france, type: VehicleType.car, horsepower: 5);
const pickup = VehicleRecord(id: 'v3', name: 'Pickup', rates: RateSystem.us, type: VehicleType.car);
const route = TripRoute(from: 'A', to: 'B', purpose: '', distance: Distance(3, DistanceUnit.km), vehicleId: 'v1');

TripRecord trip(int i, DateTime day) =>
    TripRecord(id: 't$i', date: DateTime.utc(day.year, day.month, day.day), route: route);

/// One vehicle in use, and a trip saved: the first useful moment is behind.
final withTrip = Logbook(vehicles: const [clio], trips: [trip(0, DateTime.now())]);

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

String? placement(WidgetTester tester) => find.byType(PaywallScreen).evaluate().isEmpty
    ? null
    : tester.widget<PaywallScreen>(find.byType(PaywallScreen)).placement;

void main() {
  for (final (device, t) in [
    (
      const Locale('fr', 'FR'),
      (
        line: 'Le même Pro dans chaque formule. Payez une fois et il est à vous, ou à l’année, ou à la semaine.',
        bullets: [
          'Le relevé PDF de l’année, trajet par trajet',
          'L’export CSV',
          'Les trajets récurrents',
          'Plusieurs véhicules à la fois',
        ],
        foot: 'Vos trajets restent gratuits et illimités, avec ou sans Pro.',
        snackbar: 'Disponible avec Roulekm Pro, après votre premier trajet.',
      ),
    ),
    (
      const Locale('en', 'GB'),
      (
        line: 'The same Pro in every plan. Pay once and keep it, or pay by the year or by the week.',
        bullets: [
          'Your year’s mileage log as a PDF, trip by trip',
          'CSV export',
          'Recurring trips',
          'Several vehicles at once',
        ],
        foot: 'Your trips stay free and unlimited, with or without Pro.',
        snackbar: 'Part of Roulekm Pro, once you’ve saved your first trip.',
      ),
    ),
  ]) {
    final lang = device.languageCode;

    testWidgets('Settings → Roulekm Pro before the first trip: the snackbar, no paywall ($lang)', (tester) async {
      await pumpApp(tester, device, onboarded: true, sells: true, logbook: const Logbook(vehicles: [clio]));
      await openSettings(tester);
      await tapText(tester, 'Roulekm Pro');
      expect(find.text(t.snackbar), findsOneWidget);
      expect(placement(tester), isNull);
    });

    testWidgets("Settings → Roulekm Pro after a trip: the kit's paywall with Roulekm's header ($lang)", (tester) async {
      await pumpApp(tester, device, onboarded: true, sells: true, logbook: withTrip);
      await openSettings(tester);
      await tapText(tester, 'Roulekm Pro');
      expect(placement(tester), 'settings');
      for (final line in [t.line, ...t.bullets, t.foot]) {
        expect(find.text(line), findsOneWidget);
      }
      expect(find.text('Roulekm Pro'), findsOneWidget, reason: "the header's title");
    });
  }

  testWidgets('the paywall preselects lifetime, in the offering’s order', (tester) async {
    await pumpApp(tester, const Locale('en', 'US'), onboarded: true, sells: true, logbook: withTrip);
    await openSettings(tester);
    await tapText(tester, 'Roulekm Pro');
    expect(find.widgetWithText(FilledButton, 'Buy for 24,99\u00a0€'), findsOneWidget, reason: 'the lifetime plan');
  });

  testWidgets("Settings → Roulekm Pro with Pro: the kit's entitled view", (tester) async {
    final store = FakePurchasesBackend()..entitled.value = true;
    await pumpApp(tester, const Locale('en', 'GB'), onboarded: true, store: store, logbook: withTrip);
    await openSettings(tester);
    await tapText(tester, 'Roulekm Pro');
    expect(find.text('You already have full access.'), findsOneWidget);
  });

  testWidgets('no store on this platform: no Roulekm Pro row', (tester) async {
    await pumpApp(tester, const Locale('en', 'GB'), onboarded: true, logbook: withTrip);
    await openSettings(tester);
    expect(find.text('Roulekm Pro'), findsNothing);
  });

  testWidgets('second_vehicle: bought from the paywall, the vehicle form opens', (tester) async {
    await pumpApp(tester, const Locale('en', 'GB'), onboarded: true, sells: true, logbook: withTrip);
    await openSettings(tester);
    await tapText(tester, 'Vehicles');
    await tapText(tester, 'Add a vehicle');
    expect(placement(tester), 'second_vehicle');
    await tapText(tester, 'Buy for 24,99\u00a0€');
    expect(find.byType(VehicleScreen), findsOneWidget);
  });

  testWidgets('csv_export: the Year screen opens the paywall at its placement', (tester) async {
    await pumpApp(tester, const Locale('en', 'GB'), onboarded: true, sells: true, logbook: withTrip);
    await tester.tap(find.byTooltip('Year and PDF'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('CSV spreadsheet'), 200, scrollable: find.byType(Scrollable).first);
    await tapText(tester, 'CSV spreadsheet');
    expect(placement(tester), 'csv_export');
  });

  testWidgets('recurring_trip: changing a pattern’s days opens the paywall at its placement', (tester) async {
    final pattern = RecurringTrip(id: 'r', route: route, weekdays: const [1], startDate: DateTime.utc(2026, 11, 2));
    await pumpApp(
      tester,
      const Locale('en', 'GB'),
      onboarded: true,
      sells: true,
      logbook: Logbook(vehicles: const [clio], trips: withTrip.trips, recurring: [pattern]),
    );
    await openSettings(tester);
    await tapText(tester, 'Recurring trips');
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tapText(tester, 'Change the days');
    expect(placement(tester), 'recurring_trip');
  });

  testWidgets('Pro ended: both vehicles, their trips and totals stay; a new trip saves with no paywall', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 1600) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = FakePurchasesBackend()..entitled.value = true;
    final data = await pumpApp(
      tester,
      const Locale('en', 'GB'),
      onboarded: true,
      store: store,
      logbook: Logbook(vehicles: const [clio, pickup], trips: withTrip.trips),
    );
    store.entitled.value = false;
    await tester.pumpAndSettle();
    expect(find.text('Clio'), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Add a trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clio').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'From'), 'Home');
    await tester.enterText(find.widgetWithText(TextField, 'To'), 'Site');
    await tester.enterText(find.widgetWithText(TextField, 'One-way distance'), '12');
    await tester.pump();
    await save(tester, data, 'Save\u00a0· 12\u00a0km');
    expect(placement(tester), isNull);
    final log = Logbook.fromJson((await tester.runAsync(data.log.read))!);
    expect(log.vehicles.where((v) => !v.archived), hasLength(2));
    expect(log.trips, hasLength(2));
  });

  testWidgets('free: 1,000 trips in a month, then one more, with no paywall and no count', (tester) async {
    final now = DateTime.now();
    final month = [for (var i = 0; i < 1000; i++) trip(i, DateTime(now.year, now.month, 1 + i % 28))];
    final data = await pumpApp(
      tester,
      const Locale('fr', 'FR'),
      onboarded: true,
      sells: true,
      logbook: Logbook(vehicles: const [clio], trips: month),
    );
    await tester.tap(find.bySemanticsLabel('Ajouter un trajet'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Départ'), 'Domicile');
    await tester.enterText(find.widgetWithText(TextField, 'Arrivée'), 'Chantier');
    await tester.enterText(find.widgetWithText(TextField, 'Distance aller'), '12');
    await tester.pump();
    await save(tester, data, 'Enregistrer\u00a0· 12\u00a0km');
    expect(placement(tester), isNull);
    expect(find.textContaining('1001'), findsNothing, reason: 'no trip count anywhere');
    final log = Logbook.fromJson((await tester.runAsync(data.log.read))!);
    expect(log.trips, hasLength(1001));
  });
}
