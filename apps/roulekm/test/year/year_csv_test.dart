import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/l10n/roulekm_localizations.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/rates/distance.dart';
import 'package:roulekm/src/year/year_csv.dart';

import '../home/home_screen_test.dart' show civic, clio, golf;
import 'year_screen_test.dart' show old;

TripRecord trip(
  String id,
  String vehicle,
  DateTime date,
  String from,
  String to,
  String purpose,
  int distance,
  DistanceUnit unit, {
  bool roundTrip = false,
  int? start,
  int? end,
}) => TripRecord(
  id: id,
  date: date,
  route: TripRoute(
    from: from,
    to: to,
    purpose: purpose,
    distance: Distance(distance, unit),
    vehicleId: vehicle,
    roundTrip: roundTrip,
  ),
  odometerStart: start,
  odometerEnd: end,
);

/// The bytes after the BOM, which must be there.
String body(List<int> bytes) {
  expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
  return utf8.decode(bytes.skip(3).toList());
}

void main() {
  test('in French: the year in date order, ";" and quoted text, return trips both ways, readings, archived', () {
    final logbook = Logbook(
      vehicles: const [clio, old],
      trips: [
        trip(
          'b',
          'o',
          DateTime.utc(2025, 3, 2),
          'Bureau',
          'Client',
          'Visite "client"; devis',
          42,
          DistanceUnit.km,
          start: 32580,
          end: 32622,
        ),
        trip(
          'a',
          'c',
          DateTime.utc(2025, 1, 6),
          'Domicile',
          'Chantier Bron',
          'Chantier',
          18,
          DistanceUnit.km,
          roundTrip: true,
        ),
        trip('x', 'c', DateTime.utc(2024, 12, 31), 'A', 'B', 'Hors année', 5, DistanceUnit.km),
        trip('y', 'c', DateTime.utc(2026, 1, 1), 'A', 'B', 'Hors année', 5, DistanceUnit.km),
      ],
    );
    final csv = yearCsv(logbook, 2025, lookupRoulekmLocalizations(const Locale('fr')));
    expect(
      body(csv),
      'Date;Départ;Arrivée;Motif;Distance;Unité;Véhicule;Barème;Compteur départ;Compteur arrivée\r\n'
      '06/01/2025;Domicile;Chantier Bron;Chantier (A/R);36;km;Clio;France;;\r\n'
      '02/03/2025;Bureau;Client;"Visite ""client""; devis";42;km;206 (archivé);France;32580;32622\r\n',
    );
  });

  test('in English: "," and a point, the UK tax year from 6 April, the US calendar year', () {
    final logbook = Logbook(
      vehicles: [civic, golf.copyWith(archived: true)],
      trips: [
        trip(
          'a',
          'u',
          DateTime.utc(2025, 3, 2),
          'Austin, TX',
          'Dallas',
          'Client visit',
          195,
          DistanceUnit.mile,
          roundTrip: true,
        ),
        // The UK's 2025 is 6 April 2025 to 5 April 2026.
        trip('b', 'g', DateTime.utc(2025, 4, 5), 'Home', 'Depot', 'Before', 3, DistanceUnit.mile),
        trip(
          'c',
          'g',
          DateTime.utc(2026, 2, 1),
          'Home',
          'Depot',
          'Delivery',
          12,
          DistanceUnit.mile,
          start: 10200,
          end: 10212,
        ),
      ],
    );
    final csv = yearCsv(logbook, 2025, lookupRoulekmLocalizations(const Locale('en')));
    expect(
      body(csv),
      'Date,From,To,Business purpose,Distance,Unit,Vehicle,Rate system,Start reading,End reading\r\n'
      '2025-03-02,"Austin, TX",Dallas,Client visit (round trip),390,mi,Civic,US · IRS,,\r\n'
      '2026-02-01,Home,Depot,Delivery,12,mi,Golf (archived),UK · HMRC,10200,10212\r\n',
    );
  });

  test('a year with no trip is the header row alone', () {
    final csv = yearCsv(const Logbook(vehicles: [clio]), 2025, lookupRoulekmLocalizations(const Locale('en')));
    expect(body(csv), 'Date,From,To,Business purpose,Distance,Unit,Vehicle,Rate system,Start reading,End reading\r\n');
  });
}
