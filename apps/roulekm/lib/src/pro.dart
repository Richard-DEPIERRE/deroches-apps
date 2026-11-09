import 'package:flutter/material.dart';

import '../l10n/roulekm_localizations.dart';

/// Opens the paywall at [placement] (the kit's `showPaywall`, with its soft-paywall rule) and completes with whether
/// Pro is owned when it closes. DAPP-148 connects it.
typedef OpenPaywall = Future<bool> Function(BuildContext context, String placement);

/// Whether a Pro action may go ahead (DAPP-140 §1): at once with Pro; before the first trip, no, with a snackbar and
/// no price; after it, what the paywall at [placement] says.
Future<bool> proAction(
  BuildContext context, {
  required String placement,
  required bool pro,
  required bool tripSaved,
  required OpenPaywall? openPaywall,
}) async {
  if (pro) return true;
  if (!tripSaved) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(RoulekmLocalizations.of(context).proAfterFirstTrip)));
    return false;
  }
  return await openPaywall?.call(context, placement) ?? false;
}

/// The small "Pro" tag on a Pro action, for free users only.
class ProTag extends StatelessWidget {
  const ProTag({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          RoulekmLocalizations.of(context).proTag,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onPrimaryContainer),
        ),
      ),
    );
  }
}
