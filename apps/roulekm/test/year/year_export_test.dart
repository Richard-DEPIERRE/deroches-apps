import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/l10n/roulekm_localizations.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/pro.dart';
import 'package:roulekm/src/rates/distance.dart';
import 'package:roulekm/src/year/year_csv.dart';

import '../home/home_screen_test.dart' show clio;
import 'year_screen_test.dart' show dayTrip, openYear;

final withTrips = Logbook(
  vehicles: const [clio],
  trips: [
    dayTrip('a', 'c', DateTime.utc(2025, 3, 1), 40, DistanceUnit.km),
    dayTrip('b', 'c', DateTime.utc(2026, 11, 2), 36, DistanceUnit.km),
  ],
);

/// What was shared: the file's name, type and bytes.
typedef Shared = (String, String, Uint8List);

void main() {
  late List<String> paywalls;
  late List<Shared> shared;
  late bool buys;
  setUp(() {
    paywalls = [];
    shared = [];
    buys = false;
  });

  OpenPaywall paywall() => (_, placement) async {
    paywalls.add(placement);
    return buys;
  };

  Future<void> tapCsv(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(find.text(label), 200);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('free, before the first trip: the Pro tag, then the snackbar and no paywall', (tester) async {
    await openYear(
      tester,
      'fr',
      const Logbook(vehicles: [clio]),
      openPaywall: paywall(),
      share: (name, type, bytes, _) async => shared.add((name, type, bytes)),
    );
    await tester.scrollUntilVisible(find.text('Tableau CSV'), 200);
    expect(find.text('Exporter'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Tableau CSV'), findsOneWidget);
    expect(find.descendant(of: find.byType(OutlinedButton), matching: find.byType(ProTag)), findsOneWidget);

    await tapCsv(tester, 'Tableau CSV');
    expect(find.text('Disponible avec Roulekm Pro, après votre premier trajet.'), findsOneWidget);
    expect(paywalls, isEmpty);
    expect(shared, isEmpty);
  });

  testWidgets('free, after a trip: the paywall at csv_export; closed without buying, nothing is shared', (
    tester,
  ) async {
    await openYear(
      tester,
      'en',
      withTrips,
      openPaywall: paywall(),
      share: (name, type, bytes, _) async => shared.add((name, type, bytes)),
    );
    await tapCsv(tester, 'CSV spreadsheet');
    expect(paywalls, ['csv_export']);
    expect(shared, isEmpty);
  });

  testWidgets('bought from the paywall: the chosen year\'s CSV goes to the share sheet', (tester) async {
    buys = true;
    await openYear(
      tester,
      'en',
      withTrips,
      openPaywall: paywall(),
      share: (name, type, bytes, _) async => shared.add((name, type, bytes)),
    );
    await tester.tap(find.text('Year 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025').last);
    await tester.pumpAndSettle();
    await tapCsv(tester, 'CSV spreadsheet');

    expect(paywalls, ['csv_export']);
    expect(shared, hasLength(1));
    final (name, type, bytes) = shared.single;
    expect(name, 'roulekm-2025.csv');
    expect(type, 'text/csv');
    expect(bytes, yearCsv(withTrips, 2025, lookupRoulekmLocalizations(const Locale('en'))));
  });

  testWidgets('with Pro: no tag, the year is shared at once', (tester) async {
    await openYear(
      tester,
      'fr',
      withTrips,
      pro: true,
      openPaywall: paywall(),
      share: (name, type, bytes, _) async => shared.add((name, type, bytes)),
    );
    await tester.scrollUntilVisible(find.text('Tableau CSV'), 200);
    expect(find.byType(ProTag), findsNothing);
    await tapCsv(tester, 'Tableau CSV');
    expect(paywalls, isEmpty);
    expect(shared.single.$1, 'roulekm-2026.csv');
    expect(shared.single.$3, yearCsv(withTrips, 2026, lookupRoulekmLocalizations(const Locale('fr'))));
  });
}
