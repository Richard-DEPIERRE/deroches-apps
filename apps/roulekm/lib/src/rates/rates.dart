/// One API for the three rate systems: France's barème (km), HMRC's approved mileage rates (miles) and the IRS
/// standard mileage rate (miles). Give it a period and the trips; it adds up what the law adds up and gives the
/// calculation line by line.
///
/// Pure Dart: no Flutter, no I/O.
library;

import 'dart:math';

import 'distance.dart';
import 'french_bareme.dart';
import 'uk_us_rates.dart';

enum RateSystem {
  france(DistanceUnit.km, [VehicleType.car, VehicleType.motorbike, VehicleType.moped]),
  uk(DistanceUnit.mile, [VehicleType.car, VehicleType.motorbike, VehicleType.bicycle]),

  /// One rate for every vehicle the app logs.
  us(DistanceUnit.mile, [VehicleType.car]);

  const RateSystem(this.unit, this.types);

  /// The unit its totals are shown in.
  final DistanceUnit unit;

  /// The vehicle types it has a rate for.
  final List<VehicleType> types;

  /// The period [date] counts in, named by the year it starts: the income year in France, the tax year from 6 April
  /// in the UK (2026 is 2026-27), the calendar year in the US.
  int periodOf(DateTime date) =>
      this == uk && (date.month < 4 || date.month == 4 && date.day < 6) ? date.year - 1 : date.year;
}

/// The HMRC rates in force on [date]: its tax year's, or the last year in the table when that one isn't in it yet
/// (the first year, for a clock set before the table starts).
HmrcYear hmrcYearOn(DateTime date) {
  final period = RateSystem.uk.periodOf(date);
  final years = hmrcRates.keys.where((y) => y <= period);
  return hmrcRates[years.isEmpty ? hmrcRates.keys.reduce(min) : years.reduce(max)]!;
}

class Trip {
  const Trip(this.date, this.distance, this.vehicle);

  final DateTime date;
  final Distance distance;

  /// Trips of one vehicle share its one [Vehicle] object: lines group vehicles by identity.
  final Vehicle vehicle;
}

/// [distance] × [ratePerUnitMilli], the rate in thousandths of a euro, pound or dollar per km or mile.
class Term {
  const Term(this.distance, this.ratePerUnitMilli);

  final int distance;
  final int ratePerUnitMilli;
}

class ClaimLine {
  const ClaimLine({
    required this.vehicles,
    required this.distance,
    required this.terms,
    required this.source,
    this.fixedMilli = 0,
  });

  /// The vehicles whose distances count together: one vehicle in France, every car and van in the UK (and every
  /// motorcycle, every cycle), every vehicle in the US.
  final List<Vehicle> vehicles;

  /// Their distance for the period, in the system's unit.
  final int distance;

  /// The calculation: the sum of the terms, plus France's fixed part.
  final List<Term> terms;
  final int fixedMilli;
  final BaremeSource source;

  int get milli => terms.fold(fixedMilli, (sum, t) => sum + t.distance * t.ratePerUnitMilli);
  int get cents => _cents(milli);
}

sealed class ClaimResult {
  const ClaimResult();
}

/// The app has no rates for this period: say so, never fall back to another one.
class RatesNotAvailable extends ClaimResult {
  const RatesNotAvailable(this.system, this.period);

  final RateSystem system;
  final int period;
}

class Claim extends ClaimResult {
  const Claim(this.system, this.period, this.lines);

  final RateSystem system;
  final int period;
  final List<ClaimLine> lines;

  /// Exact, in thousandths. No official text rounds it.
  int get milli => lines.fold(0, (sum, l) => sum + l.milli);

  /// The total to the cent (half up), for display: rounded once, on the total.
  int get cents => _cents(milli);
}

int _cents(int milli) => (milli + 5) ~/ 10;

/// The claim for one [period] (see [RateSystem.periodOf]) from [trips]; trips outside the period are left out.
/// Throws an [ArgumentError] for a vehicle the system has no rate for (a bicycle in France, a 2-wheeler in the US).
ClaimResult claim(RateSystem system, {required int period, required List<Trip> trips}) {
  final inPeriod = trips.where((t) => system.periodOf(t.date) == period).toList();
  switch (system) {
    case RateSystem.france:
      if (!frenchBaremes.containsKey(period)) return RatesNotAvailable(system, period);
      return Claim(system, period, [
        for (final MapEntry(key: vehicle, value: trips) in _group(inPeriod, (t) => t.vehicle).entries)
          _frenchLine(vehicle, period, trips),
      ]);
    case RateSystem.uk:
      final rates = hmrcRates[period];
      if (rates == null) return RatesNotAvailable(system, period);
      // Motorcycles (mopeds too) count together, cars and vans together, cycles together.
      final pools = _group(
        inPeriod,
        (t) => t.vehicle.type == VehicleType.moped ? VehicleType.motorbike : t.vehicle.type,
      );
      return Claim(system, period, [
        for (final MapEntry(key: type, value: trips) in pools.entries) _ukLine(type, trips, rates),
      ]);
    case RateSystem.us:
      final rates = irsRates[period];
      if (rates == null) return RatesNotAvailable(system, period);
      for (final t in inPeriod) {
        if (t.vehicle.type != VehicleType.car) {
          throw ArgumentError.value(t.vehicle.type, 'type', 'has no IRS standard mileage rate');
        }
      }
      if (inPeriod.isEmpty) return Claim(system, period, const []);
      final byRate = _group(
        inPeriod,
        (t) => rates.lastWhere((r) => r.from.compareTo(t.date.toIso8601String().substring(0, 10)) <= 0),
      );
      final terms = [for (final e in byRate.entries) Term(_distance(system, e.value), e.key.ratePerMileMilli)];
      return Claim(system, period, [
        ClaimLine(
          vehicles: _vehicles(inPeriod),
          distance: terms.fold(0, (sum, t) => sum + t.distance),
          terms: terms,
          source: irsSource,
        ),
      ]);
  }
}

ClaimLine _frenchLine(Vehicle vehicle, int year, List<Trip> trips) {
  final km = _distance(RateSystem.france, trips);
  final allowance = frenchAllowance(vehicle, year: year, km: km) as Allowance;
  return ClaimLine(
    vehicles: [vehicle],
    distance: km,
    terms: [Term(km, allowance.bracket.ratePerKmMilli)],
    fixedMilli: allowance.bracket.fixedEuros * 1000,
    source: allowance.source,
  );
}

ClaimLine _ukLine(VehicleType type, List<Trip> trips, HmrcYear rates) {
  final miles = _distance(RateSystem.uk, trips);
  return ClaimLine(
    vehicles: _vehicles(trips),
    distance: miles,
    terms: switch (type) {
      VehicleType.car when miles > 10000 => [Term(10000, rates.carFirst10k), Term(miles - 10000, rates.carAbove10k)],
      VehicleType.car => [Term(miles, rates.carFirst10k)],
      VehicleType.motorbike || VehicleType.moped => [Term(miles, rates.motorcycle)],
      VehicleType.bicycle => [Term(miles, rates.cycle)],
    },
    source: hmrcSource,
  );
}

int _distance(RateSystem system, List<Trip> trips) => totalIn(system.unit, trips.map((t) => t.distance));

List<Vehicle> _vehicles(List<Trip> trips) => trips.map((t) => t.vehicle).toSet().toList();

Map<K, List<Trip>> _group<K>(List<Trip> trips, K Function(Trip) key) {
  final groups = <K, List<Trip>>{};
  for (final t in trips) {
    (groups[key(t)] ??= []).add(t);
  }
  return groups;
}
