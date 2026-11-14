import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/rates/distance.dart';
import 'package:roulekm/src/rates/french_bareme.dart';
import 'package:roulekm/src/rates/rates.dart';

import '../data_upgrade/sample.dart';

void main() {
  Map<String, Object?> fixtureData() =>
      (jsonDecode(File('test/data_upgrade/fixtures/log.schema1.json').readAsStringSync()) as Map)['data']
          as Map<String, Object?>;

  test('schema 1 is exactly what the fixture holds: this code wrote it', () {
    expect(jsonDecode(jsonEncode(schema1Logbook.toJson())), fixtureData());
  });

  test('decoding what was encoded gives the same logbook', () {
    final decoded = Logbook.fromJson(jsonDecode(jsonEncode(schema1Logbook.toJson())) as Map<String, Object?>);
    expect(decoded, schema1Logbook);
    expect(decoded.items, hasLength(9));
  });

  test('a new install starts with an empty logbook', () {
    expect(Logbook.fromJson(Logbook.empty), const Logbook());
    expect(const Logbook().toJson(), Logbook.empty);
  });

  test('copyWith keeps every other field of a vehicle', () {
    for (final v in schema1Logbook.vehicles) {
      expect(v.copyWith(archived: !v.archived).toJson(), {...v.toJson(), 'archived': !v.archived});
    }
  });

  test('a vehicle is saved with its archived flag, false by default', () {
    const v = VehicleRecord(id: 'v', name: 'Moto', rates: RateSystem.uk, type: VehicleType.motorbike);
    expect(v.toJson(), {
      'id': 'v',
      'name': 'Moto',
      'rates': 'uk',
      'type': 'motorbike',
      'horsepower': null,
      'electric': false,
      'archived': false,
    });
  });

  test('a trip keeps its distance in the unit it was typed in, and a round trip counts twice', () {
    final trip = schema1Logbook.trips.last;
    expect(trip.route.distance.unit, DistanceUnit.mile);
    expect(trip.route.counted.value, 42);
    expect(schema1Logbook.trips[1].route.counted.value, 112);
  });

  test('a date is a calendar day, whatever the time zone', () {
    expect(schema1Logbook.trips.first.toJson()['date'], '2026-01-12');
    expect(TripRecord.fromJson(schema1Logbook.trips.first.toJson()).date, DateTime.utc(2026, 1, 12));
  });

  test('the distance from two odometer readings is arrival minus departure, and none until arrival is above it', () {
    expect(odometerDistance(32580, 32614), 34);
    expect(odometerDistance(32614, 32580), isNull);
    expect(odometerDistance(32580, 32580), isNull);
    expect(odometerDistance(32580, null), isNull);
    expect(odometerDistance(null, 32614), isNull);
  });

  test('trips latest day first; on the same day, the one added last first', () {
    TripRecord trip(String id, int day) =>
        TripRecord(id: id, date: DateTime.utc(2026, 11, day), route: schema1Logbook.trips.first.route);
    final log = Logbook(trips: [trip('a', 3), trip('b', 5), trip('c', 3), trip('d', 4)]);
    expect([for (final t in log.latestFirst) t.id], ['b', 'd', 'c', 'a']);
  });

  test("the form's suggestions are the user's own places and purposes, latest first, each once", () {
    expect(schema1Logbook.places, [
      'Office',
      'Warehouse',
      'Bureau',
      'Client Martin, Lyon',
      'Domicile',
      'Chantier Durand',
    ]);
    expect(schema1Logbook.purposes, ['Delivery', 'Rendez-vous client', 'Suivi de chantier']);
    const blank = TripRoute(
      from: ' ',
      to: 'Gare',
      purpose: '',
      distance: Distance(3, DistanceUnit.km),
      vehicleId: 'v1',
    );
    final log = Logbook(
      trips: [TripRecord(id: 'x', date: DateTime.utc(2026), route: blank)],
    );
    expect(log.places, ['Gare']);
    expect(log.purposes, isEmpty);
  });
}
