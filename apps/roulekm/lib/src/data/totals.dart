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
    final ratesYear = ratesFor(system, now)?.year;
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

/// The rates [system] uses for the period that holds [now]: that period's, or the latest published while its own
/// aren't out yet (null: the clock is before every table).
({int period, int year, BaremeSource source})? ratesFor(RateSystem system, DateTime now) {
  final period = system.periodOf(now);
  final published = _years(system).where((y) => y <= period);
  if (published.isEmpty) return null;
  final year = published.reduce(max);
  final source = switch (system) {
    RateSystem.france => frenchBaremes[year]!.source,
    RateSystem.uk => hmrcSource,
    RateSystem.us => irsSource,
  };
  return (period: period, year: year, source: source);
}

/// Where a vehicle's year sits in its rate, for its home card (DAPP-141 §1).
class VehicleRule {
  const VehicleRule({
    required this.rateMilli,
    this.limits = const [],
    this.index = 0,
    this.fill = 0,
    this.fixedEuros = 0,
  });

  /// The bar's segments: each one's upper limit but the last's ([5000, 20000] is 0–5,000, 5,001–20,000 and over).
  /// Empty: one rate whatever the distance, so no bar.
  final List<int> limits;

  /// The segment the year is in, and how far into it (the last one, open-ended, is full).
  final int index;
  final double fill;

  /// Its rate per km or mile in thousandths, and France's fixed part in whole euros.
  final int rateMilli;
  final int fixedEuros;
}

/// [vehicle]'s rule for the period that holds [now], from [totals] ([vehicleTotals] of [log]); null without rates.
VehicleRule? vehicleRule(VehicleRecord vehicle, Logbook log, Map<String, VehicleTotal> totals, DateTime now) {
  final rates = ratesFor(vehicle.rates, now);
  if (rates == null) return null;
  final distance = totals[vehicle.id]!.distance;
  switch (vehicle.rates) {
    case RateSystem.france:
      final v = Vehicle(type: vehicle.type, fiscalHorsepower: vehicle.horsepower, electric: vehicle.electric);
      final allowance = frenchAllowance(v, year: rates.year, km: distance) as Allowance;
      final brackets = allowance.band.brackets;
      return _segments(
        [for (final b in brackets) ?b.upToKm],
        distance,
        allowance.bracket.ratePerKmMilli,
        allowance.bracket.fixedEuros,
      );
    case RateSystem.uk:
      final year = hmrcRates[rates.year]!;
      if (vehicle.type != VehicleType.car) {
        return VehicleRule(rateMilli: vehicle.type == VehicleType.bicycle ? year.cycle : year.motorcycle);
      }
      // Every car and van counts towards the same 10,000 miles.
      final pool = [
        for (final v in log.vehicles)
          if (v.rates == RateSystem.uk && v.type == VehicleType.car) totals[v.id]!.distance,
      ].fold(0, (a, b) => a + b);
      return _segments([10000], pool, pool > 10000 ? year.carAbove10k : year.carFirst10k);
    case RateSystem.us:
      // Today's date, moved into the rates' year when that year is an earlier one.
      final day = DateTime.utc(now.year - (rates.period - rates.year), now.month, now.day);
      final iso = day.toIso8601String().substring(0, 10);
      return VehicleRule(
        rateMilli: irsRates[rates.year]!.lastWhere((r) => r.from.compareTo(iso) <= 0).ratePerMileMilli,
      );
  }
}

VehicleRule _segments(List<int> limits, int distance, int rateMilli, [int fixedEuros = 0]) {
  final index = limits.where((l) => distance > l).length;
  final from = index == 0 ? 0 : limits[index - 1];
  final fill = index == limits.length ? 1.0 : (distance - from) / (limits[index] - from);
  return VehicleRule(limits: limits, index: index, fill: fill, rateMilli: rateMilli, fixedEuros: fixedEuros);
}

Iterable<int> _years(RateSystem system) => switch (system) {
  RateSystem.france => frenchBaremes.keys,
  RateSystem.uk => hmrcRates.keys,
  RateSystem.us => irsRates.keys,
};
