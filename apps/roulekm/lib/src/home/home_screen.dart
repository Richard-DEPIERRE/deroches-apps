import 'package:app_kit/app_kit.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/roulekm_localizations.dart';
import '../data/log_controller.dart';
import '../data/logbook.dart';
import '../data/totals.dart';
import '../rates/distance.dart';
import '../rates/french_bareme.dart';
import '../rates/rates.dart';
import '../sources/sources_screen.dart';
import '../trips/trip_screen.dart';
import '../vehicles/vehicle_screen.dart';
import '../vehicles/vehicles_screen.dart';

const _tabular = [FontFeature.tabularFigures()];

/// The rows' trailing icon and distance end on the same 16 dp edge as the cards (Material 3's default is 24).
const _rowPadding = EdgeInsets.symmetric(horizontal: 16);

/// The first screen (DAPP-141 §1): per rate system in use, the year's total, one card per vehicle in use (amount,
/// distance, bracket and its rule) and the rates' source; then the big "+ trajet" button, the favourites and the last
/// three trips.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.log,
    required this.settings,
    this.tripSaved,
    this.editFavourites,
    this.openYear,
    this.now = DateTime.now,
  });

  final LogController log;
  final WidgetBuilder settings;

  /// Runs after each trip saved: the first one is the app's first useful moment (`markFirstValue()`).
  final Future<void> Function()? tripSaved;

  /// "Gérer" beside the favourites, and "Tout voir" beside the recent trips (the Year screen, DAPP-147): hidden until
  /// their screens exist.
  final VoidCallback? editFavourites;
  final VoidCallback? openYear;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: log,
    builder: (context, _) {
      final l10n = RoulekmLocalizations.of(context);
      final logbook = log.logbook;
      final today = now();
      final inUse = log.inUse;
      final systems = {for (final v in inUse) v.rates};
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _periodLabel(systems.firstOrNull ?? RateSystem.france, today),
            style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: _tabular),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: KitLocalizations.of(context).settingsTitle,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: settings)),
            ),
          ],
        ),
        body: logbook == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 16),
                children: [
                  if (inUse.isEmpty) _NoVehicle(log: log),
                  for (final (i, system) in systems.indexed) ..._system(context, system, logbook, today, first: i == 0),
                  _AddTripButton(
                    onPressed: () => openTripScreen(context, log, tripSaved: tripSaved, now: now),
                    label: l10n.homeAddTrip,
                    semantics: l10n.homeAddTripLabel,
                  ),
                  if (logbook.favourites.isNotEmpty) ...[
                    _Header(
                      l10n.homeFavourites(systems.firstOrNull == RateSystem.uk ? 'yes' : 'no'),
                      l10n.homeFavouritesEdit,
                      editFavourites,
                    ),
                    // Tap = the quick-add sheet (DAPP-146).
                    for (final f in logbook.favourites) _FavouriteRow(f.route),
                  ],
                  if (logbook.trips.isNotEmpty) ...[
                    _Header(l10n.homeRecent, l10n.homeSeeAll, openYear),
                    for (final t in logbook.latestFirst.take(3)) _TripRow(t, logbook.vehicles),
                  ],
                ],
              ),
      );
    },
  );

  /// The total line, the cards and the source line of the vehicles in use counted at [system].
  List<Widget> _system(
    BuildContext context,
    RateSystem system,
    Logbook logbook,
    DateTime today, {
    required bool first,
  }) {
    final l10n = RoulekmLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final totals = vehicleTotals(logbook, today);
    final vehicles = [...log.inUse.where((v) => v.rates == system)];
    final rates = ratesFor(system, today);
    final year = _periodLabel(system, today);
    final sum = _money(system, lang, vehicles.fold(0, (a, v) => a + (totals[v.id]!.cents ?? 0)));
    final note = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return [
      Padding(
        // Lined up with the card edge; a later group starts well clear of the one above.
        padding: EdgeInsets.fromLTRB(16, first ? 4 : 24, 16, 6),
        child: Text(
          switch (system) {
            RateSystem.france => l10n.homeTotalFrance(year, sum),
            RateSystem.uk => l10n.homeTotalUk(year, sum),
            RateSystem.us => l10n.homeTotalUs(year, sum),
          },
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: _tabular,
          ),
        ),
      ),
      for (final v in vehicles)
        _VehicleCard(
          vehicle: v,
          total: totals[v.id]!,
          rule: vehicleRule(v, logbook, totals, today),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => VehicleScreen(log: log, vehicle: v),
            ),
          ),
        ),
      if (rates != null)
        // Opens a screen in the app: a button for screen readers.
        Semantics(
          button: true,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SourcesScreen(log: log, now: now),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: _iconSize(context, 1)),
                    child: Icon(
                      Icons.info_outline,
                      size: _iconSize(context, 16),
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_source(l10n, system, rates), style: note)),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  static String _source(
    RoulekmLocalizations l10n,
    RateSystem system,
    ({int period, int year, BaremeSource source}) rates,
  ) {
    final year = system.label(rates.year);
    final latest = rates.year == rates.period ? 'no' : 'yes';
    final site = rates.source.site;
    return switch (system) {
      RateSystem.france => l10n.homeSourceFrance(year, latest, site),
      RateSystem.uk => l10n.homeSourceUk(year, latest, site),
      RateSystem.us => l10n.homeSourceUs(year, latest, site),
    };
  }
}

