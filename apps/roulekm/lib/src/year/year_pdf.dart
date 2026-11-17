import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../l10n/roulekm_localizations.dart';
import '../data/logbook.dart';
import '../data/totals.dart';
import '../home/home_screen.dart' show typedDistance;
import '../rates/distance.dart';
import '../rates/french_bareme.dart';
import '../rates/rates.dart';
import '../vehicles/vehicle_screen.dart' show vehicleSummary;
import 'year_csv.dart';
import 'year_screen.dart' show calculation;

/// A month of the log: its title, one row per trip (the last cell is the distance) and its total.
typedef PdfMonth = ({String title, List<List<String>> rows, (String, String) total});

/// One vehicle's year as the PDF log shows it (DAPP-141 §9), every text already in the user's language: what
/// [renderPdf] lays out, and what the tests read.
class PdfLog {
  const PdfLog({
    required this.fileName,
    required this.format,
    required this.title,
    required this.period,
    required this.identity,
    required this.columns,
    required this.months,
    required this.totalTitle,
    required this.totals,
    required this.note,
    required this.footer,
    required this.pageLabel,
  });

  final String fileName;

  /// A4, or US Letter for a US vehicle.
  final PdfPageFormat format;
  final String title;
  final String period;
  final List<(String, String)> identity;
  final List<String> columns;
  final List<PdfMonth> months;
  final String totalTitle;
  final List<(String, String)> totals;
  final String note;
  final String footer;
  final String Function(int page, int pages) pageLabel;
}

/// [year]'s log of each vehicle with trips in it, as [yearTrips] counts them, in the order of the vehicles; made
/// on [today]. French: the four mentions (date, places, purpose, distance); English: an IRS or HMRC-style log, with
/// the odometer readings.
List<PdfLog> yearPdfLogs(Logbook logbook, int year, RoulekmLocalizations l10n, DateTime today) {
  final lang = l10n.localeName;
  final trips = yearTrips(logbook, year);
  return [
    for (final v in logbook.vehicles)
      if (trips.where((t) => t.route.vehicleId == v.id).toList() case final mine when mine.isNotEmpty)
        _log(logbook, v, year, mine, l10n, lang, today),
  ];
}

