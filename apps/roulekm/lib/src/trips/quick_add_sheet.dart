import 'package:flutter/material.dart';

import '../../l10n/roulekm_localizations.dart';
import '../data/log_controller.dart';
import '../data/logbook.dart';
import '../home/home_screen.dart';
import 'trip_screen.dart';

/// Tap 1 on a favourite (DAPP-141 §2): the route, its day, and "Ajouter le trajet" (tap 2). After it the sheet
/// closes and a snackbar offers Undo. [tripSaved] runs after each save, as in the trip form.
Future<void> showQuickAdd(
  BuildContext context,
  LogController log,
  TripRoute route, {
  Future<void> Function()? tripSaved,
  DateTime Function() now = DateTime.now,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _QuickAddSheet(home: context, log: log, route: route, tripSaved: tripSaved, now: now),
);

class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet({
    required this.home,
    required this.log,
    required this.route,
    required this.tripSaved,
    required this.now,
  });

  /// The home screen's context: the snackbar and the trip form outlive the sheet.
  final BuildContext home;
  final LogController log;
  final TripRoute route;
  final Future<void> Function()? tripSaved;
  final DateTime Function() now;

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  late final _today = _day(widget.now());
  late final _yesterday = DateTime.utc(_today.year, _today.month, _today.day - 1);
  late DateTime _date = _today;
  bool _saving = false;

  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(_today.year + 1, 12, 31),
    );
    if (picked != null) setState(() => _date = _day(picked));
  }

  Future<void> _add(String added) async {
    setState(() => _saving = true);
    final l10n = RoulekmLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(widget.home);
    final log = widget.log;
    final trip = TripRecord(id: newId(), date: _date, route: widget.route);
    var saved = true;
    try {
      await log.saveTrip(trip);
      await widget.tripSaved?.call();
    } catch (_) {
      saved = false;
    }
    if (mounted) Navigator.of(context).pop();
    messenger.showSnackBar(
      saved
          ? SnackBar(
              content: Text(added),
              action: SnackBarAction(
                label: l10n.vehicleArchiveUndo,
                onPressed: () => log.deleteTrip(trip.id).onError((_, _) {
                  messenger.showSnackBar(SnackBar(content: Text(l10n.tripSaveFailed)));
                }),
              ),
            )
          : SnackBar(content: Text(l10n.tripSaveFailed)),
    );
  }

  void _edit() {
    Navigator.of(context).pop();
    openTripScreen(
      widget.home,
      widget.log,
      route: widget.route,
      date: _date,
      tripSaved: widget.tripSaved,
      now: widget.now,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = RoulekmLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final route = widget.route;
    final vehicle = widget.log.logbook?.vehicles.where((v) => v.id == route.vehicleId).firstOrNull;
    final distance = typedDistance(l10n, lang, route.distance);
    final counted = typedDistance(l10n, lang, route.counted);
    final other = _date != _today && _date != _yesterday;

    Widget chip(String label, bool selected, VoidCallback onSelected, {Widget? avatar}) =>
        ChoiceChip(avatar: avatar, label: Text(label), selected: selected, onSelected: (_) => onSelected());

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // At large text sizes the details scroll; the buttons stay on screen.
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    child: RouteText(route),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      route.purpose,
                      ?vehicle?.name,
                      route.roundTrip ? l10n.quickAddRoundTrip(distance, counted) : distance,
                    ].where((s) => s.isNotEmpty).join('\u00a0· '),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      chip(l10n.quickAddToday, _date == _today, () => setState(() => _date = _today)),
                      chip(l10n.quickAddYesterday, _date == _yesterday, () => setState(() => _date = _yesterday)),
                      chip(
                        other ? shortDay(lang, vehicle?.rates, _date, thisYear: _today.year) : l10n.quickAddOtherDate,
                        other,
                        _pickDate,
                        // The one chip that opens a picker; selected, the check takes its place.
                        avatar: Icon(
                          Icons.calendar_today_outlined,
                          size: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5).scale(18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _saving ? null : () => _add(l10n.tripAdded(counted)),
                  child: Text(l10n.quickAddAdd),
                ),
                TextButton(onPressed: _saving ? null : _edit, child: Text(l10n.quickAddEdit)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
