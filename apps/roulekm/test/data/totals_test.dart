import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/data/totals.dart';
import 'package:roulekm/src/rates/distance.dart';
import 'package:roulekm/src/rates/french_bareme.dart';
import 'package:roulekm/src/rates/rates.dart';

TripRecord trip(String vehicle, DateTime date, int distance, DistanceUnit unit) => TripRecord(
  id: '$vehicle$date$distance',
  date: date,
  route: TripRoute(from: 'A', to: 'B', purpose: 'P', distance: Distance(distance, unit), vehicleId: vehicle),
);

void main() {
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
