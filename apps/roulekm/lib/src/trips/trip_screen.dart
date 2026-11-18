import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../l10n/roulekm_localizations.dart';
import '../data/log_controller.dart';
import '../data/logbook.dart';
import '../formatting.dart';
import '../pro.dart';
import '../rates/distance.dart';
import '../rates/rates.dart';
import '../vehicles/vehicle_screen.dart';
import 'repeat_sheet.dart';

/// Opens *Add a trip*, or *Edit trip* with [trip] (DAPP-141 §3); a new trip starts from [route] and [date] when
/// given (a favourite's "Edit before adding"). [tripSaved] runs after each save: the first trip saved is the app's
/// first useful moment (`markFirstValue()`, DAPP-140). A new trip can repeat (Pro, `recurring_trip`): the trip is
/// saved first, the pattern only with [pro] or once [openPaywall] says it was bought.
Future<void> openTripScreen(
  BuildContext context,
  LogController log, {
  TripRecord? trip,
  TripRoute? route,
  DateTime? date,
  Future<void> Function()? tripSaved,
  ValueListenable<bool>? pro,
  OpenPaywall? openPaywall,
  DateTime Function() now = DateTime.now,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => TripScreen(
      log: log,
      trip: trip,
      route: route,
      date: date,
      tripSaved: tripSaved,
      pro: pro,
      openPaywall: openPaywall,
      now: now,
    ),
  ),
);

class TripScreen extends StatefulWidget {
  const TripScreen({
    super.key,
    required this.log,
    this.trip,
    this.route,
    this.date,
    this.tripSaved,
    this.pro,
    this.openPaywall,
    this.now = DateTime.now,
  });

  final LogController log;
  final TripRecord? trip;

  /// A new trip's starting point.
  final TripRoute? route;
  final DateTime? date;
  final Future<void> Function()? tripSaved;
  final ValueListenable<bool>? pro;
  final OpenPaywall? openPaywall;
  final DateTime Function() now;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  /// Kept across save attempts: saving again after a failure replaces the trip, never adds a second one.
  late final _id = widget.trip?.id ?? newId();
  late final _route = widget.trip?.route ?? widget.route;
  late DateTime _date = widget.trip?.date ?? widget.date ?? _day(widget.now());
  late final _from = TextEditingController(text: _route?.from);
  late final _to = TextEditingController(text: _route?.to);
  late final _purpose = TextEditingController(text: _route?.purpose);
  late final _distance = TextEditingController(text: _route?.distance.value.toString());
  late final _start = TextEditingController(text: widget.trip?.odometerStart?.toString());
  late final _end = TextEditingController(text: widget.trip?.odometerEnd?.toString());
  final _fromFocus = FocusNode();
  final _toFocus = FocusNode();
  late bool _odometer = widget.trip?.odometerStart != null && widget.trip?.odometerEnd != null;
  bool _grouped = false;
  late bool _roundTrip = _route?.roundTrip ?? false;
  late String? _vehicleId = _route?.vehicleId ?? widget.log.inUse.firstOrNull?.id;
  bool _favourite = false;

  /// The weekdays picked in the repeat sheet; null when the trip doesn't repeat.
  List<int>? _repeat;
  bool _checked = false;
  bool _saving = false;

  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// The vehicles in use, and the trip's own if it was archived since.
  List<VehicleRecord> get _vehicles => [
    ...widget.log.inUse,
    ...?widget.log.logbook?.vehicles.where((v) => v.archived && v.id == _route?.vehicleId),
  ];

  VehicleRecord? get _vehicle => _vehicles.where((v) => v.id == _vehicleId).firstOrNull;

  DistanceUnit get _unit => (_vehicle?.rates ?? regionRates()).unit;

  int? get _typed => switch (int.tryParse(_distance.text)) {
    final d? when d > 0 => d,
    _ => null,
  };

