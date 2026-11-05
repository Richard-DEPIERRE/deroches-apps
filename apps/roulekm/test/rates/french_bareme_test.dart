import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/rates/french_bareme.dart';

// Expected euros, worked out by hand from the published barème (DAPP-137's `rate-tables`), not from the engine:
// (fiscal horsepower, km for the year, allowance, allowance with the +20% for electric vehicles).
// dart format off
const _cars = [
  (3, 0, 0, 0), (3, 5000, 2645, 3174), (3, 5001, 2645, 3174), (3, 20000, 7385, 8862), (3, 20001, 7400, 8880),
  (4, 0, 0, 0), (4, 5000, 3030, 3636), (4, 5001, 3030, 3636), (4, 20000, 8130, 9756), (4, 20001, 8140, 9768),
  (5, 0, 0, 0), (5, 5000, 3180, 3816), (5, 5001, 3180, 3816), (5, 20000, 8535, 10242), (5, 20001, 8540, 10249),
  (6, 0, 0, 0), (6, 5000, 3325, 3990), (6, 5001, 3327, 3993), (6, 20000, 8937, 10724), (6, 20001, 8940, 10729),
  (7, 0, 0, 0), (7, 5000, 3485, 4182), (7, 5001, 3485, 4182), (7, 20000, 9395, 11274), (7, 20001, 9400, 11281),
];
const _motorbikes = [
  (2, 0, 0, 0), (2, 3000, 1185, 1422), (2, 3001, 1188, 1426), (2, 6000, 1485, 1782), (2, 6001, 1488, 1786),
  (5, 0, 0, 0), (5, 3000, 1404, 1685), (5, 3001, 1404, 1685), (5, 6000, 1650, 1980), (5, 6001, 1650, 1980),
  (6, 0, 0, 0), (6, 3000, 1818, 2182), (6, 3001, 1820, 2184), (6, 6000, 2057, 2468), (6, 6001, 2058, 2470),
];
const _mopeds = [(0, 0, 0), (3000, 945, 1134), (3001, 948, 1138), (6000, 1185, 1422), (6001, 1188, 1426)];
// dart format on

Allowance _allowance(VehicleType type, int? cv, int km, {bool electric = false, int year = 2024}) {
  final result = frenchAllowance(
    Vehicle(type: type, fiscalHorsepower: cv, electric: electric),
    year: year,
    km: km,
  );
  return result as Allowance;
}

void main() {
  for (final year in [2024, 2025]) {
    group('$year barème', () {
      for (final (cv, km, euros, electricEuros) in _cars) {
        test('car $cv CV, $km km', () {
          expect(_allowance(VehicleType.car, cv, km, year: year).euros, euros);
          expect(_allowance(VehicleType.car, cv, km, year: year, electric: true).euros, electricEuros);
        });
      }
      for (final (cv, km, euros, electricEuros) in _motorbikes) {
        test('motorbike $cv CV, $km km', () {
          expect(_allowance(VehicleType.motorbike, cv, km, year: year).euros, euros);
          expect(_allowance(VehicleType.motorbike, cv, km, year: year, electric: true).euros, electricEuros);
        });
      }
      for (final (km, euros, electricEuros) in _mopeds) {
        test('moped, $km km', () {
          expect(_allowance(VehicleType.moped, null, km, year: year).euros, euros);
          expect(_allowance(VehicleType.moped, null, km, year: year, electric: true).euros, electricEuros);
        });
      }

      test('carries its year, its source and whether the +20% applied', () {
        final a = _allowance(VehicleType.car, 5, 100, year: year, electric: true);
        expect(a.year, year);
        expect(a.source.url, startsWith('https://'));
        expect(a.electricBonus, isTrue);
        expect(_allowance(VehicleType.car, 5, 100, year: year).electricBonus, isFalse);
      });

      test('every vehicle type covers every horsepower from 1 CV, with brackets in order', () {
        final bareme = frenchBaremes[year]!;
        for (final bands in bareme.bands.values) {
          var nextCv = 1;
          for (final band in bands) {
            expect(band.minCv, nextCv);
            nextCv = (band.maxCv ?? 1000) + 1;
            final limits = band.brackets.map((b) => b.upToKm).toList();
            expect(limits.last, isNull);
            for (var i = 1; i < limits.length - 1; i++) {
              expect(limits[i]!, greaterThan(limits[i - 1]!));
            }
          }
          expect(nextCv, 1001);
        }
      });
    });
  }

  test('the bracket and its formula come from the whole year\'s distance', () {
    final low = _allowance(VehicleType.car, 3, 5000);
    expect(low.bracket.ratePerKmMilli, 529);
    expect(low.bracket.fixedEuros, 0);
    expect(low.bracketFromKm, 0);
    final mid = _allowance(VehicleType.car, 3, 5001);
    expect(mid.bracket.ratePerKmMilli, 316);
    expect(mid.bracket.fixedEuros, 1065);
    expect(mid.bracketFromKm, 5001);
    expect(_allowance(VehicleType.car, 3, 20001).bracketFromKm, 20001);
    // A trip that crosses 20,000 km moves the whole year into the last bracket: 20,001 km is worth 15 € more than
    // 20,000 km, not the 0,37 € a single extra kilometre would add on its own.
    expect(_allowance(VehicleType.car, 3, 20001).euros - _allowance(VehicleType.car, 3, 20000).euros, 15);
  });

  test('horsepower picks the band', () {
    int band(VehicleType type, int cv) => _allowance(type, cv, 1000).band.minCv;
    expect([1, 3, 4, 5, 6, 7, 12].map((cv) => band(VehicleType.car, cv)), [1, 1, 4, 5, 6, 7, 7]);
    expect([1, 2, 3, 5, 6, 9].map((cv) => band(VehicleType.motorbike, cv)), [1, 1, 3, 3, 6, 6]);
  });

  test('rounds to the nearest euro, half up', () {
    // 500 km × 0,529 = 264,50 €.
    expect(_allowance(VehicleType.car, 3, 500).euros, 265);
    // 1 km × 0,529 = 0,529 €; × 1,2 = 0,6348 €.
    expect(_allowance(VehicleType.car, 3, 1).euros, 1);
  });

  test('a year it does not know is not available, never the nearest year', () {
    for (final year in [2023, 2026, 2027]) {
      final result = frenchAllowance(const Vehicle(type: VehicleType.car, fiscalHorsepower: 5), year: year, km: 100);
      expect(result, isA<BaremeNotAvailable>().having((r) => r.year, 'year', year));
    }
  });

  test('refuses a car or motorbike without horsepower, and a negative distance', () {
    expect(() => frenchAllowance(const Vehicle(type: VehicleType.car), year: 2024, km: 1), throwsArgumentError);
    expect(() => frenchAllowance(const Vehicle(type: VehicleType.motorbike), year: 2024, km: 1), throwsArgumentError);
    expect(
      () => frenchAllowance(const Vehicle(type: VehicleType.car, fiscalHorsepower: 5), year: 2024, km: -1),
      throwsArgumentError,
    );
  });
}
