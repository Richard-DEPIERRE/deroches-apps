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
import 'package:roulekm/src/vehicles/vehicles_screen.dart';

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
const zoe = VehicleRecord(
  id: 'z',
  name: 'Zoé',
  rates: RateSystem.france,
  type: VehicleType.car,
  horsepower: 4,
  electric: true,
);
const golf = VehicleRecord(id: 'g', name: 'Golf', rates: RateSystem.uk, type: VehicleType.car);
const civic = VehicleRecord(id: 'u', name: 'Civic', rates: RateSystem.us, type: VehicleType.car);

void main() {
  testWidgets('in French: the year, the total, the bracket and its rule move as a car crosses 5,000 km', (
    tester,
  ) async {
    final log = await openHome(tester, 'fr', [clio], {'c': 4800});
    expect(find.widgetWithText(AppBar, '2026'), findsOneWidget);
    // 4 800 × 0,636 = 3 052,80 €
    expect(find.text('Frais kilométriques 2026 : 3 053 €'), findsOneWidget);
    expect(find.text('3 053 €'), findsOneWidget);
    expect(find.text('4 800 km cette année'), findsOneWidget);
    expect(find.text('Tranche jusqu’à 5 000 km : d\u00a0×\u00a00,636'), findsOneWidget);
    expect(find.text('0 – 5 000'), findsOneWidget);
    expect(find.text('Barème kilométrique 2025, le dernier publié · source : impots.gouv.fr'), findsOneWidget);
    expect(find.bySemanticsLabel('Ajouter un trajet'), findsOneWidget);

    // A trip added: 5 200 km, (5 200 × 0,357) + 1 395 = 3 251,40 €.
    await change(tester, () => log.saveTrip(trip('c', 400, [clio], 't2')));
    expect(find.text('3 251 €'), findsOneWidget);
    expect(find.text('5 200 km cette année'), findsOneWidget);
    expect(find.text('Tranche 5 001 – 20 000 km : (d\u00a0×\u00a00,357) + 1 395 €'), findsOneWidget);

    // Edited down to 100 km, then deleted: back under 5 000 km.
    await change(tester, () => log.saveTrip(trip('c', 100, [clio], 't2')));
    expect(find.text('4 900 km cette année'), findsOneWidget);
    await change(tester, () => log.deleteTrip('t2'));
    expect(find.text('3 053 €'), findsOneWidget);
    expect(find.textContaining('Tranche jusqu’à'), findsOneWidget);
  });

  testWidgets('in French: an electric car says so and is counted at the electric table', (tester) async {
    await openHome(tester, 'fr', [zoe], {'z': 1000});
    expect(find.text('électrique +20 %'), findsOneWidget);
    expect(find.text('4 CV'), findsOneWidget);
    final rate = frenchBaremes[2025]!.electricBands[VehicleType.car]!.firstWhere((b) => b.maxCv == 4);
    final euros = (1000 * rate.brackets.first.ratePerKmMilli / 1000).round();
    expect(find.text('$euros €'), findsOneWidget);
  });

  testWidgets('in English: a UK car crossing 10,000 miles in the 2026–27 tax year', (tester) async {
    final log = await openHome(tester, 'en', [golf], {'g': 9800});
    expect(find.widgetWithText(AppBar, '2026–27'), findsOneWidget);
    expect(find.text('2026–27 tax year: £5,390'), findsOneWidget, reason: '9,800 × 55p');
    expect(find.text('9,800 mi this tax year'), findsOneWidget);
    expect(find.text('First 10,000 business miles: 55p a mile'), findsOneWidget);
    expect(find.text('HMRC approved mileage rates, 2026–27 · source: gov.uk'), findsOneWidget);
    expect(find.text('trip'), findsOneWidget);

    // 10,000 × 55p + 200 × 25p = £5,550
    await change(tester, () => log.saveTrip(trip('g', 400, [golf], 't2')));
    expect(find.text('£5,550'), findsOneWidget);
    expect(find.text('Above 10,000 business miles: 25p a mile'), findsOneWidget);
  });

  testWidgets('in English: a US car has one rate and no bar', (tester) async {
    await openHome(tester, 'en', [civic], {'u': 1000});
    expect(find.text('2026 mileage deduction: \$760'), findsOneWidget);
    expect(find.text('IRS standard rate: 76¢ a business mile'), findsOneWidget);
    expect(find.text('IRS standard mileage rate for 2026 · source: irs.gov'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('0 – '), findsNothing);
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

  testWidgets('at 2× text the bracket labels hide and the rule line stays', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openHome(tester, 'fr', [clio], {'c': 4800});
    expect(find.text('0 – 5 000'), findsNothing);
    expect(find.textContaining('Tranche jusqu’à'), findsOneWidget);
  });

  testWidgets('at 2× text, the icons beside text grow with it up to 1.5×', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openHome(tester, 'fr', [clio], {'c': 100});
    expect(tester.getSize(find.byIcon(vehicleIcon(VehicleType.car))), const Size.square(30));
    expect(tester.getSize(find.byIcon(Icons.add)), const Size.square(42));
  });

  testWidgets('two rate systems: each total line sits at 16 dp, the second 24 dp under the first group', (
    tester,
  ) async {
    await openHome(tester, 'en', [clio, golf]);
    final france = find.text('2026 mileage expenses: €0');
    final uk = find.text('2026–27 tax year: £0');
    expect(tester.getTopLeft(france).dx, 16);
    expect(tester.getTopLeft(uk).dx, 16);
    final clioCard = find.ancestor(of: find.text('Clio'), matching: find.byType(Card));
    expect(tester.getTopLeft(uk).dy - tester.getBottomLeft(clioCard).dy, 24);
  });
}