PdfLog _log(
  Logbook logbook,
  VehicleRecord v,
  int year,
  List<TripRecord> trips,
  RoulekmLocalizations l10n,
  String lang,
  DateTime today,
) {
  final system = v.rates;
  final unit = system.unit;
  final number = NumberFormat.decimalPattern(lang);
  final date = DateFormat(lang == 'en' && system == RateSystem.us ? 'MM/dd/yyyy' : 'dd/MM/yyyy');
  final start = periodStart(system, year);
  final end = periodStart(system, year + 1).subtract(const Duration(days: 1));
  String longDay(DateTime d) => switch ((lang, system)) {
    ('fr', _) => DateFormat('d MMMM y', 'fr').format(d).replaceFirst(RegExp(r'^1 '), '1er '),
    (_, RateSystem.us) => DateFormat.yMMMMd('en_US').format(d),
    _ => DateFormat('d MMMM y', 'en').format(d),
  };
  String distance(int d) => typedDistance(l10n, lang, Distance(d, unit));
  final odometer = lang == 'en';

  final months = <DateTime, List<TripRecord>>{};
  for (final t in trips) {
    (months[DateTime.utc(t.date.year, t.date.month)] ??= []).add(t);
  }

  final total = yearTotals(logbook, start)[v.id]!;
  final rates = ratesFor(system, start);
  String money(int cents) => NumberFormat.simpleCurrency(
    locale: lang,
    name: switch (system) {
      RateSystem.france => 'EUR',
      RateSystem.uk => 'GBP',
      RateSystem.us => 'USD',
    },
  ).format(cents / 100);

  return PdfLog(
    // "roulekm-2026-27-golf.pdf": letters and digits, any script, joined by "-".
    fileName:
        'roulekm-${'${system.label(year)} ${v.name}'.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-')}.pdf',
    format: system == RateSystem.us ? PdfPageFormat.letter : PdfPageFormat.a4,
    title: l10n.pdfTitle(system.label(year)),
    period: l10n.pdfPeriod(longDay(start), longDay(end)),
    identity: [
      (l10n.pdfVehicle, '${v.name} — ${vehicleSummary(l10n, v)}'),
      if (rates case (:final period, year: final ratesYear, :final source))
        (
          l10n.pdfRate,
          switch (system) {
            RateSystem.france => l10n.homeSourceFrance,
            RateSystem.uk => l10n.homeSourceUk,
            RateSystem.us => l10n.homeSourceUs,
          }(system.label(ratesYear), ratesYear == period ? 'no' : 'yes', source.site),
        ),
    ],
    columns: [
      l10n.tripDate,
      l10n.tripFrom,
      l10n.tripTo,
      l10n.tripPurpose,
      if (odometer) l10n.pdfOdometer,
      l10n.pdfDistanceColumn(unit.name),
    ],
    months: [
      for (final MapEntry(key: month, value: monthTrips) in months.entries)
        (
          title: _capitalised(DateFormat.yMMMM(lang).format(month)),
          rows: [
            for (final t in monthTrips)
              [
                date.format(t.date),
                t.route.from,
                t.route.to,
                t.route.roundTrip ? l10n.csvRoundTrip(t.route.purpose) : t.route.purpose,
                if (odometer)
                  t.odometerStart != null && t.odometerEnd != null
                      ? '${number.format(t.odometerStart)} – ${number.format(t.odometerEnd)}'
                      : '—',
                number.format(totalIn(unit, [t.route.counted])),
              ],
          ],
          total: (
            l10n.pdfMonthTotal(DateFormat.MMMM(lang).format(month)),
            distance(totalIn(unit, [for (final t in monthTrips) t.route.counted])),
          ),
        ),
    ],
    totalTitle: l10n.pdfYearTotal,
    totals: [
      (l10n.pdfBusinessDistance(unit.name), l10n.yearSummary(distance(total.distance), total.trips)),
      if (total.line case final line?) ...[
        (
          line.vehicles.length > 1
              ? l10n.pdfPooledCalculation('${line.vehicles.length}')
              : _calculationLabel(l10n, number, v, rates!.year, total.distance),
          '${calculation(system, lang, line)} = ${money(line.cents)}',
        ),
        if (line.vehicles.length > 1) (l10n.pdfVehicleShare, money(total.cents!)),
      ],
    ],
    note: l10n.pdfNote(system.name),
    footer: l10n.pdfFooter(date.format(today)),
    pageLabel: (page, pages) => l10n.pdfPage('$page', '$pages'),
  );
}

/// "Calcul (tranche 5 001 à 20 000 km)" for a French vehicle with a barème; "Calculation" for the others.
String _calculationLabel(RoulekmLocalizations l10n, NumberFormat number, VehicleRecord v, int ratesYear, int km) {
  if (v.rates != RateSystem.france || v.type == VehicleType.bicycle) return l10n.yearCalculation;
  final vehicle = Vehicle(type: v.type, fiscalHorsepower: v.horsepower, electric: v.electric);
  final result = frenchAllowance(vehicle, year: ratesYear, km: km);
  if (result is! Allowance) return l10n.yearCalculation;
  final upTo = result.bracket.upToKm;
  final from = result.bracketFromKm;
  return switch ((from, upTo)) {
    (0, final to?) => l10n.pdfCalculationBracket('upTo', '', number.format(to)),
    (_, null) => l10n.pdfCalculationBracket('over', number.format(from - 1), ''),
    (_, final to?) => l10n.pdfCalculationBracket('range', number.format(from), number.format(to)),
  };
}

const _orange = PdfColor.fromInt(0xFFD9541E);
const _muted = PdfColor.fromInt(0xFF5C5C5C);
const _shade = PdfColor.fromInt(0xFFF2F0EE);
const _rule = PdfColor.fromInt(0xFFDDDDDD);

