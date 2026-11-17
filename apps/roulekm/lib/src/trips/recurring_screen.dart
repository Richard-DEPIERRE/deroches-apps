import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/roulekm_localizations.dart';
import '../data/log_controller.dart';
import '../data/logbook.dart';
import '../home/recurring_card.dart';
import '../pro.dart';
import 'repeat_sheet.dart';

enum _Action { pause, resume, edit, delete }

/// Room between items that wrap at large text sizes; at 1× the 48 dp height still wins.
const _itemPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

/// Settings → Roulekm → "Trajets récurrents" (DAPP-141 §4 and §11): one row per pattern with its menu: pause or
/// resume and delete, free; change the days (Pro, `recurring_trip`), in the repeat sheet. A deleted one has Undo.
class RecurringScreen extends StatelessWidget {
  const RecurringScreen({
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

  /// Runs [change]; a save that fails says so. Completes with whether it was saved.
  Future<bool> _run(BuildContext context, Future<void> Function() change) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = RoulekmLocalizations.of(context).tripSaveFailed;
    try {
      await change();
      return true;
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
      return false;
    }
  }

  Future<void> _edit(BuildContext context, RecurringTrip pattern) async {
    final allowed = await proAction(
      context,
      placement: 'recurring_trip',
      pro: pro.value,
      tripSaved: log.logbook!.trips.isNotEmpty,
      openPaywall: openPaywall,
    );
    if (!allowed || !context.mounted) return;
    final picked = await showRepeatSheet(
      context,
      weekdays: pattern.weekdays,
      start: null,
      title: RoulekmLocalizations.of(context).recurringEdit,
      thisYear: now().year,
      system: log.logbook?.vehicles.where((v) => v.id == pattern.route.vehicleId).firstOrNull?.rates,
      route: pattern.route,
    );
    if (picked != null && context.mounted) await _run(context, () => log.editRecurring(pattern.id, picked));
  }

  Future<void> _delete(BuildContext context, RecurringTrip pattern) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = RoulekmLocalizations.of(context);
    final at = log.logbook!.recurring.indexOf(pattern);
    if (!await _run(context, () => log.deleteRecurring(pattern.id))) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.recurringDeleted),
        action: SnackBarAction(
          label: l10n.vehicleArchiveUndo,
          onPressed: () => log.saveRecurring(pattern, at: at).onError((_, _) {
            messenger.showSnackBar(SnackBar(content: Text(l10n.tripSaveFailed)));
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = RoulekmLocalizations.of(context);
    final theme = Theme.of(context);
    // Its own messenger, like the kit's Settings: the Undo snackbar leaves with the screen.
    return ScaffoldMessenger(
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.recurringTitle)),
        body: ListenableBuilder(
          listenable: Listenable.merge([log, pro]),
          builder: (context, _) {
            final recurring = log.logbook?.recurring;
            if (recurring == null) return const Center(child: CircularProgressIndicator());
            if (recurring.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.recurringNone,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              );
            }
            final today = now();
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final pattern in recurring)
                  ListTile(
                    contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 4),
                    titleAlignment: ListTileTitleAlignment.titleHeight,
                    title: PatternText(log: log, pattern: pattern, today: today, muted: pattern.paused),
                    subtitle: pattern.paused ? Text(l10n.recurringPaused) : null,
                    trailing: PopupMenuButton<_Action>(
                      onSelected: (action) => unawaited(switch (action) {
                        _Action.pause || _Action.resume => _run(
                          context,
                          () => log.pauseRecurring(pattern.id, paused: action == _Action.pause, now: now()),
                        ),
                        _Action.edit => _edit(context, pattern),
                        _Action.delete => _delete(context, pattern),
                      }),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          padding: _itemPadding,
                          value: pattern.paused ? _Action.resume : _Action.pause,
                          child: Text(pattern.paused ? l10n.recurringResume : l10n.recurringPause),
                        ),
                        // Changing the days costs Pro: labelled before the tap.
                        PopupMenuItem(
                          padding: _itemPadding,
                          value: _Action.edit,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(child: Text(l10n.recurringEdit)),
                              if (!pro.value) ...[const SizedBox(width: 8), const ProTag()],
                            ],
                          ),
                        ),
                        PopupMenuItem(padding: _itemPadding, value: _Action.delete, child: Text(l10n.recurringDelete)),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
