import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../l10n/roulekm_localizations.dart';
import '../data/log_controller.dart';
import '../data/logbook.dart';
import '../home/home_screen.dart';
import '../rates/distance.dart';
import '../rates/rates.dart';
import '../vehicles/vehicle_screen.dart';

/// Opens *Add a trip* (DAPP-141 §3). [tripSaved] runs after each save: the first trip
/// saved is the app's first useful moment (`markFirstValue()`, DAPP-140).
Future<void> openTripScreen(
  BuildContext context,
  LogController log, {
  Future<void> Function()? tripSaved,
  DateTime Function() now = DateTime.now,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => TripScreen(log: log, tripSaved: tripSaved, now: now),
  ),
);

class TripScreen extends StatefulWidget {
  const TripScreen({super.key, required this.log, this.tripSaved, this.now = DateTime.now});

  final LogController log;
  final Future<void> Function()? tripSaved;
  final DateTime Function() now;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  late DateTime _date = _day(widget.now());
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _purpose = TextEditingController();
  final _distance = TextEditingController();
  bool _roundTrip = false;
  late String? _vehicleId = widget.log.inUse.firstOrNull?.id;
  bool _favourite = false;
  bool _checked = false;
  bool _saving = false;

  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  VehicleRecord? get _vehicle => widget.log.inUse.where((v) => v.id == _vehicleId).firstOrNull;

  DistanceUnit get _unit => (_vehicle?.rates ?? regionRates()).unit;

  int? get _typed => switch (int.tryParse(_distance.text)) {
    final d? when d > 0 => d,
    _ => null,
  };

  @override
  void dispose() {
    for (final c in [_from, _to, _purpose, _distance]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() change) async {
    setState(() => _saving = true);
    try {
      await change();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(RoulekmLocalizations.of(context).tripSaveFailed)));
    }
  }

  Future<void> _save() async {
    setState(() => _checked = true);
    final distance = _typed;
    if (_from.text.trim().isEmpty || _to.text.trim().isEmpty || distance == null) return;
    // After "Later" in onboarding: the vehicle first (DAPP-141 §6).
    if (_vehicle == null) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VehicleScreen(log: widget.log)));
      _vehicleId = widget.log.inUse.firstOrNull?.id;
    }
    final vehicle = _vehicle;
    if (vehicle == null || !mounted) return;
    final route = TripRoute(
      from: _from.text.trim(),
      to: _to.text.trim(),
      purpose: _purpose.text.trim(),
      distance: Distance(distance, vehicle.rates.unit),
      vehicleId: vehicle.id,
      roundTrip: _roundTrip,
    );
    final trip = TripRecord(id: newId(), date: _date, route: route);
    await _run(() async {
      await widget.log.saveTrip(trip);
      if (_favourite) await widget.log.saveFavourite(FavouriteTrip(id: newId(), route: route));
      await widget.tripSaved?.call();
    });
  }

  Future<void> _pickDate() async {
    final now = widget.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) setState(() => _date = _day(picked));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = RoulekmLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final date = (large ? DateFormat.yMMMEd(lang) : DateFormat.yMMMMEEEEd(lang)).format(_date);
    final typed = _typed;
    final counted = typed == null ? null : typedDistance(l10n, lang, Distance(_roundTrip ? typed * 2 : typed, _unit));
    final vehicles = widget.log.inUse;
    String? missing(TextEditingController c, String error) => _checked && c.text.trim().isEmpty ? error : null;

    TextField field(TextEditingController c, String label, {String? error}) => TextField(
      controller: c,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: label, errorText: error),
      onChanged: (_) => _checked ? setState(() {}) : null,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tripNewTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Semantics(
              button: true,
              child: InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.tripDate,
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text('${date[0].toUpperCase()}${date.substring(1)}', style: theme.textTheme.bodyLarge),
                ),
              ),
            ),
            field(_from, l10n.tripFrom, error: missing(_from, l10n.tripFromMissing)),
            field(_to, l10n.tripTo, error: missing(_to, l10n.tripToMissing)),
            field(_purpose, l10n.tripPurpose),
            TextField(
              controller: _distance,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.tripDistance,
                suffixText: _unit == DistanceUnit.km ? 'km' : 'mi',
                errorText: _checked && typed == null ? l10n.tripDistanceMissing : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.tripRoundTrip),
              subtitle: _roundTrip && counted != null ? Text(l10n.tripCounts(counted)) : null,
              value: _roundTrip,
              onChanged: (on) => setState(() => _roundTrip = on),
            ),
            if (vehicles.length > 1)
              // 24 above and 8 below, like the vehicle form's headers: the column already gives 16 above.
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.tripVehicle,
                        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final v in vehicles)
                          ChoiceChip(
                            label: FittedBox(fit: BoxFit.scaleDown, child: Text(v.name)),
                            selected: v.id == _vehicleId,
                            onSelected: (_) => setState(() => _vehicleId = v.id),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.trailing,
              title: Text(l10n.tripFavourite(_vehicle?.rates == RateSystem.uk ? 'yes' : 'no')),
              value: _favourite,
              onChanged: (on) => setState(() => _favourite = on ?? false),
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
            child: Text(counted == null ? l10n.vehicleSave : l10n.tripSave(counted)),
          ),
        ),
      ),
    );
  }
}
