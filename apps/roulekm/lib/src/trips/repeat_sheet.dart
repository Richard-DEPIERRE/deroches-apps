import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/roulekm_localizations.dart';
import '../data/logbook.dart';
import '../home/home_screen.dart';
import '../rates/rates.dart';

/// The repeat sheet over the trip form (DAPP-141 §4): seven day circles, the first day, the promise and a button that
/// says what it does. Completes with the weekdays picked (`DateTime.monday` to `DateTime.sunday`, ascending), or null.
Future<List<int>?> showRepeatSheet(
  BuildContext context, {
  required List<int> weekdays,
  required DateTime start,
  RateSystem? system,
  TripRoute? route,
}) => showModalBottomSheet<List<int>>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _RepeatSheet(weekdays: weekdays, start: start, system: system, route: route),
);

/// A weekday's name in [lang]: [DateTime.monday] is "lundi" / "Monday".
String weekdayName(String lang, int weekday) => DateFormat.EEEE(lang).format(DateTime.utc(2024, 1, weekday));

/// The days of a pattern: "du lundi au vendredi", "Monday, Wednesday and Friday", "on Mondays", "every day".
String repeatDays(RoulekmLocalizations l10n, String lang, List<int> weekdays) {
  final names = [for (final d in weekdays) weekdayName(lang, d)];
  if (names.length == 7) return l10n.repeatEveryDay;
  if (names.length == 1) return l10n.repeatOneDay(names.single);
  if (names.length >= 3 && weekdays.last - weekdays.first == names.length - 1) {
    return l10n.repeatRange(names.first, names.last);
  }
  return l10n.repeatList(names.sublist(0, names.length - 1).join(', '), names.last);
}

class _RepeatSheet extends StatefulWidget {
  const _RepeatSheet({required this.weekdays, required this.start, this.system, this.route});

  final List<int> weekdays;
  final DateTime start;
  final RateSystem? system;
  final TripRoute? route;

  @override
  State<_RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<_RepeatSheet> {
  late final _on = {...widget.weekdays};

  @override
  Widget build(BuildContext context) {
    final l10n = RoulekmLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final days = [for (var d = DateTime.monday; d <= DateTime.sunday; d++) d];
    final picked = [...days.where(_on.contains)];
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

    Widget circle(int day) {
      final on = _on.contains(day);
      return Expanded(
        // Read in full, picked or not; the whole cell is the tap target.
        child: Semantics(
          button: true,
          selected: on,
          label: weekdayName(lang, day),
          excludeSemantics: true,
          child: InkResponse(
            onTap: () => setState(() => on ? _on.remove(day) : _on.add(day)),
            child: SizedBox(
              height: 48,
              child: Center(
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: on ? scheme.primary : null,
                    shape: CircleBorder(side: BorderSide(color: on ? scheme.primary : scheme.outline)),
                  ),
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: Text(
                      DateFormat.EEEEE(lang).format(DateTime.utc(2024, 1, day)),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: on ? scheme.onPrimary : scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // At large text sizes the details scroll; the button stays on screen.
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.repeatTitle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  if (widget.route case final route?) ...[
                    const SizedBox(height: 4),
                    DefaultTextStyle.merge(style: muted, child: RouteText(route)),
                    Text(
                      route.roundTrip
                          ? l10n.homeRoundTrip(typedDistance(l10n, lang, route.distance))
                          : typedDistance(l10n, lang, route.distance),
                      style: muted,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(children: [for (final d in days) circle(d)]),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.repeatStarting),
                    trailing: Text(shortDay(lang, widget.system, widget.start), style: theme.textTheme.bodyLarge),
                  ),
                  const SizedBox(height: 4),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 8,
                        children: [
                          Icon(Icons.check_circle_outline, size: 20, color: scheme.onSurfaceVariant),
                          Expanded(child: Text(l10n.repeatPromise, style: theme.textTheme.bodyMedium)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: picked.isEmpty ? null : () => Navigator.of(context).pop(picked),
              child: Text(
                picked.isEmpty ? l10n.repeatNoDay : l10n.repeatButton(repeatDays(l10n, lang, picked)),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
