import 'dart:math';

import 'package:flutter/material.dart';

import '../../l10n/roulekm_localizations.dart';
import '../data/log_controller.dart';
import '../data/logbook.dart';
import '../rates/french_bareme.dart';
import '../rates/rates.dart';

/// Add or edit a vehicle: its rate system, type, fiscal horsepower and electric flag (DAPP-141 §5).
class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key, required this.log, this.vehicle});

  final LogController log;

  /// The vehicle to edit; null adds a new one.
  final VehicleRecord? vehicle;

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

/// The chips follow the latest barème's bands.
final _bareme = frenchBaremes[frenchBaremes.keys.reduce(max)]!;

class _VehicleScreenState extends State<VehicleScreen> {
  late final _name = TextEditingController(text: widget.vehicle?.name);
  late RateSystem _rates = widget.vehicle?.rates ?? _regionRates();
  late VehicleType _type = widget.vehicle?.type ?? VehicleType.car;
  late int? _horsepower = widget.vehicle?.horsepower;
  late bool _electric = widget.vehicle?.electric ?? false;
  bool _checked = false;
  bool _saving = false;

  RateSystem _regionRates() => switch (WidgetsBinding.instance.platformDispatcher.locales.firstOrNull?.countryCode) {
    'FR' => RateSystem.france,
    'GB' => RateSystem.uk,
    _ => RateSystem.us,
  };

  bool get _hasHorsepower => _rates == RateSystem.france && _type != VehicleType.moped;
  List<HorsepowerBand> get _bands => _bareme.bands[_type]!;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Runs [change], then [done] and closes the form; keeps it open and says so when the save fails.
  Future<void> _run(Future<void> Function() change, [VoidCallback? done]) async {
    setState(() => _saving = true);
    try {
      await change();
      if (!mounted) return;
      done?.call();
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(RoulekmLocalizations.of(context).vehicleSaveFailed)));
    }
  }

  void _save() {
    setState(() => _checked = true);
    final name = _name.text.trim();
    if (name.isEmpty || (_hasHorsepower && _horsepower == null)) return;
    final france = _rates == RateSystem.france;
    _run(
      () => widget.log.saveVehicle(
        VehicleRecord(
          id: widget.vehicle?.id ?? newId(),
          name: name,
          rates: _rates,
          type: _type,
          horsepower: _hasHorsepower ? _horsepower : null,
          electric: france && _electric,
          archived: widget.vehicle?.archived ?? false,
        ),
      ),
    );
  }

  /// The snackbar goes through the app's messenger, so it stays on the screen underneath.
  void _archive(VehicleRecord vehicle) {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = RoulekmLocalizations.of(context);
    final log = widget.log;
    _run(
      () => log.archiveVehicle(vehicle.id),
      () => messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.vehicleArchived(vehicle.name)),
          action: SnackBarAction(
            label: l10n.vehicleArchiveUndo,
            onPressed: () => log.archiveVehicle(vehicle.id, archived: false).onError((_, _) {
              messenger.showSnackBar(SnackBar(content: Text(l10n.vehicleSaveFailed)));
            }),
          ),
        ),
      ),
    );
  }

  String _ukNote(RoulekmLocalizations l10n) {
    final hmrc = hmrcYearOn(DateTime.now());
    return switch (_type) {
      VehicleType.motorbike => l10n.vehicleUkNoteMotorbike(hmrc.motorcycle ~/ 10),
      VehicleType.bicycle => l10n.vehicleUkNoteBicycle(hmrc.cycle ~/ 10),
      _ => l10n.vehicleUkNote(hmrc.carFirst10k ~/ 10, hmrc.carAbove10k ~/ 10),
    };
  }

  String _bandLabel(RoulekmLocalizations l10n, HorsepowerBand b) => switch (b) {
    HorsepowerBand(maxCv: null) => l10n.vehicleHorsepowerFrom(b.minCv),
    HorsepowerBand(minCv: 1, :final maxCv?) => l10n.vehicleHorsepowerUpTo(maxCv),
    HorsepowerBand(:final minCv, :final maxCv?) when minCv == maxCv => l10n.vehicleHorsepowerOne(minCv),
    HorsepowerBand(:final minCv, :final maxCv?) => l10n.vehicleHorsepowerRange(minCv, maxCv),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = RoulekmLocalizations.of(context);
    final theme = Theme.of(context);
    final note = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
      ),
    );
    Widget chips<T>(List<T> values, T? selected, String Function(T) label, void Function(T) onSelected) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          // A chip's label is one line: one too long for a whole line at large text shrinks, rather than fade.
          ChoiceChip(
            label: FittedBox(fit: BoxFit.scaleDown, child: Text(label(v))),
            selected: v == selected,
            onSelected: (_) => setState(() => onSelected(v)),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.vehicle == null ? l10n.vehicleNewTitle : l10n.vehicleEditTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.vehicleName,
                helperText: l10n.vehicleNameHelper,
                helperMaxLines: 4,
                errorText: _checked && _name.text.trim().isEmpty ? l10n.vehicleNameMissing : null,
              ),
              onChanged: (_) => _checked ? setState(() {}) : null,
            ),
            header(l10n.vehicleRates),
            chips(
              RateSystem.values,
              _rates,
              (r) => switch (r) {
                RateSystem.france => l10n.vehicleRatesFrance,
                RateSystem.uk => l10n.vehicleRatesUk,
                RateSystem.us => l10n.vehicleRatesUs,
              },
              (r) {
                _rates = r;
                if (!r.types.contains(_type)) _type = VehicleType.car;
              },
            ),
            if (_rates.types.length > 1) ...[
              header(l10n.vehicleType),
              chips(
                _rates.types,
                _type,
                (t) => switch (t) {
                  VehicleType.car => l10n.vehicleTypeCar,
                  VehicleType.motorbike => l10n.vehicleTypeMotorbike,
                  VehicleType.moped => l10n.vehicleTypeMoped,
                  VehicleType.bicycle => l10n.vehicleTypeBicycle,
                },
                (t) {
                  if (t != _type) _horsepower = null;
                  _type = t;
                },
              ),
            ],
            if (_hasHorsepower) ...[
              header(l10n.vehicleHorsepower),
              chips(
                _bands,
                _bands.where((b) => (_horsepower ?? 0) >= b.minCv && (_horsepower ?? 0) <= (b.maxCv ?? 99)).firstOrNull,
                (b) => _bandLabel(l10n, b),
                (b) => _horsepower = b.maxCv ?? b.minCv,
              ),
              const SizedBox(height: 8),
              if (_checked && _horsepower == null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.vehicleHorsepowerMissing,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              Text(l10n.vehicleHorsepowerNote, style: note),
            ],
            if (_rates == RateSystem.france)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.vehicleElectric),
                subtitle: Text(l10n.vehicleElectricNote),
                value: _electric,
                onChanged: (on) => setState(() => _electric = on),
              ),
            if (_rates != RateSystem.france) ...[
              const SizedBox(height: 16),
              Text(_rates == RateSystem.uk ? _ukNote(l10n) : l10n.vehicleUsNote, style: note),
            ],
            if (widget.vehicle case final vehicle? when !vehicle.archived)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                // The text-button alignment rule: its label lines up with the fields' edge.
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Transform.translate(
                    offset: const Offset(-12, 0),
                    child: TextButton(
                      // M3 narrows a text button's padding at large text: keep it at the 12 the offset cancels.
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                      onPressed: _saving ? null : () => _archive(vehicle),
                      child: Text(l10n.vehicleArchive),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _saving ? null : _save,
            child: Text(l10n.vehicleSave),
          ),
        ),
      ),
    );
  }
}
