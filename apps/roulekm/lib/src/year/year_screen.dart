import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/roulekm_localizations.dart';
import '../data/log_controller.dart';
import '../data/logbook.dart';
import '../data/totals.dart';
import '../home/home_screen.dart';
import '../rates/distance.dart';
import '../rates/rates.dart';
import '../sources/sources_screen.dart' show readOnDate;
import '../trips/trip_screen.dart';
import '../vehicles/vehicles_screen.dart';

const _tabular = [FontFeature.tabularFigures()];

/// The Year screen (DAPP-141 §7), free for every year: the year's total, one card per vehicle (distance, calculation,
/// amount), the dated source, then the year's trips by month (tap to edit). The year picker is its title.
class YearScreen extends StatefulWidget {
  const YearScreen({super.key, required this.log, this.now = DateTime.now});

  final LogController log;
  final DateTime Function() now;

  @override
  State<YearScreen> createState() => _YearScreenState();
}

class _YearScreenState extends State<YearScreen> {
  int? _year;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.log,
    builder: (context, _) {
      final l10n = RoulekmLocalizations.of(context);
      final theme = Theme.of(context);
      final lang = Localizations.localeOf(context).languageCode;
      final logbook = widget.log.logbook;
      if (logbook == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final years = yearsOf(logbook, widget.now());
      final year = _year ?? years.first;
      final systemOf = {for (final v in logbook.vehicles) v.id: v.rates};
      bool inYear(TripRecord t) => systemOf[t.route.vehicleId]?.periodOf(t.date) == year;
      final trips = logbook.latestFirst.where(inYear).toList();
      final shown = {
        for (final v in logbook.vehicles)
          if (!v.archived || trips.any((t) => t.route.vehicleId == v.id)) v,
      };
      final systems = {for (final v in shown) v.rates};
      String title(int y) => l10n.yearTitle(
        systems.firstOrNull == RateSystem.uk ? 'yes' : 'no',
        (systems.firstOrNull ?? RateSystem.france).label(y),
      );
      final months = <DateTime, List<TripRecord>>{};
      for (final t in trips) {
        (months[DateTime.utc(t.date.year, t.date.month)] ??= []).add(t);
      }
      return Scaffold(
        appBar: AppBar(
          // AppBar caps its title at 1.34× text; where "Année fiscale 2026–27 ▾" still doesn't fit (360 dp), the year
          // shrinks to fit rather than lose its end.
          title: Builder(
            builder: (context) {
              final text = FittedBox(fit: BoxFit.scaleDown, child: Text(title(year)));
              if (years.length < 2) return text;
              return PopupMenuButton<int>(
                tooltip: l10n.yearPick,
                initialValue: year,
                position: PopupMenuPosition.under,
                onSelected: (y) => setState(() => _year = y),
                itemBuilder: (_) => [
                  for (final y in years)
                    PopupMenuItem(value: y, child: Text((systems.firstOrNull ?? RateSystem.france).label(y))),
                ],
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: text),
                      // Grows with the title's text.
                      Icon(Icons.arrow_drop_down, size: MediaQuery.textScalerOf(context).scale(24)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        body: ListView(
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 16),
          children: [
            for (final system in systems)
              ..._system(context, system, year, logbook, [...shown.where((v) => v.rates == system)]),
            for (final MapEntry(key: month, value: monthTrips) in months.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                child: Semantics(
                  header: true,
                  child: Text(
                    _capitalised(DateFormat.yMMMM(lang).format(month)),
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
              ),
              for (final t in monthTrips)
                TripRow(t, logbook.vehicles, () => openTripScreen(context, widget.log, trip: t, now: widget.now)),
            ],
          ],
        ),
      );
    },
  );

  /// The year's total of [vehicles] (all counted at [system]), their cards and the rates' dated source.
  List<Widget> _system(
    BuildContext context,
    RateSystem system,
    int year,
    Logbook logbook,
    List<VehicleRecord> vehicles,
  ) {
    final l10n = RoulekmLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final totals = yearTotals(logbook, periodStart(system, year));
    final rates = ratesFor(system, periodStart(system, year));
    final distance = vehicles.fold(0, (a, v) => a + totals[v.id]!.distance);
    final count = vehicles.fold(0, (a, v) => a + totals[v.id]!.trips);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontFeatures: _tabular);
    final source = switch (rates) {
      null => null,
      (:final period, year: final ratesYear, :final source) => () {
        final latest = ratesYear == period ? 'no' : 'yes';
        final label = system.label(ratesYear);
        final date = readOnDate(system, lang, source);
        return switch (system) {
          RateSystem.france => [
            l10n.yearSourceFrance(label, latest, source.site, date),
            if (latest == 'yes') l10n.sourcesNextYear('$period', '${period + 1}'),
          ].join(' '),
          RateSystem.uk => l10n.yearSourceUk(label, latest, source.site, date),
          RateSystem.us => l10n.yearSourceUs(label, latest, source.site, date),
        };
      }(),
    };
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rates != null)
              // Already large: grows with the text size up to 1.5× only.
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.5,
                child: Text(
                  _money(system, lang, vehicles.fold(0, (a, v) => a + (totals[v.id]!.cents ?? 0))),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                    letterSpacing: -0.5,
                    fontFeatures: _tabular,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            Text(l10n.yearSummary(_distance(l10n, system, lang, distance), count), style: muted),
          ],
        ),
      ),
      for (final v in vehicles) _VehicleYear(vehicle: v, total: totals[v.id]!),
      if (source != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Text(source, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ),
    ];
  }
}

