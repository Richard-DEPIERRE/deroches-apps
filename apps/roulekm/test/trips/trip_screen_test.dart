import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/l10n/roulekm_localizations.dart';
import 'package:roulekm/src/data/log_controller.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/rates/distance.dart';
import 'package:roulekm/src/rates/french_bareme.dart';
import 'package:roulekm/src/rates/rates.dart';
import 'package:roulekm/src/trips/trip_screen.dart';

const clio = VehicleRecord(id: 'v1', name: 'Clio', rates: RateSystem.france, type: VehicleType.car, horsepower: 5);
const pickup = VehicleRecord(id: 'v3', name: 'Pickup', rates: RateSystem.us, type: VehicleType.car);
final today = DateTime(2026, 11, 5, 9);

/// Opens the trip form on a phone in [device], over a host screen; [saved] counts the first-value calls.
Future<LogController> openTrip(
  WidgetTester tester,
  Locale device, {
  List<VehicleRecord> vehicles = const [clio],
  List<int>? saved,
}) async {
  final dir = Directory.systemTemp.createTempSync('roulekm_trip_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final data = RoulekmData(dir);
  final log = LogController(data.log);
  await tester.runAsync(() => data.log.replace(Logbook(vehicles: vehicles).toJson()));
  await tester.runAsync(log.open);
  tester.platformDispatcher.localesTestValue = [device];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  tester.view.physicalSize = const Size(390, 1600) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(device.languageCode),
      localizationsDelegates: RoulekmLocalizations.localizationsDelegates,
      supportedLocales: RoulekmLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => openTripScreen(context, log, tripSaved: () async => saved?.add(1), now: () => today),
            child: const Text('host'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('host'));
  await tester.pumpAndSettle();
  return log;
}

Future<void> type(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextField, label), text);
  await tester.pump();
}

Future<void> tapSave(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await settle(tester);
}

/// Saves started by a tap run in the test's fake time: pump while real time passes, so each write reaches the disk.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a typed trip in French is saved with its day, places, purpose and distance', (tester) async {
    final saved = <int>[];
    final log = await openTrip(tester, const Locale('fr', 'FR'), saved: saved);
    expect(find.text('Nouveau trajet'), findsOneWidget);
    expect(find.text('Jeudi 5 novembre 2026'), findsOneWidget);
    expect(find.text('Véhicule'), findsNothing, reason: 'one vehicle in use: no vehicle chips');
    await type(tester, 'Départ', ' Domicile ');
    await type(tester, 'Arrivée', 'Chantier Bron');
    await type(tester, 'Motif', 'Suivi de chantier');
    await type(tester, 'Distance aller', '34');
    await tapSave(tester, 'Enregistrer · 34\u00a0km');

    expect(find.text('Nouveau trajet'), findsNothing, reason: 'the form closes');
    final trip = log.logbook!.trips.single;
    expect(trip.date, DateTime.utc(2026, 11, 5));
    expect(
      trip.route,
      const TripRoute(
        from: 'Domicile',
        to: 'Chantier Bron',
        purpose: 'Suivi de chantier',
        distance: Distance(34, DistanceUnit.km),
        vehicleId: 'v1',
      ),
    );
    expect(log.logbook!.favourites, isEmpty);
    expect(saved, [1], reason: 'a saved trip is the first useful moment');
  });

  testWidgets('a round trip counts both ways and keeps its one-way distance', (tester) async {
    final log = await openTrip(tester, const Locale('en', 'US'), vehicles: [pickup]);
    await type(tester, 'From', 'Office');
    await type(tester, 'To', 'Warehouse');
    await type(tester, 'One-way distance', '21');
    expect(find.text('mi'), findsOneWidget);
    await tester.tap(find.text('Round trip'));
    await tester.pump();
    expect(find.text('Counts 42 mi'), findsOneWidget);
    await tapSave(tester, 'Save · 42 mi');

    final route = log.logbook!.trips.single.route;
    expect([route.distance.value, route.distance.unit], [21, DistanceUnit.mile]);
    expect(route.roundTrip, isTrue);
    expect(route.purpose, '', reason: 'the purpose may stay empty');
  });

  testWidgets('without a place or a distance nothing is saved, and each says so', (tester) async {
    final saved = <int>[];
    final log = await openTrip(tester, const Locale('en', 'US'), saved: saved);
    await type(tester, 'One-way distance', '0');
    await tapSave(tester, 'Save');
    expect(find.text('Enter where the trip started'), findsOneWidget);
    expect(find.text('Enter where it ended'), findsOneWidget);
    expect(find.text('Enter the distance'), findsOneWidget);
    expect(log.logbook!.trips, isEmpty);
    expect(saved, isEmpty);
  });

  testWidgets('with two vehicles in use, the picked one is saved; a favourite keeps the same route', (tester) async {
    final log = await openTrip(tester, const Locale('en', 'US'), vehicles: [clio, pickup]);
    expect(find.text('Vehicle'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pickup'));
    await tester.pump();
    await type(tester, 'From', 'Office');
    await type(tester, 'To', 'Bank');
    await type(tester, 'One-way distance', '3');
    await tester.tap(find.text('Save as a favorite'));
    await tapSave(tester, 'Save · 3 mi');

    final trip = log.logbook!.trips.single;
    expect(trip.route.vehicleId, 'v3');
    expect(trip.route.distance.unit, DistanceUnit.mile);
    expect(log.logbook!.favourites.single.route, trip.route);
  });

  testWidgets('with no vehicle yet, saving asks for one first, then saves the trip with it', (tester) async {
    final log = await openTrip(tester, const Locale('en', 'US'), vehicles: const []);
    await type(tester, 'From', 'Office');
    await type(tester, 'To', 'Bank');
    await type(tester, 'One-way distance', '3');
    await tester.tap(find.widgetWithText(FilledButton, 'Save · 3 mi'));
    await tester.pumpAndSettle();
    await type(tester, 'Name', 'Pickup');
    await tapSave(tester, 'Save');

    final vehicle = log.inUse.single;
    expect(log.logbook!.trips.single.route.vehicleId, vehicle.id);
    expect(find.text('New trip'), findsNothing);
  });
}
