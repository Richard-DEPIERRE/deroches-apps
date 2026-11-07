import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/rates/distance.dart';
import 'package:roulekm/src/rates/french_bareme.dart';
import 'package:roulekm/src/rates/rates.dart';

/// Made-up content, never a real user's: what `fixtures/log.schema1.json` holds.
final schema1Logbook = Logbook(
  vehicles: const [
    VehicleRecord(id: 'v1', name: 'Clio', rates: RateSystem.france, type: VehicleType.car, horsepower: 5),
    VehicleRecord(
      id: 'v2',
      name: 'Zoé',
      rates: RateSystem.france,
      type: VehicleType.car,
      horsepower: 4,
      electric: true,
      archived: true,
    ),
    VehicleRecord(id: 'v3', name: 'Pickup', rates: RateSystem.us, type: VehicleType.car),
  ],
  trips: [
    TripRecord(id: 't1', date: DateTime.utc(2026, 1, 12), route: _chantier, odometerStart: 32580, odometerEnd: 32614),
    TripRecord(
      id: 't2',
      date: DateTime.utc(2026, 3, 2),
      route: const TripRoute(
        from: 'Bureau',
        to: 'Client Martin, Lyon',
        purpose: 'Rendez-vous client',
        distance: Distance(112, DistanceUnit.km),
        vehicleId: 'v2',
      ),
    ),
    TripRecord(
      id: 't3',
      date: DateTime.utc(2026, 10, 30),
      route: const TripRoute(
        from: 'Office',
        to: 'Warehouse',
        purpose: 'Delivery',
        distance: Distance(21, DistanceUnit.mile),
        vehicleId: 'v3',
        roundTrip: true,
      ),
    ),
  ],
  favourites: const [FavouriteTrip(id: 'f1', route: _chantier)],
  recurring: [
    RecurringTrip(id: 'r1', route: _chantier, weekdays: const [1, 2, 3, 4, 5], startDate: DateTime.utc(2026, 11, 3)),
    RecurringTrip(
      id: 'r2',
      route: _chantier,
      weekdays: const [6],
      startDate: DateTime.utc(2026, 9, 5),
      checkedThrough: DateTime.utc(2026, 10, 31),
      paused: true,
    ),
  ],
);

const _chantier = TripRoute(
  from: 'Domicile',
  to: 'Chantier Durand',
  purpose: 'Suivi de chantier',
  distance: Distance(34, DistanceUnit.km),
  vehicleId: 'v1',
  roundTrip: true,
);
