import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/roulekm_localizations.dart';
import '../data/log_controller.dart';
import '../data/logbook.dart';
import '../data/totals.dart';
import '../pro.dart';
import '../rates/distance.dart';
import '../rates/french_bareme.dart';
import '../rates/rates.dart';
import 'vehicle_screen.dart';

IconData vehicleIcon(VehicleType type) => switch (type) {
  VehicleType.car => Icons.directions_car_outlined,
  VehicleType.motorbike => Icons.two_wheeler,
  VehicleType.moped => Icons.moped_outlined,
  VehicleType.bicycle => Icons.pedal_bike,
};

/// The vehicles in use with their year so far, the add button, then the archived ones (DAPP-141 §5). A vehicle added
/// or put back in use while another is in use is Pro (`second_vehicle`).
class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({
    super.key,
    required this.log,
    required this.pro,
    required this.openPaywall,
    this.now = DateTime.now,
  });

  final LogController log;

  /// Whether Pro is owned.
  final ValueListenable<bool> pro;
  final OpenPaywall? openPaywall;
  final DateTime Function() now;

  /// Runs [action] at once while no vehicle is in use; otherwise only once the Pro action allows it.
  Future<void> _addInUse(BuildContext context, Future<void> Function() action) async {
    if (log.inUse.isNotEmpty) {
      final allowed = await proAction(
        context,
        placement: 'second_vehicle',
        pro: pro.value,
        tripSaved: log.logbook!.trips.isNotEmpty,
        openPaywall: openPaywall,
      );
      if (!allowed || !context.mounted) return;
    }
    await action();
  }

  Future<void> _open(BuildContext context, [VehicleRecord? vehicle]) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => VehicleScreen(log: log, vehicle: vehicle),
    ),
  );

  Future<void> _unarchive(BuildContext context, VehicleRecord vehicle) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = RoulekmLocalizations.of(context).vehicleSaveFailed;
    try {
      await log.archiveVehicle(vehicle.id, archived: false);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = RoulekmLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final note = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    const tabular = [FontFeature.tabularFigures()];

    /// Archived vehicles get a muted disc, so the two groups don't look alike.
    Widget avatar(VehicleRecord v) => CircleAvatar(
      backgroundColor: v.archived ? theme.colorScheme.surfaceContainerHighest : null,
      foregroundColor: v.archived ? theme.colorScheme.onSurfaceVariant : null,
      child: Icon(vehicleIcon(v.type)),
    );

    /// [left], then [right] at the end of the line; each line grows with large text (a tile's trailing can't).
    Widget line(Widget left, Widget? right) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        if (right != null) ...[const SizedBox(width: 12), right],
      ],
    );

    Widget amount(VehicleRecord v, VehicleTotal t) => switch (t.cents) {
      final cents? => Text(
        NumberFormat.simpleCurrency(
          locale: lang,
          name: switch (v.rates) {
            RateSystem.france => 'EUR',
            RateSystem.uk => 'GBP',
            RateSystem.us => 'USD',
          },
          decimalDigits: 0,
        ).format((cents + 50) ~/ 100),
        style: theme.textTheme.titleMedium?.copyWith(fontFeatures: tabular),
      ),
      null => const SizedBox.shrink(),
    };

    Widget distance(VehicleRecord v, VehicleTotal t) {
      final number = NumberFormat.decimalPattern(lang).format(t.distance);
      return Text(
        v.rates.unit == DistanceUnit.km ? l10n.distanceKm(number) : l10n.distanceMiles(number),
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontFeatures: tabular),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehiclesTitle)),
      body: ListenableBuilder(
        listenable: Listenable.merge([log, pro]),
        builder: (context, _) {
          final logbook = log.logbook;
          if (logbook == null) return const Center(child: CircularProgressIndicator());
          final totals = vehicleTotals(logbook, now());
          final inUse = log.inUse;
          final archived = logbook.vehicles.where((v) => v.archived).toList();
          final locked = inUse.isNotEmpty && !pro.value;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final v in inUse)
                ListTile(
                  titleAlignment: ListTileTitleAlignment.titleHeight,
                  leading: avatar(v),
                  title: line(Text(v.name), amount(v, totals[v.id]!)),
                  subtitle: line(Text(vehicleSummary(l10n, v)), distance(v, totals[v.id]!)),
                  onTap: () => _open(context, v),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => _addInUse(context, () => _open(context)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(l10n.vehiclesAdd, textAlign: TextAlign.center)),
                      if (locked) ...[const SizedBox(width: 8), const ProTag()],
                    ],
                  ),
                ),
              ),
              if (locked)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(l10n.vehiclesSwapHint, style: note),
                ),
              if (archived.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.vehiclesArchived,
                      style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
                for (final v in archived)
                  ListTile(
                    titleAlignment: ListTileTitleAlignment.titleHeight,
                    leading: avatar(v),
                    title: Text(v.name),
                    subtitle: Text(l10n.vehiclesArchivedNote),
                    // Putting it back in use costs Pro while another is in use: labelled before the tap.
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (locked) ...[const ProTag(), const SizedBox(width: 8)],
                        IconButton(
                          icon: const Icon(Icons.unarchive_outlined),
                          tooltip: l10n.vehiclesUnarchive,
                          onPressed: () => _addInUse(context, () => _unarchive(context, v)),
                        ),
                      ],
                    ),
                    onTap: () => _open(context, v),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
