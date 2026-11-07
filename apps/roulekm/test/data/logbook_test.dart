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
}