/// [log] laid out (DAPP-141 §9): 40 pt margins, black on white in Barlow ([regular] and [bold]), one orange rule under
/// the title and nothing that looks official (no logo, seal or form look: anti-goal 4). The header row repeats on
/// every page, and every page says "Page x of y".
Future<Uint8List> renderPdf(PdfLog log, {required pw.Font regular, required pw.Font bold, bool compress = true}) {
  final doc = pw.Document(
    compress: compress,
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  const small = pw.TextStyle(fontSize: 8.5);
  final strong = small.copyWith(fontWeight: pw.FontWeight.bold);
  final last = log.columns.length - 1;
  pw.Widget cell(String text, int i, {pw.TextStyle? style}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: pw.Text(text, style: style ?? small, textAlign: i == last ? pw.TextAlign.right : pw.TextAlign.left),
  );
  pw.Widget full(String text, [String end = '', PdfColor? color]) => pw.Container(
    color: color,
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(text, style: strong),
        pw.Text(end, style: strong),
      ],
    ),
  );
  pw.Widget pair((String, String) p) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(p.$1, style: const pw.TextStyle(fontSize: 9, color: _muted)),
        pw.SizedBox(width: 16),
        pw.Flexible(
          child: pw.Text(
            p.$2,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    ),
  );

  // Date, places and purpose share what the date, the odometer and the distance leave.
  final widths = <int, pw.TableColumnWidth>{
    0: const pw.FixedColumnWidth(58),
    1: const pw.FlexColumnWidth(1.2),
    2: const pw.FlexColumnWidth(1.4),
    3: const pw.FlexColumnWidth(2),
    if (last == 5) 4: const pw.FixedColumnWidth(84),
    last: const pw.FixedColumnWidth(44),
  };
  final identity = [
    pw.Wrap(
      spacing: 24,
      runSpacing: 4,
      children: [
        for (final (label, value) in log.identity)
          pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(fontSize: 9),
              children: [
                pw.TextSpan(
                  text: '$label ',
                  style: const pw.TextStyle(color: _muted),
                ),
                pw.TextSpan(text: value),
              ],
            ),
          ),
      ],
    ),
    pw.SizedBox(height: 14),
  ];

  doc.addPage(
    pw.MultiPage(
      pageFormat: log.format.copyWith(marginTop: 40, marginBottom: 40, marginLeft: 40, marginRight: 40),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(log.title, style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(log.period, style: const pw.TextStyle(fontSize: 9, color: _muted)),
                  ],
                ),
              ),
              pw.Text(log.pageLabel(context.pageNumber, context.pagesCount), style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 2, color: _orange),
          pw.SizedBox(height: 12),
          if (context.pageNumber == 1) ...identity,
          // The table's header row, here so that it repeats on every page.
          pw.Table(
            columnWidths: widths,
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.8))),
                children: [for (final (i, c) in log.columns.indexed) cell(c, i, style: strong)],
              ),
            ],
          ),
        ],
      ),
      footer: (context) => pw.Text(log.footer, style: const pw.TextStyle(fontSize: 8, color: _muted)),
      build: (context) => [
        // A month: its shaded title, its trips, its total; the trips' table can break across pages.
        for (final m in log.months) ...[
          full(m.title, '', _shade),
          pw.Table(
            columnWidths: widths,
            children: [
              for (final r in m.rows)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.5)),
                  ),
                  children: [for (final (i, c) in r.indexed) cell(c, i)],
                ),
            ],
          ),
          // The year's last total stays with the box, so a new page never starts with the box alone.
          if (m != log.months.last) full(m.total.$1, m.total.$2),
        ],
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              full(log.months.last.total.$1, log.months.last.total.$2),
              pw.SizedBox(height: 18),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(log.totalTitle, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    for (final t in log.totals) pair(t),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(log.note, style: const pw.TextStyle(fontSize: 8, color: _muted)),
            ],
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

String _capitalised(String s) => '${s[0].toUpperCase()}${s.substring(1)}';
