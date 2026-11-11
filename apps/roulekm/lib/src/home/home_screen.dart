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
import '../vehicles/vehicle_screen.dart';
import '../vehicles/vehicles_screen.dart';

const _tabular = [FontFeature.tabularFigures()];

/// The first screen (DAPP-141 §1): per rate system in use, the year's total, one card per vehicle in use (amount,
/// distance, bracket and its rule) and the rates' source; then the big "+ trajet" button.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.log, required this.settings, this.addTrip, this.now = DateTime.now});

  final LogController log;
  final WidgetBuilder settings;

  /// Opens "Add a trip" (DAPP-146); the button is off until then.
  final VoidCallback? addTrip;
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
                  for (final system in systems) ..._system(context, system, logbook, today),
                  _AddTripButton(onPressed: addTrip, label: l10n.homeAddTrip, semantics: l10n.homeAddTripLabel),
                ],
              ),
      );
    },
  );

  /// The total line, the cards and the source line of the vehicles in use counted at [system].
  List<Widget> _system(BuildContext context, RateSystem system, Logbook logbook, DateTime today) {
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
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(_source(l10n, system, rates), style: note)),
            ],
          ),
        ),
    ];
  }

  static String _source(
    RoulekmLocalizations l10n,
    RateSystem system,
    ({int period, int year, BaremeSource source}) rates,
  ) {
    final year = _yearLabel(system, rates.year);
    final latest = rates.year == rates.period ? 'no' : 'yes';
    final site = Uri.parse(rates.source.url).host.replaceFirst(RegExp(r'^www\d*\.'), '');
    return switch (system) {
      RateSystem.france => l10n.homeSourceFrance(year, latest, site),
      RateSystem.uk => l10n.homeSourceUk(year, latest, site),
      RateSystem.us => l10n.homeSourceUs(year, latest, site),
    };
  }
}

/// "2026", or the UK's tax year "2026–27".
String _yearLabel(RateSystem system, int year) =>
    system == RateSystem.uk ? '$year–${'${(year + 1) % 100}'.padLeft(2, '0')}' : '$year';

String _periodLabel(RateSystem system, DateTime now) => _yearLabel(system, system.periodOf(now));

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

String _number(String lang, num n) => NumberFormat.decimalPattern(lang).format(n);

String _distance(RoulekmLocalizations l10n, RateSystem system, String lang, int d) =>
    system.unit == DistanceUnit.km ? l10n.distanceKm(_number(lang, d)) : l10n.distanceMiles(_number(lang, d));

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
          final i => '${_number(lang, rule.limits[i - 1] + 1)} – ${_distance(l10n, system, lang, rule.limits[i])}',
        };
        final fixed = _money(system, lang, rule.fixedEuros * 100);
        return l10n.homeRuleFrance(
          range,
          rule.fixedEuros == 0 ? 'd\u00a0×\u00a0$rate' : '(d\u00a0×\u00a0$rate) + $fixed',
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
                  Icon(vehicleIcon(vehicle.type), size: 20, color: scheme.onSurfaceVariant),
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
            Icon(Icons.bolt, size: 14, color: scheme.onTertiaryContainer),
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
        icon: const Icon(Icons.add, size: 28),
        label: Text(label),
      ),
    ),
  );
}
