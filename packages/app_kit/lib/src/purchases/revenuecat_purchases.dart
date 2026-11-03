import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

import '../config/app_config.dart';
import 'purchases.dart';

/// The store through RevenueCat (ADR 0001, section 4). The user stays
/// anonymous under RevenueCat's own random app user id: never `logIn`.
/// Purchase state is the entitlement; no receipt check of our own.
class RevenueCatPurchases implements PurchasesBackend {
  RevenueCatPurchases._(this._entitlementId);

  /// Configures RevenueCat with the platform's public SDK key from [config];
  /// null when the app has none for this platform (it then sells nothing).
  static Future<RevenueCatPurchases?> start(AppConfig config) async {
    final key = defaultTargetPlatform == TargetPlatform.iOS ? config.revenueCatAppleKey : config.revenueCatGoogleKey;
    if (key == null) return null;
    await rc.Purchases.configure(rc.PurchasesConfiguration(key));
    final backend = RevenueCatPurchases._(config.entitlementId);
    rc.Purchases.addCustomerInfoUpdateListener(backend._update);
    unawaited(rc.Purchases.getCustomerInfo().then(backend._update, onError: (Object e) => debugPrint('purchases: $e')));
    return backend;
  }

  final String _entitlementId;
  final _entitled = ValueNotifier(false);
  var _packages = <String, rc.Package>{};
  Uri? _manageUrl;

  @override
  ValueListenable<bool> get entitled => _entitled;

  @override
  Uri? get manageUrl => _manageUrl;

  void _update(rc.CustomerInfo info) {
    final manage = info.managementURL;
    _manageUrl = manage == null ? null : Uri.tryParse(manage);
    _entitled.value = info.entitlements.active.containsKey(_entitlementId);
  }

  @override
  Future<List<StorePackage>> packages() async {
    final offering = (await rc.Purchases.getOfferings()).getOffering('default');
    // A free trial or introductory price is never sold: the paywall only states
    // the store's one price, so an app's products carry none (ADR 0001, section 4).
    _packages = {
      for (final p in offering?.availablePackages ?? <rc.Package>[])
        if (p.storeProduct.introductoryPrice == null) p.identifier: p,
    };
    return [
      for (final p in _packages.values)
        StorePackage(id: p.identifier, price: p.storeProduct.priceString, period: p.storeProduct.subscriptionPeriod),
    ];
  }

  @override
  Future<PurchaseResult> buy(String id) async {
    final package = _packages[id];
    if (package == null) return PurchaseFailed(PurchaseFailure.unavailable, 'no package $id');
    try {
      _update((await rc.Purchases.purchase(rc.PurchaseParams.package(package))).customerInfo);
      return const Purchased();
    } on PlatformException catch (e) {
      return resultFor(rc.PurchasesErrorHelper.getErrorCode(e), '${e.code}: ${e.message}');
    }
  }

  @override
  Future<void> restore() async => _update(await rc.Purchases.restorePurchases());
}

@visibleForTesting
PurchaseResult resultFor(rc.PurchasesErrorCode code, String detail) => switch (code) {
  rc.PurchasesErrorCode.purchaseCancelledError => const PurchaseCancelled(),
  rc.PurchasesErrorCode.paymentPendingError => const PurchasePending(),
  _ => PurchaseFailed(switch (code) {
    rc.PurchasesErrorCode.purchaseNotAllowedError ||
    rc.PurchasesErrorCode.insufficientPermissionsError => PurchaseFailure.notAllowed,
    rc.PurchasesErrorCode.productNotAvailableForPurchaseError ||
    rc.PurchasesErrorCode.purchaseInvalidError ||
    rc.PurchasesErrorCode.ineligibleError => PurchaseFailure.unavailable,
    rc.PurchasesErrorCode.productAlreadyPurchasedError => PurchaseFailure.alreadyOwned,
    rc.PurchasesErrorCode.networkError || rc.PurchasesErrorCode.offlineConnectionError => PurchaseFailure.network,
    rc.PurchasesErrorCode.storeProblemError => PurchaseFailure.store,
    _ => PurchaseFailure.other,
  }, detail),
};
