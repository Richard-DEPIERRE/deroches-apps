import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/kit_localizations.dart';
import '../app/kit_scope.dart';
import '../config/app_config.dart';
import 'paywall_gate.dart';
import 'purchases.dart';

/// Opens the paywall at [placement] if the soft-paywall rule allows it
/// ([PaywallGate.canShow]). Completes with whether the app's entitlement is
/// active once the paywall closes; false at once, showing nothing, when the
/// gate refuses. [header] is the app's own words on what the plans unlock.
Future<bool> showPaywall(
  BuildContext context, {
  required String placement,
  required PaywallGate gate,
  required Purchases purchases,
  required Widget header,
}) async {
  if (!gate.canShow(placement)) return false;
  final legal = KitScope.of(context).config.legal[Localizations.localeOf(context).languageCode]!;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => PaywallScreen(placement: placement, purchases: purchases, legal: legal, header: header),
    ),
  );
  return purchases.entitled.value;
}

/// The one paywall every app uses, with the honesty rules in code (ADR 0001,
/// section 4; anti-goal 3). Before its button it shows each plan's store
/// price and period, when a subscription renews and at what price, how to
/// cancel, "Restore purchases", the terms and privacy links; its close button
/// works from the first frame. No countdown, urgency or fake trial, ever.
///
/// Open it with [showPaywall], which applies the soft-paywall rule.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    required this.placement,
    required this.purchases,
    required this.legal,
    required this.header,
    this.openLink = _launch,
  });

  final String placement;
  final Purchases purchases;

  /// The app's legal pages in the user's language.
  final LegalLinks legal;
  final Widget header;
  final Future<bool> Function(Uri) openLink;

  static Future<bool> _launch(Uri uri) => launchUrl(uri);

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late Future<List<PlanOffer>> _offers;
  Plan? _picked;
  bool _busy = false;
  bool _bought = false;

  Purchases get _purchases => widget.purchases;

  @override
  void initState() {
    super.initState();
    _purchases.analytics.track('paywall.view.${widget.placement}');
    _offers = _load();
  }

  Future<List<PlanOffer>> _load() async {
    // A subscription whose period can't be put in words is never sold.
    final offers = [for (final o in await _purchases.offers()) if (!o.renews || _isoPeriod.hasMatch(o.period!)) o];
    if (offers.isEmpty) throw StateError('no plan to offer');
    _picked = offers.any((o) => o.plan == Plan.yearly) ? Plan.yearly : offers.first.plan;
    return offers;
  }

  Future<void> _buy(PlanOffer offer) async {
    _purchases.analytics.track('paywall.tap.${offer.plan.name}');
    setState(() => _busy = true);
    final result = await _purchases.buy(offer);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result is Purchased) {
      _bought = true;
      Navigator.of(context).pop();
    }
  }

  Future<void> _restore() async {
    _purchases.analytics.track('paywall.tap.restore');
    setState(() => _busy = true);
    await _purchases.restore();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = KitLocalizations.of(context);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_bought) _purchases.analytics.track('paywall.dismiss.${widget.placement}');
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.paywallClose,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: SafeArea(
          child: FutureBuilder(
            future: _offers,
            builder: (context, snapshot) => switch (snapshot.data) {
              final offers? => _plans(context, l10n, offers),
              null => Center(child: CircularProgressIndicator(semanticsLabel: l10n.paywallLoading)),
            },
          ),
        ),
      ),
    );
  }

  Widget _plans(BuildContext context, KitLocalizations l10n, List<PlanOffer> offers) {
    final theme = Theme.of(context);
    final picked = offers.firstWhere((o) => o.plan == _picked);
    final ios = theme.platform == TargetPlatform.iOS || theme.platform == TargetPlatform.macOS;
    final small = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DefaultTextStyle.merge(style: theme.textTheme.titleLarge, child: widget.header),
          const SizedBox(height: 16),
          for (final offer in offers)
            Card(
              child: ListTile(
                selected: offer.plan == _picked,
                onTap: _busy ? null : () => setState(() => _picked = offer.plan),
                leading: Icon(offer.plan == _picked ? Icons.check_circle : Icons.circle_outlined),
                title: Text(switch (offer.plan) {
                  Plan.weekly => l10n.paywallPlanWeekly,
                  Plan.yearly => l10n.paywallPlanYearly,
                  Plan.lifetime => l10n.paywallPlanLifetime,
                }),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.renews ? l10n.paywallPricePerPeriod(offer.price, _period(offer, l10n)) : offer.price,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      offer.renews ? l10n.paywallRenews(offer.price, _period(offer, l10n)) : l10n.paywallOneTime,
                    ),
                  ],
                ),
              ),
            ),
          if (offers.any((o) => o.renews)) ...[
            const SizedBox(height: 8),
            Text(ios ? l10n.paywallCancelAppStore : l10n.paywallCancelGooglePlay, style: small),
          ],
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(onPressed: _busy ? null : () => _restore(), child: Text(l10n.paywallRestore)),
              TextButton(onPressed: () => widget.openLink(widget.legal.terms), child: Text(l10n.paywallTerms)),
              TextButton(onPressed: () => widget.openLink(widget.legal.privacy), child: Text(l10n.paywallPrivacy)),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : () => _buy(picked),
            child: Text(
              picked.renews
                  ? l10n.paywallSubscribe(picked.price, _period(picked, l10n))
                  : l10n.paywallBuyOnce(picked.price),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// The store's ISO 8601 periods we can put in words: `P1W`, `P3M`, `P1Y`.
final _isoPeriod = RegExp(r'^P(\d+)([DWMY])$');

/// A subscription's period in words.
String _period(PlanOffer offer, KitLocalizations l10n) {
  final match = _isoPeriod.firstMatch(offer.period!)!;
  final unit = const {'D': 'day', 'W': 'week', 'M': 'month', 'Y': 'year'}[match[2]]!;
  return l10n.paywallPeriod(unit, int.parse(match[1]!));
}

