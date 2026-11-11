import 'package:app_kit/app_kit.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/roulekm_localizations.dart';
import '../data/log_controller.dart';
import '../data/logbook.dart';
import '../data/totals.dart';
import '../rates/distance.dart';
import '../rates/rates.dart';
import '../vehicles/vehicle_screen.dart';
import '../vehicles/vehicles_screen.dart';

const _tabular = [FontFeature.tabularFigures()];

/// The first screen (DAPP-141 §1): per rate system in use, the year's total and one card per vehicle in use (amount
/// and distance); then the big "+ trajet" button.
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

  /// The total line and the cards of the vehicles in use counted at [system].
  List<Widget> _system(BuildContext context, RateSystem system, Logbook logbook, DateTime today) {
    final l10n = RoulekmLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final totals = vehicleTotals(logbook, today);
    final vehicles = [...log.inUse.where((v) => v.rates == system)];
    final year = _periodLabel(system, today);
    final sum = _money(system, lang, vehicles.fold(0, (a, v) => a + (totals[v.id]!.cents ?? 0)));
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
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => VehicleScreen(log: log, vehicle: v),
            ),
          ),
        ),
    ];
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
  const _VehicleCard({required this.vehicle, required this.total, required this.onTap});

  final VehicleRecord vehicle;
  final VehicleTotal total;
  final VoidCallback onTap;

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
            ],
          ),
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