  static int? _reading(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'\D'), ''));

  /// The one-way distance: typed, or between the two odometer readings.
  int? get _measured => _odometer ? odometerDistance(_reading(_start), _reading(_end)) : _typed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A saved trip's readings, grouped as the phone writes numbers, like the ones typed.
    if (_grouped) return;
    _grouped = true;
    final lang = Localizations.localeOf(context).languageCode;
    for (final c in [_start, _end]) {
      c.text = _group(lang, _reading(c));
    }
  }

  @override
  void dispose() {
    for (final c in [_from, _to, _purpose, _distance, _start, _end]) {
      c.dispose();
    }
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  void _swap() => setState(() {
    final from = _from.text;
    _from.text = _to.text;
    _to.text = from;
  });

  /// Back to a typed distance, the readings' distance carries over.
  void _setOdometer(bool on) => setState(() {
    if (_measured case final d? when !on) _distance.text = '$d';
    _odometer = on;
  });

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
      ).showSnackBar(SnackBar(content: Text(RoulekmLocalizations.of(context).tripSaveFailed)));
    }
  }

  Future<void> _save() async {
    setState(() => _checked = true);
    final distance = _measured;
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
    final trip = TripRecord(
      id: _id,
      date: _date,
      route: route,
      odometerStart: _odometer ? _reading(_start) : null,
      odometerEnd: _odometer ? _reading(_end) : null,
    );
    await _run(() async {
      await widget.log.saveTrip(trip);
      if (_favourite) await widget.log.saveFavourite(FavouriteTrip(id: newId(), route: route));
      await widget.tripSaved?.call();
      // Then the repetition, which alone needs Pro: without it the trip stays and no pattern is kept.
      if (_repeat case final weekdays? when mounted) {
        final allowed = await proAction(
          context,
          placement: 'recurring_trip',
          pro: _pro,
          tripSaved: true,
          openPaywall: widget.openPaywall,
        );
        if (allowed) {
          await widget.log.saveRecurring(
            RecurringTrip(id: newId(), route: route, weekdays: weekdays, startDate: _date, checkedThrough: _date),
          );
        }
      }
    });
  }

  bool get _pro => widget.pro?.value ?? false;

  /// The repeat sheet; the pattern starts on the trip's day, which the trip itself covers.
  Future<void> _pickRepeat() async {
    if (!_pro && (widget.log.logbook?.trips.isEmpty ?? true)) {
      // Before the first trip: the snackbar, no price (DAPP-140 §1).
      await proAction(context, placement: 'recurring_trip', pro: false, tripSaved: false, openPaywall: null);
      return;
    }
    final measured = _measured;
    final picked = await showRepeatSheet(
      context,
      weekdays: _repeat ?? const [1, 2, 3, 4, 5],
      start: _date,
      thisYear: widget.now().year,
      system: _vehicle?.rates,
      route: _from.text.trim().isEmpty || _to.text.trim().isEmpty || measured == null
          ? null
          : TripRoute(
              from: _from.text.trim(),
              to: _to.text.trim(),
              purpose: '',
              distance: Distance(measured, _unit),
              vehicleId: '',
              roundTrip: _roundTrip,
            ),
    );
    if (picked != null && mounted) setState(() => _repeat = picked);
  }

  void _delete(TripRecord trip) {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = RoulekmLocalizations.of(context);
    final log = widget.log;
    _run(
      () => log.deleteTrip(trip.id),
      () => messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.tripDeleted),
          action: SnackBarAction(
            label: l10n.vehicleArchiveUndo,
            onPressed: () => log.saveTrip(trip).onError((_, _) {
              messenger.showSnackBar(SnackBar(content: Text(l10n.tripSaveFailed)));
            }),
          ),
        ),
      ),
    );
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
    final measured = _measured;
    String distance(int d) => typedDistance(l10n, lang, Distance(d, _unit));
    final counted = measured == null ? null : distance(_roundTrip ? measured * 2 : measured);
    final vehicles = _vehicles;
    final places = widget.log.logbook?.places ?? const <String>[];
    final purposes = widget.log.logbook?.purposes.take(3) ?? const <String>[];
    final start = _reading(_start);
    final end = _reading(_end);
    String? missing(TextEditingController c, String error) => _checked && c.text.trim().isEmpty ? error : null;
    String? unread(int? reading) => _checked && reading == null ? l10n.tripOdometerMissing : null;

    TextField field(TextEditingController c, String label, {String? error, FocusNode? focusNode}) => TextField(
      controller: c,
      focusNode: focusNode,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: label, errorText: error),
      onChanged: (_) => _checked ? setState(() {}) : null,
    );

    // The user's own places, on the phone only.
    Widget place(TextEditingController c, FocusNode focusNode, String label, String? error) => Autocomplete<String>(
      textEditingController: c,
      focusNode: focusNode,
      optionsBuilder: (value) {
        final typed = value.text.trim().toLowerCase();
        return typed.isEmpty
            ? const []
            : places.where((p) => p.toLowerCase().contains(typed) && p.toLowerCase() != typed);
      },
      onSelected: (_) => setState(() {}),
      fieldViewBuilder: (_, c, focusNode, _) => field(c, label, error: error, focusNode: focusNode),
      // An M3 menu, with no row highlighted: on a touch phone that reads as pre-selected.
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: AlignmentDirectional.topStart,
        child: Material(
          elevation: 3,
          color: theme.colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              shrinkWrap: true,
              children: [
                for (final option in options)
                  InkWell(
                    onTap: () => onSelected(option),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(option, style: theme.textTheme.bodyLarge),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    TextField reading(TextEditingController c, String label, String? error) => TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [_ReadingFormatter(lang)],
      decoration: InputDecoration(labelText: label, errorText: error, errorMaxLines: 2),
      onChanged: (_) => setState(() {}),
    );
    final readings = [
      reading(_start, l10n.tripOdometerStart, unread(start)),
      reading(
        _end,
        l10n.tripOdometerEnd,
        // Not while the end reading is still being typed: both are grouped alike, so lengths compare digits.
        start != null && end != null && end <= start && (_checked || _end.text.length >= _start.text.length)
            ? l10n.tripOdometerBelow
            : unread(end),
      ),
    ];

    // The text-button alignment rule: its label lines up with the fields' edge.
    Widget textButton(String label, VoidCallback? onPressed) => Align(
      alignment: AlignmentDirectional.centerStart,
      child: Transform.translate(
        offset: const Offset(-12, 0),
        child: TextButton(
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.trip == null ? l10n.tripNewTitle : l10n.tripEditTitle)),
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
            // A tonal swap button on the line between the places; a text button under them at large text sizes.
            Stack(
              alignment: AlignmentDirectional.centerEnd,
              children: [
                Column(
                  spacing: 16,
                  children: [
                    place(_from, _fromFocus, l10n.tripFrom, missing(_from, l10n.tripFromMissing)),
                    place(_to, _toFocus, l10n.tripTo, missing(_to, l10n.tripToMissing)),
                  ],
                ),
                if (!large)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: IconButton.filledTonal(
                      tooltip: l10n.tripSwap,
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      onPressed: _swap,
                      icon: const Icon(Icons.swap_vert),
                    ),
                  ),
              ],
            ),
            if (large) textButton(l10n.tripSwap, _swap),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                field(_purpose, l10n.tripPurpose),
                if (purposes.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in purposes)
                        ActionChip(
                          // The user's own text, which can be long: cut, never shrunk.
                          label: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onPressed: () => setState(() => _purpose.text = p),
                        ),
                    ],
                  ),
              ],
            ),
            SegmentedButton<bool>(
              segments: [
                // Above 1.3× text, no icons: the fill shows the selected one.
                ButtonSegment(
                  value: false,
                  label: Text(l10n.tripModeDistance),
                  icon: large ? null : const Icon(Icons.straighten),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(l10n.tripModeOdometer),
                  icon: large ? null : const Icon(Icons.speed),
                ),
              ],
              showSelectedIcon: !large,
              selected: {_odometer},
              onSelectionChanged: (s) => _setOdometer(s.single),
            ),
            if (!_odometer)
              TextField(
                controller: _distance,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.tripDistance,
                  suffixText: _unit == DistanceUnit.km ? 'km' : 'mi',
                  errorText: _checked && measured == null ? l10n.tripDistanceMissing : null,
                ),
                onChanged: (_) => setState(() {}),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  // Side by side only while each half holds its label: stacked on a small phone with large text.
                  LayoutBuilder(
                    builder: (context, box) => (box.maxWidth - 16) / 2 >= MediaQuery.textScalerOf(context).scale(130)
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 16,
                            children: [for (final r in readings) Expanded(child: r)],
                          )
                        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: readings),
                  ),
                  if (measured != null)
                    Text(
                      l10n.tripOdometerDistance(distance(measured)),
                      style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                    ),
                ],
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
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(v.archived ? l10n.tripVehicleArchived(v.name) : v.name),
                            ),
                            selected: v.id == _vehicleId,
                            onSelected: (_) => setState(() => _vehicleId = v.id),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (widget.trip == null)
              // No leading icon: its text lines up with the rows around it, whose controls sit at the end.
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  spacing: 8,
                  children: [
                    Flexible(child: Text(l10n.repeatTitle)),
                    if (!_pro) const ProTag(),
                  ],
                ),
                subtitle: Text(switch (_repeat) {
                  final days? => _capitalized(repeatDays(l10n, lang, days)),
                  null => l10n.repeatNever,
                }),
                trailing: const Icon(Icons.chevron_right),
                onTap: _saving ? null : _pickRepeat,
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.trailing,
              title: Text(l10n.tripFavourite(_vehicle?.rates == RateSystem.uk ? 'yes' : 'no')),
              value: _favourite,
              onChanged: (on) => setState(() => _favourite = on ?? false),
            ),
            if (widget.trip case final trip?) textButton(l10n.tripDelete, _saving ? null : () => _delete(trip)),
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

String _capitalized(String s) => '${s[0].toUpperCase()}${s.substring(1)}';

String _group(String lang, int? n) => n == null ? '' : NumberFormat.decimalPattern(lang).format(n);

/// Groups an odometer reading's digits as the phone writes numbers ("45 210", "32,580"); 7 digits at most.
class _ReadingFormatter extends TextInputFormatter {
  _ReadingFormatter(this.lang);

  final String lang;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 7) return oldValue;
    final text = _group(lang, int.tryParse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
