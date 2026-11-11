import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/l10n/roulekm_localizations.dart';
import 'package:roulekm/src/data/log_controller.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/home/home_screen.dart';
import 'package:roulekm/src/rates/distance.dart';
import 'package:roulekm/src/rates/french_bareme.dart';
import 'package:roulekm/src/rates/rates.dart';

/// The home in [lang] on a 2026-11-11 clock, over [vehicles] and one trip per entry of [trips] (vehicle id, distance).
Future<LogController> openHome(
  WidgetTester tester,
  String lang,
  List<VehicleRecord> vehicles, [
  Map<String, int> trips = const {},
]) async {
  final dir = Directory.systemTemp.createTempSync('roulekm_home_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final data = RoulekmData(dir);
  final log = LogController(data.log);
  final logbook = Logbook(vehicles: vehicles, trips: [for (final e in trips.entries) trip(e.key, e.value, vehicles)]);
  await tester.runAsync(() => data.log.replace(logbook.toJson()));
  await tester.runAsync(log.open);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: const [...RoulekmLocalizations.localizationsDelegates, KitLocalizations.delegate],
      supportedLocales: RoulekmLocalizations.supportedLocales,
      home: HomeScreen(log: log, settings: (_) => const Text('settings'), now: () => DateTime(2026, 11, 11)),
    ),
  );
  return log;
}

TripRecord trip(String vehicleId, int distance, List<VehicleRecord> vehicles, [String id = 't1']) {
  final unit = vehicles.firstWhere((v) => v.id == vehicleId).rates.unit;
  return TripRecord(
    id: id,
    date: DateTime.utc(2026, 10, 1),
    route: TripRoute(from: 'A', to: 'B', purpose: 'P', distance: Distance(distance, unit), vehicleId: vehicleId),
  );
}

/// Runs a log change outside the test's fake time, then lets the screen rebuild.
Future<void> change(WidgetTester tester, Future<void> Function() action) async {
  await tester.runAsync(action);
  await tester.pumpAndSettle();
}

const clio = VehicleRecord(id: 'c', name: 'Clio', rates: RateSystem.france, type: VehicleType.car, horsepower: 5);
const golf = VehicleRecord(id: 'g', name: 'Golf', rates: RateSystem.uk, type: VehicleType.car);
const civic = VehicleRecord(id: 'u', name: 'Civic', rates: RateSystem.us, type: VehicleType.car);

void main() {
  testWidgets('in French: the year and the total follow trips added, edited and deleted, across 5,000 km', (
    tester,
  ) async {
    final log = await openHome(tester, 'fr', [clio], {'c': 4800});
    expect(find.widgetWithText(AppBar, '2026'), findsOneWidget);
    // 4 800 × 0,636 = 3 052,80 €
    expect(find.text('Frais kilométriques 2026 : 3 053 €'), findsOneWidget);
    expect(find.text('3 053 €'), findsOneWidget);
    expect(find.text('4 800 km cette année'), findsOneWidget);
    expect(find.bySemanticsLabel('Ajouter un trajet'), findsOneWidget);

    // A trip added: 5 200 km, (5 200 × 0,357) + 1 395 = 3 251,40 €.
    await change(tester, () => log.saveTrip(trip('c', 400, [clio], 't2')));
    expect(find.text('3 251 €'), findsOneWidget);
    expect(find.text('5 200 km cette année'), findsOneWidget);

    // Edited down to 100 km, then deleted: back under 5 000 km.
    await change(tester, () => log.saveTrip(trip('c', 100, [clio], 't2')));
    expect(find.text('4 900 km cette année'), findsOneWidget);
    await change(tester, () => log.deleteTrip('t2'));
    expect(find.text('3 053 €'), findsOneWidget);
  });

  testWidgets('in English: a UK car crossing 10,000 miles in the 2026–27 tax year', (tester) async {
    final log = await openHome(tester, 'en', [golf], {'g': 9800});
    expect(find.widgetWithText(AppBar, '2026–27'), findsOneWidget);
    expect(find.text('2026–27 tax year: £5,390'), findsOneWidget, reason: '9,800 × 55p');
    expect(find.text('9,800 mi this tax year'), findsOneWidget);
    expect(find.text('trip'), findsOneWidget);

    // 10,000 × 55p + 200 × 25p = £5,550
    await change(tester, () => log.saveTrip(trip('g', 400, [golf], 't2')));
    expect(find.text('£5,550'), findsOneWidget);
  });

  testWidgets('in English: a US car, in dollars', (tester) async {
    await openHome(tester, 'en', [civic], {'u': 1000});
    expect(find.text('2026 mileage deduction: \$760'), findsOneWidget);
  });

  testWidgets('no vehicle in use: one card asks for it, and the vehicle form opens', (tester) async {
    await openHome(tester, 'fr', const []);
    expect(find.text('Ajoutez votre véhicule pour voir vos frais'), findsOneWidget);
    await tester.tap(find.text('Ajouter mon véhicule'));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau véhicule'), findsOneWidget);
  });

  testWidgets('a vehicle card opens its form', (tester) async {
    await openHome(tester, 'en', [clio]);
    await tester.tap(find.text('Clio'));
    await tester.pumpAndSettle();
    expect(find.text('Edit vehicle'), findsOneWidget);
  });
}
