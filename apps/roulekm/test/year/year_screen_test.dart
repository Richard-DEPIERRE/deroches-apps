import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/l10n/roulekm_localizations.dart';
import 'package:roulekm/src/data/log_controller.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/rates/distance.dart';
import 'package:roulekm/src/rates/french_bareme.dart';
import 'package:roulekm/src/rates/rates.dart';
import 'package:roulekm/src/year/year_screen.dart';

import '../app_test.dart' show pumpApp;
import '../home/home_screen_test.dart' show civic, clio, golf;

const old = VehicleRecord(
  id: 'o',
  name: '206',
  rates: RateSystem.france,
  type: VehicleType.car,
  horsepower: 4,
  archived: true,
);

TripRecord dayTrip(String id, String vehicle, DateTime date, int distance, DistanceUnit unit, {String to = 'B'}) =>
    TripRecord(
      id: id,
      date: date,
      route: TripRoute(from: 'A', to: to, purpose: 'P', distance: Distance(distance, unit), vehicleId: vehicle),
    );

/// The Year screen in [lang] on a 2026-11-16 clock.
Future<LogController> openYear(WidgetTester tester, String lang, Logbook logbook) async {
  final dir = Directory.systemTemp.createTempSync('roulekm_year_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final data = RoulekmData(dir);
  final log = LogController(data.log);
  await tester.runAsync(() => data.log.replace(logbook.toJson()));
  await tester.runAsync(log.open);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: const [...RoulekmLocalizations.localizationsDelegates, KitLocalizations.delegate],
      supportedLocales: RoulekmLocalizations.supportedLocales,
      home: YearScreen(log: log, now: () => DateTime(2026, 11, 16)),
    ),
  );
  return log;
}

void main() {
  testWidgets('in French: this year first, then a past year from the picker, with its own barème and calculation', (
    tester,
  ) async {
    await openYear(
      tester,
      'fr',
      Logbook(
        vehicles: const [clio, old],
        trips: [
          dayTrip('a', 'c', DateTime.utc(2024, 3, 1), 6000, DistanceUnit.km, to: 'Lyon'),
          dayTrip('b', 'c', DateTime.utc(2024, 9, 1), 2412, DistanceUnit.km, to: 'Bron'),
          dayTrip('d', 'o', DateTime.utc(2024, 9, 2), 100, DistanceUnit.km),
          dayTrip('e', 'c', DateTime.utc(2026, 11, 2), 36, DistanceUnit.km),
        ],
      ),
    );
    expect(find.text('Année 2026'), findsOneWidget);
    expect(find.text('36\u00a0km\u00a0· 1 trajet'), findsOneWidget);
    // 2026's barème isn't out: 2025's, said as the latest, then the sentence on next year's.
    expect(
      find.textContaining('Calcul au barème kilométrique 2025, le dernier publié (source\u00a0: impots.gouv.fr'),
      findsOneWidget,
    );
    expect(find.textContaining('Le barème des trajets de 2026 paraît début 2027'), findsOneWidget);

    await tester.tap(find.text('Année 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2024').last);
    await tester.pumpAndSettle();

    expect(find.text('Année 2024'), findsOneWidget);
    // (8 412 × 0,357) + 1 395 = 4 398,08 €, and the archived 206: 100 × 0,606 = 60,60 €.
    expect(find.text('4\u202f459\u00a0€'), findsOneWidget);
    expect(find.text('8\u202f512\u00a0km\u00a0· 3 trajets'), findsOneWidget);
    expect(find.text('(8\u202f412\u00a0×\u00a00,357) + 1\u202f395'), findsOneWidget);
    expect(find.text('4\u202f398\u00a0€'), findsOneWidget);
    expect(find.text('206'), findsOneWidget);
    expect(
      find.textContaining('Calcul au barème kilométrique 2024 (source\u00a0: impots.gouv.fr, lu le'),
      findsOneWidget,
    );
    expect(find.textContaining('paraît début'), findsNothing);

    await tester.scrollUntilVisible(find.text('Mars 2024'), 200);
    expect(find.text('Septembre 2024'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('A vers Lyon')));
    await tester.pumpAndSettle();
    expect(find.text('Modifier le trajet'), findsOneWidget);
  });

  testWidgets('in English: the IRS calculation, rate by rate, and "not tax advice"', (tester) async {
    await openYear(
      tester,
      'en',
      Logbook(
        vehicles: const [civic],
        trips: [
          dayTrip('a', 'u', DateTime.utc(2026, 3, 1), 1000, DistanceUnit.mile),
          dayTrip('b', 'u', DateTime.utc(2026, 8, 1), 200, DistanceUnit.mile),
        ],
      ),
    );
    expect(find.text('Year 2026'), findsOneWidget);
    expect(find.text('1,200\u00a0mi\u00a0· 2 trips'), findsOneWidget);
    expect(find.text('1,000\u00a0×\u00a0\$0.725 + 200\u00a0×\u00a0\$0.76'), findsOneWidget);
    // 725 + 152 = $877
    expect(find.text('\$877'), findsNWidgets(2));
    expect(find.textContaining('it is not tax advice'), findsOneWidget);
  });

  testWidgets('the UK: the tax year, and its two car rates', (tester) async {
    await openYear(
      tester,
      'en',
      Logbook(vehicles: const [golf], trips: [dayTrip('a', 'g', DateTime.utc(2026, 5, 1), 12000, DistanceUnit.mile)]),
    );
    expect(find.text('Tax year 2026–27'), findsOneWidget);
    expect(find.text('10,000\u00a0×\u00a055p + 2,000\u00a0×\u00a025p'), findsOneWidget);
  });

  testWidgets("the home's PDF icon opens the Year screen", (tester) async {
    await pumpApp(tester, const Locale('fr'), onboarded: true);
    await tester.tap(find.byTooltip('Année et PDF'));
    await tester.pumpAndSettle();
    expect(find.byType(YearScreen), findsOneWidget);
  });
}
