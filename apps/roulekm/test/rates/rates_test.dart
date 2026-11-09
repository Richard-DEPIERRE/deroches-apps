import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/rates/distance.dart';
import 'package:roulekm/src/rates/french_bareme.dart';
import 'package:roulekm/src/rates/rates.dart';

// Expected amounts come from DAPP-137's fact-checked `rate-tables` (sections 2 and 3, read 2026-11-05), worked out by
// hand, not from the engine.
const _car = Vehicle(type: VehicleType.car);
const _van = Vehicle(type: VehicleType.car, electric: true);
const _motorbike = Vehicle(type: VehicleType.motorbike);
const _moped = Vehicle(type: VehicleType.moped);
const _bicycle = Vehicle(type: VehicleType.bicycle);

Trip _miles(DateTime date, int miles, [Vehicle vehicle = _car]) =>
    Trip(date, Distance(miles, DistanceUnit.mile), vehicle);
Trip _km(DateTime date, int km, Vehicle vehicle) => Trip(date, Distance(km, DistanceUnit.km), vehicle);

Claim _claim(RateSystem system, int period, List<Trip> trips) => claim(system, period: period, trips: trips) as Claim;

void main() {
  group('UK, HMRC', () {
    // (tax year, miles, pence): 45p / 25p up to 2025-26, 55p / 25p from 2026-27.
    // dart format off
    const step = [
      (2024, 9999, 449955), (2024, 10000, 450000), (2024, 10001, 450025),
      (2025, 9999, 449955), (2025, 10000, 450000), (2025, 10001, 450025),
      (2026, 9999, 549945), (2026, 10000, 550000), (2026, 10001, 550025),
    ];
    // dart format on
    for (final (year, miles, pence) in step) {
      test('car, $miles miles in $year-${year % 100 + 1}', () {
        expect(_claim(RateSystem.uk, year, [_miles(DateTime(year, 5), miles)]).cents, pence);
      });
    }

    test("gov.uk's worked examples: 12,000 miles → £6,000, 11,000 → £5,750 (2026-27)", () {
      final c = _claim(RateSystem.uk, 2026, [_miles(DateTime(2026, 6), 12000)]);
      expect(c.cents, 600000);
      expect(c.lines.single.terms.map((t) => (t.distance, t.ratePerUnitMilli)), [(10000, 550), (2000, 250)]);
      expect(_claim(RateSystem.uk, 2026, [_miles(DateTime(2026, 6), 11000)]).cents, 575000);
      expect(_claim(RateSystem.uk, 2024, [_miles(DateTime(2024, 6), 12000)]).cents, 500000);
    });

    test('the 10,000 miles count all cars and vans together (s.230(3))', () {
      final c = _claim(RateSystem.uk, 2026, [_miles(DateTime(2026, 5), 6000), _miles(DateTime(2026, 9), 6000, _van)]);
      expect(c.lines.single.vehicles, [_car, _van]);
      expect(c.lines.single.distance, 12000);
      expect(c.cents, 600000);
    });

    test('motorcycles (mopeds too) 24p, cycles 20p, each on its own line', () {
      final c = _claim(RateSystem.uk, 2025, [
        _miles(DateTime(2025, 5), 2000, _motorbike),
        _miles(DateTime(2025, 6), 1000, _moped),
        _miles(DateTime(2025, 7), 500, _bicycle),
      ]);
      expect(c.lines.map((l) => l.vehicles), [
        [_motorbike, _moped],
        [_bicycle],
      ]);
      expect(c.lines.map((l) => l.cents), [72000, 10000]);
      expect(c.cents, 82000);
    });

    test('the tax year runs 6 April to 5 April', () {
      expect(RateSystem.uk.periodOf(DateTime(2026, 4, 5)), 2025);
      expect(RateSystem.uk.periodOf(DateTime(2026, 4, 6)), 2026);
      expect(RateSystem.uk.periodOf(DateTime(2027, 4, 5, 23, 59)), 2026);
      final trips = [_miles(DateTime(2026, 4, 5), 100), _miles(DateTime(2026, 4, 6), 100)];
      expect(_claim(RateSystem.uk, 2025, trips).cents, 4500);
      expect(_claim(RateSystem.uk, 2026, trips).cents, 5500);
    });

    test('unknown tax years are not available, 2027-28 included (announced, not law)', () {
      for (final year in [2023, 2027]) {
        expect(claim(RateSystem.uk, period: year, trips: const []), isA<RatesNotAvailable>());
      }
    });
  });

  group('US, IRS', () {
    test('each year: 67¢ (2024), 70¢ (2025)', () {
      expect(_claim(RateSystem.us, 2024, [_miles(DateTime(2024, 3), 10000)]).cents, 670000);
      expect(_claim(RateSystem.us, 2025, [_miles(DateTime(2025, 12, 31), 1000)]).cents, 70000);
    });

    test('2026: 72.5¢ to 30 June, 76¢ from 1 July, by the date of the trip', () {
      final c = _claim(RateSystem.us, 2026, [
        _miles(DateTime(2026, 3, 2), 600),
        _miles(DateTime(2026, 6, 30), 400),
        _miles(DateTime(2026, 7, 1), 1000),
      ]);
      expect(c.lines.single.terms.map((t) => (t.distance, t.ratePerUnitMilli)), [(1000, 725), (1000, 760)]);
      expect(c.cents, 148500);
    });

    test('every vehicle shares the one rate; a 2-wheeler has none', () {
      expect(
        _claim(RateSystem.us, 2025, [_miles(DateTime(2025, 1), 10), _miles(DateTime(2025, 2), 10, _van)]).cents,
        1400,
      );
      expect(
        () => claim(RateSystem.us, period: 2025, trips: [_miles(DateTime(2025, 1), 10, _motorbike)]),
        throwsArgumentError,
      );
    });

    test('unknown years are not available', () {
      for (final year in [2023, 2027]) {
        expect(claim(RateSystem.us, period: year, trips: const []), isA<RatesNotAvailable>());
      }
    });
  });

  group('France, through the same API', () {
    const clio = Vehicle(type: VehicleType.car, fiscalHorsepower: 5);
    const zoe = Vehicle(type: VehicleType.car, fiscalHorsepower: 5, electric: true); // 0,763 €/km

    test('each vehicle on its own (service-public: 5 CV, 4,000 km in 2025 → 2,544 €)', () {
      final c = _claim(RateSystem.france, 2025, [
        _km(DateTime(2025, 2), 2500, clio),
        _km(DateTime(2025, 9), 1500, clio),
        _km(DateTime(2025, 3), 4000, zoe),
        _km(DateTime(2024, 12, 31), 900, clio),
      ]);
      expect(c.lines.map((l) => l.vehicles), [
        [clio],
        [zoe],
      ]);
      expect(c.lines.map((l) => (l.distance, l.cents)), [(4000, 254400), (4000, 305200)]);
      expect(c.lines.first.terms.single.ratePerUnitMilli, 636);
    });

    test('2026 is not available; a bicycle has no barème', () {
      expect(claim(RateSystem.france, period: 2026, trips: const []), isA<RatesNotAvailable>());
      expect(
        () => claim(RateSystem.france, period: 2025, trips: [_km(DateTime(2025, 1), 10, _bicycle)]),
        throwsArgumentError,
      );
    });
  });

  group('units', () {
    test('km and miles convert once, on the total of each unit, rounded half up', () {
      expect(totalIn(DistanceUnit.mile, const [Distance(100, DistanceUnit.km)]), 62); // 62.137
      expect(totalIn(DistanceUnit.km, const [Distance(100, DistanceUnit.mile)]), 161); // 160.934
      expect(totalIn(DistanceUnit.mile, List.filled(3, const Distance(1, DistanceUnit.km))), 2); // 1.864, not 3 × 1
      expect(totalIn(DistanceUnit.km, const [Distance(7, DistanceUnit.km), Distance(1, DistanceUnit.mile)]), 9);
      expect(totalIn(DistanceUnit.km, const []), 0);
    });

    test('a trip logged in km counts in miles in the UK, and the other way round in France', () {
      const clio = Vehicle(type: VehicleType.car, fiscalHorsepower: 5);
      expect(_claim(RateSystem.uk, 2026, [_km(DateTime(2026, 5), 100, _car)]).lines.single.distance, 62);
      expect(_claim(RateSystem.france, 2025, [_miles(DateTime(2025, 5), 100, clio)]).lines.single.distance, 161);
    });
  });

  group('the form', () {
    test('shows the HMRC year in force: it starts on 6 April', () {
      expect(hmrcYearOn(DateTime(2026, 3, 31)).carFirst10k, 450, reason: '2025-26');
      expect(hmrcYearOn(DateTime(2026, 4, 5)).carFirst10k, 450, reason: '2025-26');
      expect(hmrcYearOn(DateTime(2026, 4, 6)).carFirst10k, 550, reason: '2026-27');
    });

    test('a tax year not in the table yet keeps the last one', () {
      expect(hmrcYearOn(DateTime(2030, 5)).carFirst10k, 550);
      expect(hmrcYearOn(DateTime(2023, 6)).carFirst10k, 450, reason: 'a clock before the table: its first year');
    });

    test('offers only the types each system has a rate for', () {
      expect(RateSystem.france.types, [VehicleType.car, VehicleType.motorbike, VehicleType.moped]);
      expect(RateSystem.uk.types, [VehicleType.car, VehicleType.motorbike, VehicleType.bicycle]);
      expect(RateSystem.us.types, [VehicleType.car]);
    });
  });
}
