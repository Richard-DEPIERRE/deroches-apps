import 'package:flutter/foundation.dart';

import '../analytics/analytics.dart';
import '../config/app_config.dart';

/// RevenueCat's package for each plan, in the `default` offering (ADR 0001, section 4).
const planPackages = {Plan.weekly: r'$rc_weekly', Plan.yearly: r'$rc_annual', Plan.lifetime: r'$rc_lifetime'};

/// One package of the `default` offering, as the store gives it. Never built
/// from a hard-coded price.
@immutable
class StorePackage {
  const StorePackage({required this.id, required this.price, this.period});

  /// RevenueCat's package identifier, such as `$rc_annual`.
  final String id;

  /// The price as the store formats it, in the user's currency and locale.
  final String price;

  /// The store's ISO 8601 billing period (`P1W`, `P1Y`); null for a one-time purchase.
  final String? period;
}

/// A plan the paywall may offer.
@immutable
class PlanOffer {
  const PlanOffer(this.plan, this.package);

  final Plan plan;
  final StorePackage package;

  /// The store's price, with no-break spaces so it never breaks across lines.
  String get price => package.price.replaceAll(' ', '\u00a0');
  String? get period => package.period;

  /// A subscription renews at [price] every [period] until cancelled in the store.
  bool get renews => package.period != null;
}

/// Why a purchase failed. The name is the analytics detail:
/// `purchase.fail.<name in snake_case>`.
enum PurchaseFailure {
  /// Purchases are off on this device (parental controls, a work profile).
  notAllowed,

  /// The store doesn't sell this product here, or not to this user.
  unavailable,

  /// The store account already owns it: restore instead.
  alreadyOwned,

  network,

  /// The store itself had a problem.
  store,
  other,
}

sealed class PurchaseResult {
  const PurchaseResult();
}

final class Purchased extends PurchaseResult {
  const Purchased();
}

/// The user closed the store's sheet. Not an error.
final class PurchaseCancelled extends PurchaseResult {
  const PurchaseCancelled();
}

/// Waiting for someone else, such as a parent's Ask to Buy approval. The
/// entitlement turns on by itself if it goes through.
final class PurchasePending extends PurchaseResult {
  const PurchasePending();
}

final class PurchaseFailed extends PurchaseResult {
  const PurchaseFailed(this.reason, this.detail);

  final PurchaseFailure reason;

  /// For logs and crash breadcrumbs, never shown to the user.
  final String detail;

  @override
  String toString() => 'PurchaseFailed(${reason.name}): $detail';
}

enum RestoreResult { restored, nothingToRestore, failed }

/// The store, through RevenueCat in an app (`RevenueCatPurchases`) and
/// `FakePurchasesBackend` from `package:app_kit/testing.dart` in tests.
abstract interface class PurchasesBackend {
  /// The `default` offering's packages. Throws when the store can't be reached.
  Future<List<StorePackage>> packages();

  /// Buys package [id], one of those [packages] returned.
  Future<PurchaseResult> buy(String id);

  /// Restores the store account's purchases into [entitled]. Throws when the
  /// store can't be reached.
  Future<void> restore();

  /// Whether the app's entitlement is active.
  ValueListenable<bool> get entitled;

  /// The store's page for managing the active subscription; null without one,
  /// such as for a lifetime purchase. Set before [entitled] changes.
  Uri? get manageUrl;
}

/// The only way an app sells (ADR 0001, section 4): the plans of its
/// [AppConfig], at the store's prices, with `purchase.*` events.
class Purchases {
  Purchases({required this.backend, required this.analytics, required this.plans});

  final PurchasesBackend backend;
  final Analytics analytics;
  final Set<Plan> plans;

  /// The entitlement: true once a plan is bought or restored.
  ValueListenable<bool> get entitled => backend.entitled;

  /// See [PurchasesBackend.manageUrl].
  Uri? get manageUrl => backend.manageUrl;

  /// The plans the app sells and the store has, in [Plan] order. Throws when
  /// the store can't be reached.
  Future<List<PlanOffer>> offers() async {
    final byId = {for (final p in await backend.packages()) p.id: p};
    return [
      for (final plan in Plan.values)
        if (plans.contains(plan) && byId[planPackages[plan]] != null) PlanOffer(plan, byId[planPackages[plan]]!),
    ];
  }

  Future<PurchaseResult> buy(PlanOffer offer) async {
    PurchaseResult result;
    try {
      result = await backend.buy(offer.package.id);
    } catch (e) {
      result = PurchaseFailed(PurchaseFailure.other, '$e');
    }
    switch (result) {
      case Purchased():
        analytics.track('purchase.complete.${offer.plan.name}');
      case PurchaseFailed(:final reason):
        analytics.track('purchase.fail.${_snake(reason.name)}');
      case PurchaseCancelled() || PurchasePending():
    }
    return result;
  }

  Future<RestoreResult> restore() async {
    try {
      await backend.restore();
    } catch (e) {
      debugPrint('restore: $e');
      return RestoreResult.failed;
    }
    return entitled.value ? RestoreResult.restored : RestoreResult.nothingToRestore;
  }
}

String _snake(String name) => name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
