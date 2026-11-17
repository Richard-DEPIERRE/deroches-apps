import 'dart:async';

import 'package:app_kit/app_kit.dart';
import 'package:flutter/material.dart';

import '../l10n/roulekm_localizations.dart';

/// Opens the paywall at [placement] (the kit's `showPaywall`, with its soft-paywall rule) and completes with whether
/// Pro is owned when it closes.
typedef OpenPaywall = Future<bool> Function(BuildContext context, String placement);

/// The kit's paywall with Roulekm's header (DAPP-140 §2); null when the app sells nothing on this platform.
/// Only asked once a trip is saved ([proAction]), which is the first useful moment: it is marked first, so a log
/// restored from a backup on a new phone opens the paywall too.
OpenPaywall? roulekmPaywall(KitStateController kitState, Purchases? purchases) {
  if (purchases == null) return null;
  final gate = PaywallGate(kitState);
  return (context, placement) {
    // The kit state changes at once, so the gate allows the paywall; the save to disk follows.
    unawaited(gate.markFirstValue());
    return showPaywall(context, placement: placement, gate: gate, purchases: purchases, header: const ProHeader());
  };
}

/// What every plan unlocks, word for word from DAPP-140 §2.
class ProHeader extends StatelessWidget {
  const ProHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = RoulekmLocalizations.of(context);
    final body = Theme.of(context).textTheme.bodyLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(l10n.proTitle)),
        const SizedBox(height: 8),
        Text(l10n.proLine, style: body),
        const SizedBox(height: 12),
        for (final line in [l10n.proPdf, l10n.proCsv, l10n.proRecurring, l10n.proVehicles])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(line, style: body)),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(l10n.proFoot, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

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
