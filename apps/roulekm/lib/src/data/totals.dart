import 'dart:math';

import '../rates/distance.dart';
import '../rates/french_bareme.dart';
import '../rates/rates.dart';
import '../rates/uk_us_rates.dart';
import 'logbook.dart';

/// A vehicle's distance for the period, in its rate system's unit, and its amount in cents (null: no rates at all).
typedef VehicleTotal = ({int distance, int? cents});

/// Each vehicle's total for the period that holds [now] ([RateSystem.periodOf]), archived ones included.
///
/// A period whose rates aren't published yet is counted at the latest ones (the home names them, DAPP-141 §1): its
/// trips are moved to that period, day for day. Where the law pools vehicles (the UK's cars, the US), the line's
/// amount is shared out by distance.
Map<String, VehicleTotal> vehicleTotals(Logbook log, DateTime now) {
  final totals = <String, VehicleTotal>{};
  for (final system in RateSystem.values) {
    final period = system.periodOf(now);
    final published = _years(system).where((y) => y <= period);
    final ratesYear = published.isEmpty ? null : published.reduce(max);
    final shift = period - (ratesYear ?? period);
    final vehicles = {
      for (final v in log.vehicles)
        if (v.rates == system) v.id: Vehicle(type: v.type, fiscalHorsepower: v.horsepower, electric: v.electric),
    };
    final trips = [
      for (final t in log.trips)
        if (vehicles[t.route.vehicleId] case final vehicle? when system.periodOf(t.date) == period)
          Trip(DateTime.utc(t.date.year - shift, t.date.month, t.date.day), t.route.counted, vehicle),
    ];
    final result = ratesYear == null ? null : claim(system, period: ratesYear, trips: trips);
    for (final MapEntry(key: id, value: vehicle) in vehicles.entries) {
      final distance = totalIn(system.unit, [
        for (final t in trips)
          if (identical(t.vehicle, vehicle)) t.distance,
      ]);
      final line = switch (result) {
        Claim(:final lines) => lines.where((l) => l.vehicles.any((v) => identical(v, vehicle))).firstOrNull,
        _ => null,
      };
      totals[id] = (
        distance: distance,
        cents: result is! Claim
            ? null
            : line == null || line.distance == 0
            ? 0
            : (line.milli * distance / line.distance / 10).round(),
      );
    }
  }
  return totals;
}

Iterable<int> _years(RateSystem system) => switch (system) {
  RateSystem.france => frenchBaremes.keys,
  RateSystem.uk => hmrcRates.keys,
  RateSystem.us => irsRates.keys,
};
