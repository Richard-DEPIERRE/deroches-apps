/// The French barème kilométrique: a vehicle and its kilometres for a year give the allowance.
///
/// Pure Dart: no Flutter, no I/O. The figures are data, one file per year under `fr/`; a new year is a new file and
/// one line in [frenchBaremes].
library;

import 'fr/bareme_2024.dart';
import 'fr/bareme_2025.dart';

/// Every barème the app knows, by income year.
const Map<int, FrenchBareme> frenchBaremes = {2024: bareme2024, 2025: bareme2025};

enum VehicleType { car, motorbike, moped }

class Vehicle {
  const Vehicle({required this.type, this.fiscalHorsepower, this.electric = false});

  final VehicleType type;

  /// Puissance fiscale (CV). Needed for cars and motorbikes; mopeds (under 50 cc) have a single band.
  final int? fiscalHorsepower;

  /// Electric vehicles get the barème's amount plus 20%.
  final bool electric;
}

class BaremeSource {
  const BaremeSource({required this.title, required this.url, required this.publishedOn});

  /// The official text's own title, shown as is.
  final String title;
  final String url;

  /// ISO date (yyyy-mm-dd) of the official text.
  final String publishedOn;
}

/// One formula, `km × rate + fixed`, for distances up to [upToKm] (inclusive; null = no limit).
class Bracket {
  const Bracket(this.upToKm, this.ratePerKmMilli, [this.fixedEuros = 0]);

  final int? upToKm;

  /// Euros per km in thousandths: 529 is 0,529 €/km. Integers keep the arithmetic exact.
  final int ratePerKmMilli;
  final int fixedEuros;
}

/// The brackets for fiscal horsepower from [minCv] to [maxCv] (inclusive; null = and above).
class HorsepowerBand {
  const HorsepowerBand(this.minCv, this.maxCv, this.brackets);

  final int minCv;
  final int? maxCv;
  final List<Bracket> brackets;
}

class FrenchBareme {
  const FrenchBareme({required this.year, required this.source, required this.bands, required this.electricBands});

  final int year;
  final BaremeSource source;

  /// For each vehicle type, its bands in ascending horsepower. Mopeds have one band from 1 CV up.
  final Map<VehicleType, List<HorsepowerBand>> bands;

  /// The tables the tax office publishes for 100% electric vehicles: [bands] plus 20%, as it rounds them.
  final Map<VehicleType, List<HorsepowerBand>> electricBands;
}

sealed class BaremeResult {
  const BaremeResult();
}

/// The app has no barème for [year]: say so, never fall back to another year.
class BaremeNotAvailable extends BaremeResult {
  const BaremeNotAvailable(this.year);

  final int year;
}

class Allowance extends BaremeResult {
  const Allowance({
    required this.year,
    required this.source,
    required this.km,
    required this.band,
    required this.bracket,
    required this.bracketFromKm,
    required this.electricBonus,
    required this.milliEuros,
  });

  final int year;
  final BaremeSource source;
  final int km;
  final HorsepowerBand band;

  /// The bracket the whole year's [km] falls in, and so the formula used.
  final Bracket bracket;
  final int bracketFromKm;

  /// Whether the electric table (the barème plus 20%) was used.
  final bool electricBonus;

  /// The exact allowance in thousandths of a euro. No official text rounds it.
  final int milliEuros;

  /// The allowance to the cent (half up), for display.
  int get cents => (milliEuros + 5) ~/ 10;
}

/// The allowance for one vehicle over one year. [km] is that vehicle's whole distance for the year: the bracket
/// depends on it, so never add up the allowances of separate trips or pool different vehicles.
BaremeResult frenchAllowance(Vehicle vehicle, {required int year, required int km}) {
  if (km < 0) throw ArgumentError.value(km, 'km', 'must not be negative');
  final bareme = frenchBaremes[year];
  if (bareme == null) return BaremeNotAvailable(year);

  final cv = vehicle.type == VehicleType.moped ? 1 : vehicle.fiscalHorsepower;
  if (cv == null || cv < 1) {
    throw ArgumentError.value(cv, 'fiscalHorsepower', 'a ${vehicle.type.name} needs its fiscal horsepower');
  }
  final bands = (vehicle.electric ? bareme.electricBands : bareme.bands)[vehicle.type]!;
  final band = bands.firstWhere((b) => cv >= b.minCv && (b.maxCv == null || cv <= b.maxCv!));

  var fromKm = 0;
  var bracket = band.brackets.first;
  for (final b in band.brackets) {
    bracket = b;
    if (b.upToKm == null || km <= b.upToKm!) break;
    fromKm = b.upToKm! + 1;
  }

  return Allowance(
    year: year,
    source: bareme.source,
    km: km,
    band: band,
    bracket: bracket,
    bracketFromKm: fromKm,
    electricBonus: vehicle.electric,
    milliEuros: km * bracket.ratePerKmMilli + bracket.fixedEuros * 1000,
  );
}
