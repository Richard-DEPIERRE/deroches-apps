import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/data/totals.dart';
import 'package:roulekm/src/rates/distance.dart';
import 'package:roulekm/src/rates/french_bareme.dart';
import 'package:roulekm/src/rates/rates.dart';

import 'totals_test.dart' show trip;

void main() {
  const clio = VehicleRecord(id: 'c', name: 'Clio', rates: RateSystem.france, type: VehicleType.car, horsepower: 5);
  const old = VehicleRecord(
    id: 'o',
    name: '206',
    rates: RateSystem.france,
    type: VehicleType.car,
    horsepower: 4,
    archived: true,
  );
  const golf = VehicleRecord(id: 'g', name: 'Golf', rates: RateSystem.uk, type: VehicleType.car);

  test("a past year: its own barème, its trips counted, archived vehicles included, and each one's calculation", () {
    final log = Logbook(
      vehicles: const [clio, old],
      trips: [
        trip('c', DateTime.utc(2024, 3, 1), 6000, DistanceUnit.km),
        trip('c', DateTime.utc(2024, 9, 1), 2412, DistanceUnit.km),
        trip('o', DateTime.utc(2024, 1, 2), 100, DistanceUnit.km),
        trip('c', DateTime.utc(2025, 1, 2), 999, DistanceUnit.km),
      ],
    );
    final totals = yearTotals(log, periodStart(RateSystem.france, 2024));
    final c = totals['c']!;
    expect((c.distance, c.trips), (8412, 2));
    // (8 412 × 0,357) + 1 395 = 4 398,084 €
    expect(c.cents, 439808);
    expect([for (final t in c.line!.terms) (t.distance, t.ratePerUnitMilli)], [(8412, 357)]);
    expect(c.line!.fixedMilli, 1395000);
    final o = totals['o']!;
    expect((o.distance, o.trips, o.cents), (100, 1, 6060));
  });

  test('a vehicle without trips that year: zero, and no calculation', () {
    final log = Logbook(vehicles: const [clio], trips: [trip('c', DateTime.utc(2025, 1, 2), 10, DistanceUnit.km)]);
    final c = yearTotals(log, periodStart(RateSystem.france, 2024))['c']!;
    expect((c.distance, c.trips, c.cents, c.line), (0, 0, 0, null));
  });

  test("the UK year starts on 6 April; the years run from the first trip's to this one, latest first", () {
    expect(periodStart(RateSystem.uk, 2025), DateTime.utc(2025, 4, 6));
    expect(RateSystem.uk.periodOf(periodStart(RateSystem.uk, 2025)), 2025);
    final log = Logbook(
      vehicles: const [golf, clio],
      trips: [
        trip('g', DateTime.utc(2024, 4, 5), 10, DistanceUnit.mile), // 2023-24
        trip('c', DateTime.utc(2025, 6, 1), 10, DistanceUnit.km),
      ],
    );
    expect(yearsOf(log, DateTime(2026, 11, 16)), [2026, 2025, 2024, 2023]);
    expect(yearsOf(const Logbook(), DateTime(2026, 11, 16)), [2026]);
  });
}
