import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/data/totals.dart';
import 'package:roulekm/src/rates/distance.dart';
import 'package:roulekm/src/rates/french_bareme.dart';
import 'package:roulekm/src/rates/rates.dart';
import 'package:roulekm/src/rates/uk_us_rates.dart';

TripRecord trip(String vehicle, DateTime date, int distance, DistanceUnit unit) => TripRecord(
  id: '$vehicle$date$distance',
  date: date,
  route: TripRoute(from: 'A', to: 'B', purpose: 'P', distance: Distance(distance, unit), vehicleId: vehicle),
);

void main() {
  group('rules', ruleTests);

  const clio = VehicleRecord(id: 'c', name: 'Clio', rates: RateSystem.france, type: VehicleType.car, horsepower: 5);

  test("a year whose barème isn't out yet is counted at the latest one; other years' trips are left out", () {
    final log = Logbook(
      vehicles: const [clio],
      trips: [
        trip('c', DateTime.utc(2026, 1, 12), 100, DistanceUnit.km),
        trip('c', DateTime.utc(2026, 11, 2), 36, DistanceUnit.km),
        trip('c', DateTime.utc(2025, 12, 31), 500, DistanceUnit.km),
      ],
    );
    final total = vehicleTotals(log, DateTime(2026, 11, 9))['c']!;
    expect(total.distance, 136);
    final allowance = frenchAllowance(const Vehicle(type: VehicleType.car, fiscalHorsepower: 5), year: 2025, km: 136);
    expect(total.cents, (allowance as Allowance).cents);
  });

  test('UK cars share the first 10,000 miles, archived ones too, and the amount is shared out by distance', () {
    const a = VehicleRecord(id: 'a', name: 'A', rates: RateSystem.uk, type: VehicleType.car);
    const b = VehicleRecord(id: 'b', name: 'B', rates: RateSystem.uk, type: VehicleType.car, archived: true);
    final log = Logbook(
      vehicles: const [a, b],
      trips: [
        trip('a', DateTime.utc(2026, 4, 6), 6000, DistanceUnit.mile),
        trip('b', DateTime.utc(2027, 4, 5), 6000, DistanceUnit.mile),
        trip('a', DateTime.utc(2026, 4, 5), 9000, DistanceUnit.mile), // 2025-26
      ],
    );
    final totals = vehicleTotals(log, DateTime(2026, 11, 9));
    // 10,000 × 55p + 2,000 × 25p = £6,000, half each.
    expect(totals['a'], (distance: 6000, cents: 300000));
    expect(totals['b'], (distance: 6000, cents: 300000));
  });

  test('no trips: nothing yet; a clock before every table: the distance, no amount', () {
    final log = Logbook(vehicles: const [clio], trips: [trip('c', DateTime.utc(2023, 5, 1), 10, DistanceUnit.km)]);
    expect(vehicleTotals(log, DateTime(2026, 11, 9))['c'], (distance: 0, cents: 0));
    expect(vehicleTotals(log, DateTime(2023, 6, 1))['c'], (distance: 10, cents: null));
  });
}

void ruleTests() {
  VehicleRule rule(VehicleRecord v, List<TripRecord> trips, DateTime now, [List<VehicleRecord> others = const []]) {
    final log = Logbook(vehicles: [v, ...others], trips: trips);
    return vehicleRule(v, log, vehicleTotals(log, now), now)!;
  }

  const clio = VehicleRecord(id: 'c', name: 'Clio', rates: RateSystem.france, type: VehicleType.car, horsepower: 5);
  final nov = DateTime(2026, 11, 11);

  test('France: the bar has the barème\'s three brackets and the year moves to the next one past 5,000 km', () {
    final below = rule(clio, [trip('c', DateTime.utc(2026, 3, 1), 4800, DistanceUnit.km)], nov);
    expect(below.limits, [5000, 20000]);
    expect((below.index, below.fill, below.rateMilli, below.fixedEuros), (0, .96, 636, 0));
    final above = rule(clio, [trip('c', DateTime.utc(2026, 3, 1), 5300, DistanceUnit.km)], nov);
    expect((above.index, above.fill, above.rateMilli, above.fixedEuros), (1, .02, 357, 1395));
    final far = rule(clio, [trip('c', DateTime.utc(2026, 3, 1), 25000, DistanceUnit.km)], nov);
    expect((far.index, far.fill, far.rateMilli), (2, 1.0, 427));
  });

  test('France: an electric car gets the electric table', () {
    const zoe = VehicleRecord(
      id: 'z',
      name: 'Zoé',
      rates: RateSystem.france,
      type: VehicleType.car,
      horsepower: 5,
      electric: true,
    );
    final electric = frenchBaremes[2025]!.electricBands[VehicleType.car]!.firstWhere((b) => b.maxCv == 5);
    expect(rule(zoe, [], nov).rateMilli, electric.brackets.first.ratePerKmMilli);
  });

  test('UK: the cars share the 10,000-mile bar; bicycles have one rate and no bar', () {
    const a = VehicleRecord(id: 'a', name: 'A', rates: RateSystem.uk, type: VehicleType.car);
    const b = VehicleRecord(id: 'b', name: 'B', rates: RateSystem.uk, type: VehicleType.car);
    final first = [trip('a', DateTime.utc(2026, 5, 1), 6000, DistanceUnit.mile)];
    final alone = rule(a, first, nov, [b]);
    expect(alone.limits, [10000]);
    expect((alone.index, alone.fill, alone.rateMilli), (0, .6, 550));
    final pooled = rule(a, [...first, trip('b', DateTime.utc(2026, 6, 1), 4500, DistanceUnit.mile)], nov, [b]);
    expect((pooled.index, pooled.fill, pooled.rateMilli), (1, 1.0, 250));
    const bike = VehicleRecord(id: 'k', name: 'K', rates: RateSystem.uk, type: VehicleType.bicycle);
    final cycle = rule(bike, [], nov);
    expect(cycle.limits, isEmpty);
    expect(cycle.rateMilli, 200);
  });

  test(
    "US: the rate in force today; while the new year's isn't out, the latest year's on the same day, as the totals",
    () {
      const civic = VehicleRecord(id: 'u', name: 'Civic', rates: RateSystem.us, type: VehicleType.car);
      expect(rule(civic, [], DateTime(2026, 3, 1)).rateMilli, 725);
      expect(rule(civic, [], nov).rateMilli, 760);
      expect(rule(civic, [], DateTime(2027, 2, 1)).rateMilli, 725);
    },
  );

  test('ratesFor: the period, the year of the rates used and their source', () {
    final france = ratesFor(RateSystem.france, nov)!;
    expect((france.period, france.year, france.source), (2026, 2025, frenchBaremes[2025]!.source));
    final uk = ratesFor(RateSystem.uk, DateTime(2026, 4, 5))!;
    expect((uk.period, uk.year, uk.source), (2025, 2025, hmrcSource));
    final us = ratesFor(RateSystem.us, DateTime(2027, 1, 2))!;
    expect((us.period, us.year, us.source), (2027, 2026, irsSource));
    expect(ratesFor(RateSystem.us, DateTime(2023, 6, 1)), isNull);
  });
}
