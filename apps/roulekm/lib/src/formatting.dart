import 'dart:math';

import 'package:intl/intl.dart';

import '../l10n/roulekm_localizations.dart';
import 'data/logbook.dart';
import 'rates/distance.dart';
import 'rates/french_bareme.dart';
import 'rates/rates.dart';

// The text shared by the screens and the yearly PDF (DAPP-373): no widgets here, so the PDF imports no screen.

/// The latest barème: its bands label a vehicle's horsepower.
final latestBareme = frenchBaremes[frenchBaremes.keys.reduce(max)]!;

/// A distance in the unit it was typed in.
String typedDistance(RoulekmLocalizations l10n, String lang, Distance d) => d.unit == DistanceUnit.km
    ? l10n.distanceKm(NumberFormat.decimalPattern(lang).format(d.value))
    : l10n.distanceMiles(NumberFormat.decimalPattern(lang).format(d.value));

String vehicleTypeLabel(RoulekmLocalizations l10n, VehicleType type) => switch (type) {
  VehicleType.car => l10n.vehicleTypeCar,
  VehicleType.motorbike => l10n.vehicleTypeMotorbike,
  VehicleType.moped => l10n.vehicleTypeMoped,
  VehicleType.bicycle => l10n.vehicleTypeBicycle,
};

String bandLabel(RoulekmLocalizations l10n, HorsepowerBand b) => switch (b) {
  HorsepowerBand(maxCv: null) => l10n.vehicleHorsepowerFrom(b.minCv),
  HorsepowerBand(minCv: 1, :final maxCv?) => l10n.vehicleHorsepowerUpTo(maxCv),
  HorsepowerBand(:final minCv, :final maxCv?) when minCv == maxCv => l10n.vehicleHorsepowerOne(minCv),
  HorsepowerBand(:final minCv, :final maxCv?) => l10n.vehicleHorsepowerRange(minCv, maxCv),
};

/// "Voiture · 5 CV · thermique", "Car or van · HMRC rates": the vehicle's line in the list.
String vehicleSummary(RoulekmLocalizations l10n, VehicleRecord v) => [
  vehicleTypeLabel(l10n, v.type),
  ...switch (v.rates) {
    RateSystem.france => [
      if (v.horsepower case final cv?)
        bandLabel(l10n, latestBareme.bands[v.type]!.firstWhere((b) => cv >= b.minCv && cv <= (b.maxCv ?? cv))),
      v.electric ? l10n.vehicleEngineElectric : l10n.vehicleEngineFuel,
    ],
    RateSystem.uk => [l10n.vehicleRatesUkShort],
    RateSystem.us => [l10n.vehicleRatesUsShort],
  },
].join('\u00a0· '); // the dot stays at the end of a line

/// The calculation with the user's numbers (a wrapped line starts with "+", never ends with it): "(8 412 × 0,357) + 1 395", "10,000 × 55p + 2,000 × 25p",
/// "1,000 × $0.725 + 200 × $0.76".
String calculation(RateSystem system, String lang, ClaimLine line) {
  final number = NumberFormat.decimalPattern(lang);
  String rate(int milli) => switch (system) {
    RateSystem.france => NumberFormat.decimalPatternDigits(locale: lang, decimalDigits: 3).format(milli / 1000),
    RateSystem.uk => '${number.format(milli / 10)}p',
    RateSystem.us => '\$${NumberFormat('0.00#', lang).format(milli / 1000)}',
  };
  final terms = [for (final t in line.terms) '${number.format(t.distance)} × ${rate(t.ratePerUnitMilli)}'];
  return line.fixedMilli == 0
      ? terms.join(' +\u00a0')
      : '(${terms.join(' +\u00a0')}) +\u00a0${number.format(line.fixedMilli ~/ 1000)}';
}
