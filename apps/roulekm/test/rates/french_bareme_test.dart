import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/rates/french_bareme.dart';

// Expected cents, worked out from DAPP-137's fact-checked `rate-tables` (the base tables and the published tables for
// 100% electric vehicles), not from the engine: (fiscal horsepower, km for the year, cents, electric cents).
// dart format off
const _cars = [
  (3, 0, 0, 0), (3, 5000, 264500, 317500), (3, 5001, 264532, 317338), (3, 20000, 738500, 885800), (3, 20001, 740037, 888044),
  (4, 0, 0, 0), (4, 5000, 303000, 363500), (4, 5001, 303034, 363641), (4, 20000, 813000, 975600), (4, 20001, 814041, 976049),
  (5, 0, 0, 0), (5, 5000, 318000, 381500), (5, 5001, 318036, 381443), (5, 20000, 853500, 1023400), (5, 20001, 854043, 1024051),
  (6, 0, 0, 0), (6, 5000, 332500, 399000), (6, 5001, 332737, 399345), (6, 20000, 893700, 1072800), (6, 20001, 894045, 1072054),
  (7, 0, 0, 0), (7, 5000, 348500, 418000), (7, 5001, 348539, 418347), (7, 20000, 939500, 1127800), (7, 20001, 940047, 1128056),
];
const _motorbikes = [
  (2, 0, 0, 0), (2, 3000, 118500, 142200), (2, 3001, 118810, 142612), (2, 6000, 148500, 178300), (2, 6001, 148825, 178830),
  (5, 0, 0, 0), (5, 3000, 140400, 168600), (5, 3001, 140408, 168410), (5, 6000, 165000, 197800), (5, 6001, 165028, 198033),
  (6, 0, 0, 0), (6, 3000, 181800, 218100), (6, 3001, 182008, 218510), (6, 6000, 205700, 247000), (6, 6001, 205834, 247241),
];
const _mopeds = [(0, 0, 0), (3000, 94500, 113400), (3001, 94808, 113810), (6000, 118500, 142300), (6001, 118820, 142824)];
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
      for (final (cv, km, cents, electricCents) in _cars) {
        test('car $cv CV, $km km', () {
          expect(_allowance(VehicleType.car, cv, km, year: year).cents, cents);
          expect(_allowance(VehicleType.car, cv, km, year: year, electric: true).cents, electricCents);
        });
      }
      for (final (cv, km, cents, electricCents) in _motorbikes) {
        test('motorbike $cv CV, $km km', () {
          expect(_allowance(VehicleType.motorbike, cv, km, year: year).cents, cents);
          expect(_allowance(VehicleType.motorbike, cv, km, year: year, electric: true).cents, electricCents);
        });
      }
      for (final (km, cents, electricCents) in _mopeds) {
        test('moped, $km km', () {
          expect(_allowance(VehicleType.moped, null, km, year: year).cents, cents);
          expect(_allowance(VehicleType.moped, null, km, year: year, electric: true).cents, electricCents);
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
        for (final bands in [...bareme.bands.values, ...bareme.electricBands.values]) {
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
    // A trip that crosses 20,000 km moves the whole year into the last bracket: 20,001 km is worth 15,37 € more than
    // 20,000 km, not the 0,37 € a single extra kilometre would add on its own.
    expect(_allowance(VehicleType.car, 3, 20001).cents - _allowance(VehicleType.car, 3, 20000).cents, 1537);
  });

  test('horsepower picks the band', () {
    int band(VehicleType type, int cv) => _allowance(type, cv, 1000).band.minCv;
    expect([1, 3, 4, 5, 6, 7, 12].map((cv) => band(VehicleType.car, cv)), [1, 1, 4, 5, 6, 7, 7]);
    expect([1, 2, 3, 5, 6, 9].map((cv) => band(VehicleType.motorbike, cv)), [1, 1, 3, 3, 6, 6]);
  });

  test('keeps the exact amount, and shows it to the cent, half up', () {
    expect(_allowance(VehicleType.car, 6, 5001).milliEuros, 3327374);
    // 5 km × 0,529 = 2,645 €.
    expect(_allowance(VehicleType.car, 3, 5).cents, 265);
  });

  test("DAPP-137's worked examples", () {
    expect(_allowance(VehicleType.car, 5, 4000, year: 2025).cents, 254400); // service-public A14686
    expect(_allowance(VehicleType.car, 6, 12000).cents, 594500);
    expect(_allowance(VehicleType.car, 3, 25000).cents, 925000);
    expect(_allowance(VehicleType.car, 5, 6000, electric: true).cents, 424200);
    expect(_allowance(VehicleType.motorbike, 4, 4000).cents, 148600);
    expect(_allowance(VehicleType.moped, null, 7000).cents, 138600);
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
