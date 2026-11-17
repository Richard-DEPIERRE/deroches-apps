import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../l10n/roulekm_localizations.dart';
import '../data/logbook.dart';
import '../rates/distance.dart';
import '../rates/rates.dart';

/// The trips counted in [year], earliest first (on the same day, the one added first): each trip by its vehicle's
/// period, so a UK vehicle's 2026 is its tax year 2026–27.
List<TripRecord> yearTrips(Logbook logbook, int year) {
  final systemOf = {for (final v in logbook.vehicles) v.id: v.rates};
  return [
    for (final t in logbook.latestFirst.reversed)
      if (systemOf[t.route.vehicleId]?.periodOf(t.date) == year) t,
  ];
}

/// [year]'s trips as a CSV file for a spreadsheet (DAPP-141 §9), made on the phone: the PDF's columns plus vehicle,
/// rate system, unit and the odometer readings, one row per trip. UTF-8 with a BOM so Excel reads the accents; in
/// French `;` between fields (Excel's French list separator, as the decimal comma takes `,`), in English `,`. Every
/// number is a whole number with no thousands separator, so spreadsheets read it as a number in either language.
Uint8List yearCsv(Logbook logbook, int year, RoulekmLocalizations l10n) {
  final french = l10n.localeName == 'fr';
  final separator = french ? ';' : ',';
  final date = DateFormat(french ? 'dd/MM/yyyy' : 'yyyy-MM-dd');
  final vehicles = {for (final v in logbook.vehicles) v.id: v};
  String field(Object? value) {
    final text = '${value ?? ''}';
    return text.contains(RegExp('[$separator"\r\n]')) ? '"${text.replaceAll('"', '""')}"' : text;
  }

  final rows = [
    [
      l10n.tripDate,
      l10n.tripFrom,
      l10n.tripTo,
      l10n.tripPurpose,
      l10n.yearDistance,
      l10n.csvUnit,
      l10n.tripVehicle,
      l10n.vehicleRates,
      l10n.tripOdometerStart,
      l10n.tripOdometerEnd,
    ],
    for (final t in yearTrips(logbook, year))
      if (vehicles[t.route.vehicleId] case final v?)
        [
          date.format(t.date),
          t.route.from,
          t.route.to,
          t.route.roundTrip ? l10n.csvRoundTrip(t.route.purpose) : t.route.purpose,
          t.route.counted.value,
          t.route.counted.unit == DistanceUnit.km ? 'km' : 'mi',
          v.archived ? l10n.tripVehicleArchived(v.name) : v.name,
          switch (v.rates) {
            RateSystem.france => l10n.vehicleRatesFrance,
            RateSystem.uk => l10n.vehicleRatesUk,
            RateSystem.us => l10n.vehicleRatesUs,
          },
          t.odometerStart,
          t.odometerEnd,
        ],
  ];
  final text = rows.map((r) => '${r.map(field).join(separator)}\r\n').join();
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]);
}
