import 'package:app_kit/src/purchases/revenuecat_purchases.dart';
import 'package:app_kit/app_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show PurchasesErrorCode;

void main() {
  test('the user cancelling is a cancellation, Ask to Buy is pending, never a failure', () {
    expect(resultFor(PurchasesErrorCode.purchaseCancelledError, ''), isA<PurchaseCancelled>());
    expect(resultFor(PurchasesErrorCode.paymentPendingError, ''), isA<PurchasePending>());
  });

  test('store errors become failure reasons', () {
    PurchaseFailure reason(PurchasesErrorCode code) => (resultFor(code, 'x') as PurchaseFailed).reason;

    expect(reason(PurchasesErrorCode.purchaseNotAllowedError), PurchaseFailure.notAllowed);
    expect(reason(PurchasesErrorCode.productNotAvailableForPurchaseError), PurchaseFailure.unavailable);
    expect(reason(PurchasesErrorCode.productAlreadyPurchasedError), PurchaseFailure.alreadyOwned);
    expect(reason(PurchasesErrorCode.networkError), PurchaseFailure.network);
    expect(reason(PurchasesErrorCode.offlineConnectionError), PurchaseFailure.network);
    expect(reason(PurchasesErrorCode.storeProblemError), PurchaseFailure.store);
    expect(reason(PurchasesErrorCode.unknownError), PurchaseFailure.other);
  });
}