/// A vehicle's year: Distance, Calcul (when the line is its own), Montant in bold; label over value above 1.3× text.
class _VehicleYear extends StatelessWidget {
  const _VehicleYear({required this.vehicle, required this.total});

  final VehicleRecord vehicle;
  final YearTotal total;

  @override
  Widget build(BuildContext context) {
    final l10n = RoulekmLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final label = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final value = theme.textTheme.bodyMedium?.copyWith(fontFeatures: _tabular);
    Widget row(String name, String text, {bool bold = false}) {
      final style = bold ? value?.copyWith(fontWeight: FontWeight.w600) : value;
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: MergeSemantics(
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: label),
                    Text(text, style: style),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: label),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(text, style: style, textAlign: TextAlign.end),
                    ),
                  ],
                ),
        ),
      );
    }

    final line = total.line;
    return Card.filled(
      color: scheme.surfaceContainer,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  vehicleIcon(vehicle.type),
                  size: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5).scale(20),
                  color: scheme.onSurfaceVariant,
                ),
                Text(
                  vehicle.archived ? l10n.tripVehicleArchived(vehicle.name) : vehicle.name,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            row(l10n.yearDistance, _distance(l10n, vehicle.rates, lang, total.distance)),
            // A line shared with other vehicles (UK cars, the US) is the pool's: its amount here is a share of it.
            if (line != null && line.vehicles.length == 1)
              row(l10n.yearCalculation, calculation(vehicle.rates, lang, line)),
            if (total.cents case final cents?) row(l10n.yearAmount, _money(vehicle.rates, lang, cents), bold: true),
          ],
        ),
      ),
    );
  }
}

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

/// Whole euros, pounds or dollars, as on every screen.
String _money(RateSystem system, String lang, int cents) => NumberFormat.simpleCurrency(
  locale: lang,
  name: switch (system) {
    RateSystem.france => 'EUR',
    RateSystem.uk => 'GBP',
    RateSystem.us => 'USD',
  },
  decimalDigits: 0,
).format((cents + 50) ~/ 100);

String _distance(RoulekmLocalizations l10n, RateSystem system, String lang, int d) =>
    typedDistance(l10n, lang, Distance(d, system.unit));

String _capitalised(String s) => '${s[0].toUpperCase()}${s.substring(1)}';
