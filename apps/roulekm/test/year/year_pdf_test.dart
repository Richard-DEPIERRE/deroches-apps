import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:roulekm/l10n/roulekm_localizations.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/rates/distance.dart';
import 'package:roulekm/src/rates/french_bareme.dart' show VehicleType;
import 'package:roulekm/src/rates/rates.dart';
import 'package:roulekm/src/year/year_pdf.dart';

import '../home/home_screen_test.dart' show civic, clio, golf;
import 'year_csv_test.dart' show trip;

const polo = VehicleRecord(id: 'p', name: 'Polo', rates: RateSystem.uk, type: VehicleType.car);
const kangoo = VehicleRecord(id: 'k', name: 'Kangoo', rates: RateSystem.france, type: VehicleType.car, horsepower: 4);

/// The text with its no-break spaces as plain ones, so expectations read as on paper.
String plain(String s) => s.replaceAll(RegExp('[\u00a0\u202f]'), ' ');

List<String> plainAll(Iterable<String> l) => [for (final s in l) plain(s)];

/// The made-up log's rows, totals and labels, as plain text.
Map<String, Object> read(PdfLog log) => {
  'file': log.fileName,
  'title': plain(log.title),
  'period': plain(log.period),
  'identity': [for (final (l, v) in log.identity) '${plain(l)} ${plain(v)}'],
  'columns': log.columns,
  'months': [
    for (final m in log.months)
      [
        plain(m.title),
        for (final r in m.rows) plainAll(r).join(' | '),
        plainAll([m.total.$1, m.total.$2]).join(' | '),
      ],
  ],
  'totalTitle': plain(log.totalTitle),
  'totals': [for (final (l, v) in log.totals) '${plain(l)}: ${plain(v)}'],
  'note': plain(log.note),
  'footer': plain(log.footer),
  'page': plain(log.pageLabel(2, 4)),
};

