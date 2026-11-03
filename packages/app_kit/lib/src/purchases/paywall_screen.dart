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
/// After a purchase, the screen underneath confirms it.
Future<bool> showPaywall(
  BuildContext context, {
  required String placement,
  required PaywallGate gate,
  required Purchases purchases,
  required Widget header,
}) async {
  if (!gate.canShow(placement)) return false;
  final legal = KitScope.of(context).config.legal[Localizations.localeOf(context).languageCode]!;
  final thanks = KitLocalizations.of(context).paywallPurchased;
  final bought = await Navigator.of(context).push(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => PaywallScreen(placement: placement, purchases: purchases, legal: legal, header: header),
    ),
  );
  if (bought == true && context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(_snackBar(thanks));
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
  _Busy _busy = _Busy.none;
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
    final offers = [
      for (final o in await _purchases.offers())
        if (!o.renews || _isoPeriod.hasMatch(o.period!)) o,
    ];
    if (offers.isEmpty) throw StateError('no plan to offer');
    _picked = offers.any((o) => o.plan == Plan.yearly) ? Plan.yearly : offers.first.plan;
    return offers;
  }

  void _say(String message) => ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(_snackBar(message));

  Future<void> _buy(PlanOffer offer, KitLocalizations l10n) async {
    _purchases.analytics.track('paywall.tap.${offer.plan.name}');
    setState(() => _busy = _Busy.buying);
    final PurchaseResult result;
    try {
      result = await _purchases.buy(offer);
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
    if (!mounted) return;
    switch (result) {
      case Purchased():
        _bought = true;
        Navigator.of(context).pop(true);
      case PurchasePending():
        _say(l10n.paywallPending);
      case PurchaseFailed():
        _say(l10n.paywallBuyFailed);
      case PurchaseCancelled(): // the user's choice: nothing to say
    }
  }

  Future<void> _restore(KitLocalizations l10n) async {
    _purchases.analytics.track('paywall.tap.restore');
    setState(() => _busy = _Busy.restoring);
    final RestoreResult result;
    try {
      result = await _purchases.restore();
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
    if (!mounted) return;
    _say(switch (result) {
      RestoreResult.restored => l10n.paywallRestored,
      RestoreResult.nothingToRestore => l10n.paywallNothingToRestore,
      RestoreResult.failed => l10n.paywallRestoreFailed,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = KitLocalizations.of(context);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_bought) _purchases.analytics.track('paywall.dismiss.${widget.placement}');
      },
      // The screen follows the entitlement as it changes, such as when the
      // store's customer info arrives after the paywall opened.
      child: ValueListenableBuilder(
        valueListenable: _purchases.entitled,
        builder: (context, entitled, _) => FutureBuilder(
          future: _offers,
          builder: (context, snapshot) {
            final offers = entitled ? null : snapshot.data;
            return Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.paywallClose,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              body: SafeArea(
                child: switch (snapshot) {
                  _ when entitled => _Message(Icons.check_circle, l10n.paywallEntitled, [
                    if (_purchases.manageUrl case final url?)
                      OutlinedButton(onPressed: () => widget.openLink(url), child: Text(l10n.paywallManage)),
                    FilledButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(l10n.paywallClose)),
                  ]),
                  AsyncSnapshot(:final data?) => _plans(context, l10n, data),
                  AsyncSnapshot(hasError: true, connectionState: ConnectionState.done) =>
                    _Message(null, l10n.paywallError, [
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _offers = _load();
                        }),
                        child: Text(l10n.paywallRetry),
                      ),
                    ]),
                  _ => Center(child: CircularProgressIndicator(semanticsLabel: l10n.paywallLoading)),
                },
              ),
              // The footer as the bottom bar, so snackbars float above it.
              bottomNavigationBar: offers == null
                  ? null
                  : _footer(context, l10n, offers.firstWhere((o) => o.plan == _picked)),
            );
          },
        ),
      ),
    );
  }

  Widget _plans(BuildContext context, KitLocalizations l10n, List<PlanOffer> offers) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DefaultTextStyle.merge(style: theme.textTheme.titleLarge, child: widget.header),
          for (final offer in offers) ...[
            const SizedBox(height: 12),
            _PlanCard(
              selected: offer.plan == _picked,
              onTap: _busy != _Busy.none ? null : () => setState(() => _picked = offer.plan),
              name: switch (offer.plan) {
                Plan.weekly => l10n.paywallPlanWeekly,
                Plan.yearly => l10n.paywallPlanYearly,
                Plan.lifetime => l10n.paywallPlanLifetime,
              },
              price: offer.renews ? l10n.paywallPricePerPeriod(offer.price, _perPeriod(l10n, offer)) : offer.price,
              terms: offer.renews
                  ? l10n.paywallRenews(l10n.paywallEvery(_period(offer).unit, _period(offer).count), offer.price)
                  : l10n.paywallOneTime,
            ),
          ],
        ],
      ),
    );
  }

  /// Pinned, so the button and what it does stay on screen. On a small phone
  /// at a large text size, the lines above the button scroll within a quarter
  /// of the screen instead of pushing it off, leaving room for a snackbar.
  Widget _footer(BuildContext context, KitLocalizations l10n, PlanOffer picked) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ios = theme.platform == TargetPlatform.iOS || theme.platform == TargetPlatform.macOS;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height / 4),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      !picked.renews
                          ? l10n.paywallOneTime
                          : ios
                          ? l10n.paywallCancelAppStore
                          : l10n.paywallCancelGooglePlay,
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _busy != _Busy.none ? null : () => _restore(l10n),
                          child: _Spinning(_busy == _Busy.restoring, colors.primary, Text(l10n.paywallRestore)),
                        ),
                        // The legal pair breaks as one, so neither link is ever alone on a line.
                        Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => widget.openLink(widget.legal.terms),
                              child: Text(l10n.paywallTerms),
                            ),
                            TextButton(
                              onPressed: () => widget.openLink(widget.legal.privacy),
                              child: Text(l10n.paywallPrivacy),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            FilledButton(
              // While buying it keeps its colours, so it reads as in progress, not unavailable.
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                disabledBackgroundColor: _busy == _Busy.buying ? colors.primary : null,
                disabledForegroundColor: _busy == _Busy.buying ? colors.onPrimary : null,
              ),
              onPressed: _busy != _Busy.none ? null : () => _buy(picked, l10n),
              child: _Spinning(
                _busy == _Busy.buying,
                colors.onPrimary,
                Text(
                  picked.renews
                      ? l10n.paywallSubscribe(picked.price, _perPeriod(l10n, picked))
                      : l10n.paywallBuyOnce(picked.price),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the paywall is waiting on: the spinner shows where the user tapped.
enum _Busy { none, buying, restoring }

/// [label], or while [spinning] a 20dp spinner in its place, at the label's size.
class _Spinning extends StatelessWidget {
  const _Spinning(this.spinning, this.color, this.label);

  final bool spinning;
  final Color color;
  final Widget label;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Visibility.maintain(visible: !spinning, child: label),
      if (spinning) SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
    ],
  );
}

SnackBar _snackBar(String message) => SnackBar(behavior: SnackBarBehavior.floating, content: Text(message));

/// A calm message in place of the plans, with its buttons.
class _Message extends StatelessWidget {
  const _Message(this.icon, this.text, this.actions);

  final IconData? icon;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // One rule for every message: text no wider than 340dp, buttons as wide as it.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null) ...[Icon(icon, size: 48, color: theme.colorScheme.primary), const SizedBox(height: 16)],
              Text(text, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              for (final action in actions) ...[
                const SizedBox(height: 12),
                ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: action),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One plan: a radio choice, shown by its border and icon; the text keeps its colours.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.selected,
    required this.onTap,
    required this.name,
    required this.price,
    required this.terms,
  });

  final bool selected;
  final VoidCallback? onTap;
  final String name;
  final String price;

  /// When it renews and at what price, or that it never does.
  final String terms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(width: 2, color: selected ? colors.primary : colors.outlineVariant),
    );
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          shape: shape,
          onTap: onTap,
          leading: Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            color: selected ? colors.primary : colors.onSurfaceVariant,
          ),
          title: Text(name, style: theme.textTheme.titleMedium?.copyWith(color: colors.onSurface)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                price,
                style: theme.textTheme.titleMedium?.copyWith(color: colors.onSurface, fontWeight: FontWeight.bold),
              ),
              Text(terms, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The store's ISO 8601 periods we can put in words: `P1W`, `P3M`, `P1Y`.
final _isoPeriod = RegExp(r'^P(\d+)([DWMY])$');

String _perPeriod(KitLocalizations l10n, PlanOffer o) => l10n.paywallPeriod(_period(o).unit, _period(o).count);

/// A subscription's period, as the unit and count the messages take.
({String unit, int count}) _period(PlanOffer offer) {
  final match = _isoPeriod.firstMatch(offer.period!)!;
  final unit = const {'D': 'day', 'W': 'week', 'M': 'month', 'Y': 'year'}[match[2]]!;
  return (unit: unit, count: int.parse(match[1]!));
}
