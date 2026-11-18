import 'package:flutter/material.dart';

import '../../l10n/roulekm_localizations.dart';
import '../data/log_controller.dart';
import '../data/logbook.dart';
import '../formatting.dart';
import '../trips/repeat_sheet.dart';
import 'home_screen.dart';

/// Each pattern with days waiting, and those days, oldest first.
typedef Waiting = List<(RecurringTrip, List<DateTime>)>;

/// "3 trajets réguliers à confirmer" under the big button (DAPP-141 §1, with Pro): each pattern's route and days,
/// "Voir" to pick which days and "Tout confirmer". Nothing is counted until confirmed, one save per pattern; a day
/// confirmed or skipped is never offered again.
class RecurringCard extends StatelessWidget {
  const RecurringCard({super.key, required this.log, required this.waiting, required this.today, this.tripSaved});

  final LogController log;
  final Waiting waiting;
  final DateTime today;
  final Future<void> Function()? tripSaved;

  /// Adds the [picked] days of each pattern and marks every day shown as seen, then says how many were added or
  /// skipped, with Undo: it removes those trips and puts every day back as waiting, in one save.
  Future<void> _confirm(BuildContext context, Map<String, List<DateTime>> picked) async {
    final l10n = RoulekmLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final count = picked.values.fold(0, (n, days) => n + days.length);
    final skipped = waiting.fold(0, (n, w) => n + w.$2.length) - count;
    final before = <String, DateTime?>{};
    final added = <String>[];
    try {
      for (final (pattern, days) in waiting) {
        final ids = await log.confirmRecurring(pattern.id, picked[pattern.id] ?? const [], through: days.last);
        // Null: an earlier tap already confirmed these days; its own snackbar and Undo cover them.
        if (ids == null) continue;
        before[pattern.id] = pattern.checkedThrough;
        added.addAll(ids);
      }
      if (added.isNotEmpty) await tripSaved?.call();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.tripSaveFailed)));
      return;
    }
    if (before.isEmpty) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(added.isNotEmpty ? l10n.recurringAdded(added.length) : l10n.recurringSkipped(skipped)),
        action: SnackBarAction(
          label: l10n.vehicleArchiveUndo,
          onPressed: () => log.undoConfirm(added, before).onError((_, _) {
            messenger.showSnackBar(SnackBar(content: Text(l10n.tripSaveFailed)));
          }),
        ),
      ),
    );
  }

  Future<void> _review(BuildContext context) async {
    final picked = await showModalBottomSheet<Map<String, List<DateTime>>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _ReviewSheet(log: log, waiting: waiting, today: today),
    );
    if (picked != null && context.mounted) await _confirm(context, picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = RoulekmLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = waiting.fold(0, (n, w) => n + w.$2.length);
    final scaler = MediaQuery.textScalerOf(context);
    final icon = scaler.clamp(maxScaleFactor: 1.5).scale(18);
    final title = theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w600);
    final line = scaler.scale(title.fontSize!) * (title.height ?? 1.2);
    return Card.outlined(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              spacing: 8,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Centred on the title's first line.
                Padding(
                  padding: EdgeInsets.only(top: ((line - icon) / 2).clamp(0, double.infinity)),
                  child: Icon(Icons.repeat, size: icon, color: scheme.primary),
                ),
                Expanded(child: Text(l10n.recurringToConfirm(count), style: title)),
              ],
            ),
            for (final (pattern, days) in waiting) ...[
              const SizedBox(height: 8),
              PatternText(log: log, pattern: pattern, days: days, today: today),
            ],
            const SizedBox(height: 4),
            // Card actions at the end (M3); they wrap at large text sizes. Full width, or the Wrap shrinks to them.
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(onPressed: () => _review(context), child: Text(l10n.recurringReview)),
                  FilledButton.tonal(
                    onPressed: () => _confirm(context, {for (final (pattern, days) in waiting) pattern.id: days}),
                    child: Text(l10n.recurringConfirmAll),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A pattern's route, its weekdays and distance and, with [days], the days waiting: two listed, more
/// as their count and span. A [muted] route (a paused pattern) takes the secondary text colour.
class PatternText extends StatelessWidget {
  const PatternText({
    super.key,
    required this.log,
    required this.pattern,
    required this.today,
    this.days,
    this.muted = false,
  });

  final LogController log;
  final RecurringTrip pattern;
  final DateTime today;
  final List<DateTime>? days;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final l10n = RoulekmLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final route = pattern.route;
    final system = log.logbook?.vehicles.where((v) => v.id == route.vehicleId).firstOrNull?.rates;
    final weekdays = repeatDays(l10n, lang, pattern.weekdays);
    final distance = typedDistance(l10n, lang, route.distance);
    String day(DateTime d) => shortDay(lang, system, d, thisYear: today.year);
    final secondary = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle.merge(
          style: theme.textTheme.bodyLarge?.copyWith(color: muted ? theme.colorScheme.onSurfaceVariant : null),
          child: RouteText(route),
        ),
        Text(
          '${weekdays[0].toUpperCase()}${weekdays.substring(1)}\u00a0· '
          '${route.roundTrip ? l10n.homeRoundTrip(distance) : distance}',
          style: secondary,
        ),
        if (days case final days?)
          Text(
            days.length <= 2
                ? days.map(day).join('\u00a0· ')
                : l10n.recurringSpan(days.length, '${day(days.first)}\u00a0– ${day(days.last)}'),
            style: secondary,
          ),
      ],
    );
  }
}

/// "Voir": every day waiting, ticked; unticked days are skipped, never counted nor offered again.
class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.log, required this.waiting, required this.today});

  final LogController log;
  final Waiting waiting;
  final DateTime today;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _off = <(String, DateTime)>{};

  @override
  Widget build(BuildContext context) {
    final l10n = RoulekmLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final vehicles = widget.log.logbook?.vehicles ?? const [];
    final picked = {
      for (final (pattern, days) in widget.waiting) pattern.id: [...days.where((d) => !_off.contains((pattern.id, d)))],
    };
    final count = picked.values.fold(0, (n, days) => n + days.length);
    final total = widget.waiting.fold(0, (n, w) => n + w.$2.length);
    const edge = EdgeInsets.symmetric(horizontal: 16);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // At large text sizes the days scroll; the button stays on screen.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: edge,
                    child: Text(
                      l10n.recurringToConfirm(total),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: edge,
                    child: Text(
                      l10n.recurringReviewHint,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  for (final (pattern, days) in widget.waiting) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: edge,
                      child: PatternText(log: widget.log, pattern: pattern, today: widget.today),
                    ),
                    for (final d in days)
                      CheckboxListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        controlAffinity: ListTileControlAffinity.leading,
                        value: !_off.contains((pattern.id, d)),
                        onChanged: (on) =>
                            setState(() => on! ? _off.remove((pattern.id, d)) : _off.add((pattern.id, d))),
                        title: Text(
                          shortDay(
                            lang,
                            vehicles.where((v) => v.id == pattern.route.vehicleId).firstOrNull?.rates,
                            d,
                            thisYear: widget.today.year,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => Navigator.of(context).pop(picked),
              child: Text(count == 0 ? l10n.recurringSkip : l10n.recurringConfirm(count), textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}