void main() {
  setUpAll(initializeDateFormatting);
  final fr = lookupRoulekmLocalizations(const Locale('fr'));
  final en = lookupRoulekmLocalizations(const Locale('en'));
  final today = DateTime(2027, 1, 5);

  test('in French: one A4 log per vehicle with trips that year, the four mentions, months, bracket and calculation', () {
    final logbook = Logbook(
      vehicles: const [clio, kangoo],
      trips: [
        trip(
          'a',
          'c',
          DateTime.utc(2026, 3, 3),
          'Domicile',
          'Chantier Bron',
          'Suivi de chantier',
          34,
          DistanceUnit.km,
          roundTrip: true,
        ),
        trip('b', 'c', DateTime.utc(2026, 3, 5), 'Agence', 'Fournisseur', 'Achat matériel', 18, DistanceUnit.km),
        trip('c', 'c', DateTime.utc(2026, 12, 7), 'Domicile', 'Client', 'Rendez-vous', 6000, DistanceUnit.km),
        trip('d', 'c', DateTime.utc(2025, 12, 31), 'X', 'Y', 'Hors année', 50, DistanceUnit.km),
        trip('e', 'k', DateTime.utc(2025, 6, 1), 'X', 'Y', 'Hors année', 50, DistanceUnit.km),
      ],
    );
    final logs = yearPdfLogs(logbook, 2026, fr, today);
    expect(logs, hasLength(1));
    expect(logs.single.format, PdfPageFormat.a4);
    expect(read(logs.single), {
      'file': 'roulekm-2026-clio.pdf',
      'title': 'Relevé des frais kilométriques 2026',
      'period': 'Déplacements professionnels — du 1er janvier 2026 au 31 décembre 2026',
      'identity': [
        'Véhicule : Clio — Voiture · 5 CV · thermique',
        'Barème : Barème kilométrique 2025, le dernier publié · source : impots.gouv.fr',
      ],
      'columns': ['Date', 'Départ', 'Arrivée', 'Motif', 'Km'],
      'months': [
        [
          'Mars 2026',
          '03/03/2026 | Domicile | Chantier Bron | Suivi de chantier (A/R) | 68',
          '05/03/2026 | Agence | Fournisseur | Achat matériel | 18',
          'Total mars | 86 km',
        ],
        ['Décembre 2026', '07/12/2026 | Domicile | Client | Rendez-vous | 6 000', 'Total décembre | 6 000 km'],
      ],
      'totalTitle': 'Total de l’année',
      'totals': [
        'Distance professionnelle: 6 086 km · 3 trajets',
        'Calcul (tranche 5 001 à 20 000 km): (6 086 × 0,357) + 1 395 = 3 567,70 €',
      ],
      'note':
          'Chaque trajet indique sa date, ses lieux de départ et d’arrivée, son motif et sa distance. Montants au barème '
          'kilométrique publié par l’administration fiscale ; à conserver avec vos justificatifs.',
      'footer': 'Établi avec Roulekm le 05/01/2027',
      'page': 'Page 2 sur 4',
    });
  });

  test('in English, a US vehicle: Letter, US dates, the odometer column and the year\'s two IRS rates', () {
    final logbook = Logbook(
      vehicles: const [civic],
      trips: [
        trip(
          'a',
          'u',
          DateTime.utc(2026, 3, 12),
          'Home',
          'Job site',
          'Site visit',
          21,
          DistanceUnit.mile,
          roundTrip: true,
          start: 32580,
          end: 32622,
        ),
        trip('b', 'u', DateTime.utc(2026, 8, 4), 'Office', 'Supplier', 'Pick up materials', 11, DistanceUnit.mile),
      ],
    );
    final log = yearPdfLogs(logbook, 2026, en, today).single;
    expect(log.format, PdfPageFormat.letter);
    expect(read(log), {
      'file': 'roulekm-2026-civic.pdf',
      'title': 'Mileage log 2026',
      'period': 'Business trips — January 1, 2026 to December 31, 2026',
      'identity': [
        'Vehicle: Civic — Car or van · IRS standard rate',
        'Rate: IRS standard mileage rate for 2026 · source: irs.gov',
      ],
      'columns': ['Date', 'From', 'To', 'Business purpose', 'Odometer', 'Miles'],
      'months': [
        [
          'March 2026',
          '03/12/2026 | Home | Job site | Site visit (round trip) | 32,580 – 32,622 | 42',
          'March total | 42 mi',
        ],
        ['August 2026', '08/04/2026 | Office | Supplier | Pick up materials | — | 11', 'August total | 11 mi'],
      ],
      'totalTitle': 'Year total',
      'totals': ['Business miles: 53 mi · 2 trips', 'Calculation: 42 × \$0.725 + 11 × \$0.76 = \$38.81'],
      'note':
          'Each trip shows its date, places, business purpose and miles. Amounts at the IRS standard mileage rate. Keep '
          'this log with your tax records.',
      'footer': 'Made with Roulekm on 01/05/2027',
      'page': 'Page 2 of 4',
    });
  });

  test('in English, two UK cars: A4, the tax year, the pooled calculation and each car\'s share', () {
    final logbook = Logbook(
      vehicles: const [golf, polo],
      trips: [
        trip('a', 'g', DateTime.utc(2026, 5, 1), 'Home', 'Depot', 'Delivery', 8000, DistanceUnit.mile),
        trip('b', 'p', DateTime.utc(2027, 4, 5), 'Home', 'Depot', 'Delivery', 4000, DistanceUnit.mile),
        trip('c', 'p', DateTime.utc(2027, 4, 6), 'Home', 'Depot', 'Next tax year', 10, DistanceUnit.mile),
      ],
    );
    final logs = yearPdfLogs(logbook, 2026, en, today);
    expect([for (final l in logs) l.fileName], ['roulekm-2026-27-golf.pdf', 'roulekm-2026-27-polo.pdf']);
    expect(logs.first.format, PdfPageFormat.a4);
    final golfLog = read(logs.first);
    expect(golfLog['title'], 'Mileage log 2026–27');
    expect(golfLog['period'], 'Business trips — 6 April 2026 to 5 April 2027');
    expect((golfLog['months']! as List).single, [
      'May 2026',
      '01/05/2026 | Home | Depot | Delivery | — | 8,000',
      'May total | 8,000 mi',
    ]);
    expect(golfLog['totals'], [
      'Business miles: 8,000 mi · 1 trip',
      'Calculation, 2 vehicles together: 10,000 × 55p + 2,000 × 25p = £6,000.00',
      'This vehicle’s share, by distance: £4,000.00',
    ]);
    expect(golfLog['note'], contains('Amounts at HMRC’s approved mileage rates.'));
    expect(golfLog['footer'], 'Made with Roulekm on 05/01/2027');
  });

  test('no trips that year: no log', () {
    expect(yearPdfLogs(const Logbook(vehicles: [clio]), 2026, fr, today), isEmpty);
  });

  test('rendered: a PDF on the log\'s paper, one page per ~30 trips, in Barlow', () async {
    pw.Font font(String weight) =>
        pw.Font.ttf(File('assets/fonts/Barlow-$weight.ttf').readAsBytesSync().buffer.asByteData());
    final logbook = Logbook(
      vehicles: const [clio],
      trips: [
        for (var i = 0; i < 120; i++)
          trip(
            '$i',
            'c',
            DateTime.utc(2026, 1 + i % 12, 1 + i % 28),
            'Domicile',
            'Client $i',
            'Visite',
            20,
            DistanceUnit.km,
          ),
      ],
    );
    final log = yearPdfLogs(logbook, 2026, fr, today).single;
    final bytes = await renderPdf(log, regular: font('Regular'), bold: font('SemiBold'), compress: false);
    final text = latin1.decode(bytes);
    expect(text, startsWith('%PDF'));
    final pages = RegExp(r'/Type/Page\b').allMatches(text).length;
    expect(pages, inInclusiveRange(4, 7));
    expect(text, contains('/MediaBox[0 0 595.27559 841.88976]'));
    expect(text, contains('/BaseFont/Barlow-Regular'));
  });
}