String _periodLabel(RateSystem system, DateTime now) => system.label(system.periodOf(now));

/// Whole euros, pounds or dollars, as on every screen (cents only in the PDF).
String _money(RateSystem system, String lang, int cents) => NumberFormat.simpleCurrency(
  locale: lang,
  name: switch (system) {
    RateSystem.france => 'EUR',
    RateSystem.uk => 'GBP',
    RateSystem.us => 'USD',
  },
  decimalDigits: 0,
).format((cents + 50) ~/ 100);

/// An icon beside text grows with it, up to the same 1.5× as the amount.
double _iconSize(BuildContext context, double size) =>
    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5).scale(size);

String _number(String lang, num n) => NumberFormat.decimalPattern(lang).format(n);

String _distance(RoulekmLocalizations l10n, RateSystem system, String lang, int d) =>
    typedDistance(l10n, lang, Distance(d, system.unit));

/// A distance in the unit it was typed in.
String typedDistance(RoulekmLocalizations l10n, String lang, Distance d) =>
    d.unit == DistanceUnit.km ? l10n.distanceKm(_number(lang, d.value)) : l10n.distanceMiles(_number(lang, d.value));

/// "Mer. 5 nov.", "Wed, Nov 5", and "Wed 5 Nov" for an HMRC vehicle; never broken across lines.
String _day(String lang, RateSystem? system, DateTime day) {
  final text = switch (lang) {
    'fr' => DateFormat.MMMEd('fr').format(day),
    _ when system == RateSystem.uk => DateFormat('EEE d MMM', 'en').format(day),
    _ => DateFormat.MMMEd('en').format(day),
  };
  return '${text[0].toUpperCase()}${text.substring(1)}'.replaceAll(' ', '\u00a0');
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.total, required this.rule, required this.onTap});

  final VehicleRecord vehicle;
  final VehicleTotal total;
  final VehicleRule? rule;
  final VoidCallback onTap;

  String _rule(RoulekmLocalizations l10n, String lang, VehicleRule rule) {
    final system = vehicle.rates;
    switch (system) {
      case RateSystem.france:
        final rate = NumberFormat.decimalPatternDigits(locale: lang, decimalDigits: 3).format(rule.rateMilli / 1000);
        final range = switch (rule.index) {
          0 => l10n.homeRangeUpTo(_distance(l10n, system, lang, rule.limits.first)),
          final i when i == rule.limits.length => l10n.homeRangeOver(_distance(l10n, system, lang, rule.limits.last)),
          final i =>
            '${_number(lang, rule.limits[i - 1] + 1)}\u00a0–\u00a0${_distance(l10n, system, lang, rule.limits[i])}',
        };
        final fixed = _money(system, lang, rule.fixedEuros * 100);
        return l10n.homeRuleFrance(
          range,
          rule.fixedEuros == 0 ? 'd\u00a0×\u00a0$rate' : '(d\u00a0×\u00a0$rate)\u00a0+\u00a0$fixed',
        );
      case RateSystem.uk:
        final pence = rule.rateMilli ~/ 10;
        if (rule.limits.isEmpty) return l10n.homeRuleUkFlat(pence);
        return rule.index == 0 ? l10n.homeRuleUkFirst(pence) : l10n.homeRuleUkAbove(pence);
      case RateSystem.us:
        return l10n.homeRuleUs(_number(lang, rule.rateMilli / 10));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = RoulekmLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontFeatures: _tabular);
    final distance = _distance(l10n, vehicle.rates, lang, total.distance);
    return Card.filled(
      color: scheme.surfaceContainer,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(vehicleIcon(vehicle.type), size: _iconSize(context, 20), color: scheme.onSurfaceVariant),
                  Text(vehicle.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  if (vehicle.rates == RateSystem.france && vehicle.horsepower != null)
                    Text(l10n.vehicleHorsepowerOne(vehicle.horsepower!), style: muted),
                  if (vehicle.rates == RateSystem.france && vehicle.electric) _ElectricTag(l10n.homeElectric),
                ],
              ),
              if (total.cents case final cents?) ...[
                const SizedBox(height: 8),
                // Already large: grows with the text size up to 1.5× only.
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.5,
                  child: Text(
                    _money(vehicle.rates, lang, cents),
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w600,
                      height: 1.05,
                      letterSpacing: -0.5,
                      fontFeatures: _tabular,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                vehicle.rates == RateSystem.uk ? l10n.homeThisTaxYear(distance) : l10n.homeThisYear(distance),
                style: muted,
              ),
              if (rule case final rule?) ...[
                const SizedBox(height: 12),
                if (rule.limits.isNotEmpty) ...[_BracketBar(rule, lang), const SizedBox(height: 8)],
                Text(
                  _rule(l10n, lang, rule),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontFeatures: _tabular),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Equal-width segments, the ones before the year's full and its own filled to where the year sits. Above 1.3× text
/// the labels hide: the rule line under it already names the bracket.
class _BracketBar extends StatelessWidget {
  const _BracketBar(this.rule, this.lang);

  final VehicleRule rule;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontFeatures: _tabular);
    final limits = rule.limits;
    final labels = [
      for (var i = 0; i <= limits.length; i++)
        i == limits.length
            ? '+ ${_number(lang, limits.last)}'
            : '${_number(lang, i == 0 ? 0 : limits[i - 1] + 1)} – ${_number(lang, limits[i])}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: i < rule.index ? scheme.primary : scheme.surfaceContainerHighest),
                        if (i == rule.index)
                          FractionallySizedBox(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: rule.fill,
                            child: ColoredBox(color: scheme.primary),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (MediaQuery.textScalerOf(context).scale(1) <= 1.3) ...[
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: i == rule.index
                          ? small?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600)
                          : small,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ElectricTag extends StatelessWidget {
  const _ElectricTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, size: _iconSize(context, 14), color: scheme.onTertiaryContainer),
            Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onTertiaryContainer)),
          ],
        ),
      ),
    );
  }
}

