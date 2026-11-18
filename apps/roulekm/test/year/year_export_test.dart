import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/l10n/roulekm_localizations.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/pro.dart';
import 'package:roulekm/src/rates/distance.dart';
import 'package:roulekm/src/year/year_csv.dart';
import 'package:roulekm/src/year/year_screen.dart';

import '../home/home_screen_test.dart' show clio, golf, zoe;
import 'year_screen_test.dart' show dayTrip, openYear;

final withTrips = Logbook(
  vehicles: const [clio],
  trips: [
    dayTrip('a', 'c', DateTime.utc(2025, 3, 1), 40, DistanceUnit.km),
    dayTrip('b', 'c', DateTime.utc(2026, 11, 2), 36, DistanceUnit.km),
  ],
);

/// The two exports: their button in French and English, and their placement.
const exports = [
  (fr: 'Relevé PDF de l’année', en: 'Year’s PDF log', placement: 'pdf_export'),
  (fr: 'Tableau CSV', en: 'CSV spreadsheet', placement: 'csv_export'),
];

void main() {
  late List<String> paywalls;
  late List<List<SharedFile>> shares;
  late bool buys;
  setUp(() {
    paywalls = [];
    shares = [];
    buys = false;
  });

  OpenPaywall paywall() => (_, placement) async {
    paywalls.add(placement);
    return buys;
  };

  Future<void> record(List<SharedFile> files, Rect _) async => shares.add(files);

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(find.text(label), 200);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('the Exporter section: the PDF (filled) above the CSV (outlined), each with the Pro tag', (tester) async {
    await openYear(tester, 'fr', withTrips);
    await tester.scrollUntilVisible(find.text('Tableau CSV'), 200);
    expect(find.text('Exporter'), findsOneWidget);
    final pdf = find.widgetWithText(FilledButton, 'Relevé PDF de l’année');
    final csv = find.widgetWithText(OutlinedButton, 'Tableau CSV');
    expect(tester.getTopLeft(pdf).dy, lessThan(tester.getTopLeft(csv).dy));
    expect(find.descendant(of: pdf, matching: find.byType(ProTag)), findsOneWidget);
    expect(find.descendant(of: csv, matching: find.byType(ProTag)), findsOneWidget);
  });

  for (final e in exports) {
    group(e.placement, () {
      testWidgets('free, before the first trip: the snackbar and no paywall', (tester) async {
        await openYear(
          tester,
          'fr',
          const Logbook(vehicles: [clio]),
          openPaywall: paywall(),
          share: record,
        );
        await tap(tester, e.fr);
        expect(find.text('Disponible avec Roulekm Pro, après votre premier trajet.'), findsOneWidget);
        expect(paywalls, isEmpty);
        expect(shares, isEmpty);
      });

      testWidgets('free, after a trip: the paywall; closed without buying, nothing is shared', (tester) async {
        await openYear(tester, 'en', withTrips, openPaywall: paywall(), share: record);
        await tap(tester, e.en);
        expect(paywalls, [e.placement]);
        expect(shares, isEmpty);
      });

      testWidgets('with Pro, a year without trips: no file, just "Aucun trajet en 2026"', (tester) async {
        final logbook = Logbook(vehicles: const [clio], trips: [withTrips.trips.first]);
        await openYear(tester, 'fr', logbook, pro: true, share: record);
        await tap(tester, e.fr);
        expect(find.text('Aucun trajet en 2026'), findsOneWidget);
        expect(shares, isEmpty);
      });

      testWidgets('with Pro, a UK tax year without trips: "No trips in tax year 2026–27"', (tester) async {
        await openYear(tester, 'en', const Logbook(vehicles: [golf]), pro: true, share: record);
        await tap(tester, e.en);
        expect(find.text('No trips in tax year 2026–27'), findsOneWidget);
        expect(shares, isEmpty);
      });

      testWidgets('the share sheet fails: a snackbar says so', (tester) async {
        await openYear(tester, 'fr', withTrips, pro: true, share: (_, _) async => throw Exception('no sheet'));
        await tap(tester, e.fr);
        expect(find.text('Le partage n’a pas pu s’ouvrir. Réessayez.'), findsOneWidget);
      });

      testWidgets('the share sheet fails, in English', (tester) async {
        await openYear(tester, 'en', withTrips, pro: true, share: (_, _) async => throw Exception('no sheet'));
        await tap(tester, e.en);
        expect(find.text('The share sheet didn’t open. Try again.'), findsOneWidget);
      });
    });
  }

  testWidgets('bought from the paywall: the chosen year\'s CSV goes to the share sheet', (tester) async {
    buys = true;
    await openYear(tester, 'en', withTrips, openPaywall: paywall(), share: record);
    await tester.tap(find.text('Year 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025').last);
    await tester.pumpAndSettle();
    await tap(tester, 'CSV spreadsheet');

    expect(paywalls, ['csv_export']);
    final file = shares.single.single;
    expect(file.name, 'roulekm-2025.csv');
    expect(file.mimeType, 'text/csv');
    expect(file.bytes, yearCsv(withTrips, 2025, lookupRoulekmLocalizations(const Locale('en'))));
  });

  testWidgets('with Pro: no tag, one PDF per vehicle with trips that year, shared at once', (tester) async {
    final logbook = Logbook(
      vehicles: const [clio, zoe],
      trips: [...withTrips.trips, dayTrip('z', 'z', DateTime.utc(2026, 5, 4), 12, DistanceUnit.km)],
    );
    await openYear(tester, 'fr', logbook, pro: true, openPaywall: paywall(), share: record);
    await tester.scrollUntilVisible(find.text('Tableau CSV'), 200);
    expect(find.byType(ProTag), findsNothing);
    await tap(tester, 'Relevé PDF de l’année');

    expect(paywalls, isEmpty);
    final files = shares.single;
    expect(files, hasLength(2));
    for (final f in files) {
      expect(f.name, endsWith('.pdf'));
      expect(f.mimeType, 'application/pdf');
      expect(String.fromCharCodes(f.bytes.take(5)), '%PDF-');
    }
    expect(files.first.name, isNot(files.last.name));
  });

  testWidgets('bought from the paywall: the PDF goes to the share sheet', (tester) async {
    buys = true;
    await openYear(tester, 'en', withTrips, openPaywall: paywall(), share: record);
    await tap(tester, 'Year’s PDF log');
    expect(paywalls, ['pdf_export']);
    expect(shares.single.single.mimeType, 'application/pdf');
  });

  testWidgets('with Pro, the CSV: no tag, shared at once', (tester) async {
    await openYear(tester, 'fr', withTrips, pro: true, openPaywall: paywall(), share: record);
    await tap(tester, 'Tableau CSV');
    expect(paywalls, isEmpty);
    expect(shares.single.single.name, 'roulekm-2026.csv');
    expect(shares.single.single.bytes, yearCsv(withTrips, 2026, lookupRoulekmLocalizations(const Locale('fr'))));
  });
}