/// After "Later" in onboarding: one card in place of the vehicles' (DAPP-141 §6).
class _NoVehicle extends StatelessWidget {
  const _NoVehicle({required this.log});

  final LogController log;

  @override
  Widget build(BuildContext context) {
    final l10n = RoulekmLocalizations.of(context);
    final theme = Theme.of(context);
    return Card.filled(
      color: theme.colorScheme.surfaceContainer,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.homeNoVehicle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VehicleScreen(log: log))),
              child: Text(l10n.onboardingDone),
            ),
          ],
        ),
      ),
    );
  }
}

/// A section's title (as the settings' section headers), and its text button lined up with the screen edge (−12 dp).
class _Header extends StatelessWidget {
  const _Header(this.title, this.action, this.onPressed);

  final String title;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
            ),
          ),
          // Hidden until its screen exists. No 64 dp minimum width, and the same 12 dp padding at any text size: a
          // short label ("Edit") ends on the rows' 16 dp edge.
          if (onPressed != null)
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size.square(48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: onPressed,
              child: Text(action),
            )
          else
            const SizedBox(height: 48),
        ],
      ),
    );
  }
}

/// "Domicile → Chantier Bron": the arrow is an icon (Barlow has no glyph for U+2192), read "Domicile vers Chantier
/// Bron".
class _Route extends StatelessWidget {
  const _Route(this.route);

  final TripRoute route;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    return Semantics(
      label: RoulekmLocalizations.of(context).homeRoute(route.from, route.to),
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            // A word joiner keeps the arrow with the place before it: a line never starts with it.
            TextSpan(text: '${route.from}\u2060'),
            // Grows with the text, as a WidgetSpan does.
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.arrow_forward, size: (style.fontSize ?? 16) * 0.9, color: style.color),
              ),
            ),
            TextSpan(text: route.to),
          ],
        ),
      ),
    );
  }
}

class _FavouriteRow extends StatelessWidget {
  const _FavouriteRow(this.route);

  final TripRoute route;

  @override
  Widget build(BuildContext context) {
    final l10n = RoulekmLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final distance = typedDistance(l10n, Localizations.localeOf(context).languageCode, route.distance);
    return MergeSemantics(
      child: ListTile(
        contentPadding: _rowPadding,
        titleAlignment: ListTileTitleAlignment.titleHeight,
        leading: Icon(Icons.star, color: scheme.primary, size: _iconSize(context, 22)),
        title: _Route(route),
        subtitle: Text(route.roundTrip ? l10n.homeRoundTrip(distance) : distance),
        trailing: Icon(Icons.add_circle_outline, color: scheme.primary, size: _iconSize(context, 22)),
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow(this.trip, this.vehicles);

  final TripRecord trip;
  final List<VehicleRecord> vehicles;

  @override
  Widget build(BuildContext context) {
    final l10n = RoulekmLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final vehicle = vehicles.where((v) => v.id == trip.route.vehicleId).firstOrNull;
    return MergeSemantics(
      child: ListTile(
        contentPadding: _rowPadding,
        titleAlignment: ListTileTitleAlignment.titleHeight,
        title: _Route(trip.route),
        subtitle: Text(
          [
            _day(lang, vehicle?.rates, trip.date),
            ?vehicle?.name,
            trip.route.purpose,
          ].where((s) => s.isNotEmpty).join('\u00a0· '),
        ),
        trailing: Text(
          typedDistance(l10n, lang, trip.route.counted),
          style: theme.textTheme.bodyMedium?.copyWith(fontFeatures: _tabular),
        ),
      ),
    );
  }
}

class _AddTripButton extends StatelessWidget {
  const _AddTripButton({required this.onPressed, required this.label, required this.semantics});

  final VoidCallback? onPressed;
  final String label;
  final String semantics;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Semantics(
      label: semantics,
      button: true,
      excludeSemantics: true,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(64),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
        icon: Icon(Icons.add, size: _iconSize(context, 28)),
        label: Text(label),
      ),
    ),
  );
}
