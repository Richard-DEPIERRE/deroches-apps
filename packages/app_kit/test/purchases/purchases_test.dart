import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakePurchasesBackend store;
  late FakeAnalyticsBackend sent;

  Future<Purchases> purchases(Set<Plan> plans) async {
    final dir = Directory.systemTemp.createTempSync('purchases_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final kit = KitStateController(directory: dir, appId: 'carnet-km');
    await kit.load();
    sent = FakeAnalyticsBackend();
    store = FakePurchasesBackend();
    return Purchases(
      backend: store,
      plans: plans,
      analytics: Analytics(backend: sent, kitState: kit, appId: 'carnet-km', appVersion: '1.0.0', locale: () => 'fr'),
    );
  }

  Future<List<String>> events(Purchases p) async {
    await p.analytics.idle;
    return [for (final e in sent.events) e.name];
  }

  test('each plan maps to its RevenueCat package, with the price, period and renewal the store gives', () async {
    final offers = await (await purchases(Plan.values.toSet())).offers();

    expect([for (final o in offers) o.plan], Plan.values);
    expect([for (final o in offers) o.package.id], [r'$rc_weekly', r'$rc_annual', r'$rc_lifetime']);
    expect([for (final o in offers) o.price], ['0,99\u00a0€', '9,99\u00a0€', '24,99\u00a0€']);
    expect([for (final o in offers) o.period], ['P1W', 'P1Y', null]);
    expect([for (final o in offers) o.renews], [true, true, false]);
  });

  test("the plans come in the offering's order, not the kit's", () async {
    final p = await purchases(Plan.values.toSet());
    store.storePackages.setAll(0, store.storePackages.reversed.toList());

    expect([for (final o in await p.offers()) o.plan], [Plan.lifetime, Plan.yearly, Plan.weekly]);
  });

  test('a plain space in the store price becomes a no-break space, so the price never breaks', () async {
    final p = await purchases({Plan.lifetime});
    store.storePackages[2] = const StorePackage(id: r'$rc_lifetime', price: '1 234,99 €');

    expect((await p.offers()).single.price, '1\u00a0234,99\u00a0€');
  });

  test("a plan the app doesn't sell is hidden, and so is one the store doesn't have", () async {
    final p = await purchases({Plan.yearly, Plan.lifetime});
    expect([for (final o in await p.offers()) o.plan], [Plan.yearly, Plan.lifetime]);

    store.storePackages.removeWhere((s) => s.id == r'$rc_lifetime');
    expect([for (final o in await p.offers()) o.plan], [Plan.yearly]);
  });

  test('buying unlocks the entitlement and sends purchase.complete.<plan>', () async {
    final p = await purchases({Plan.yearly});
    final yearly = (await p.offers()).single;

    expect(p.entitled.value, isFalse);
    expect(await p.buy(yearly), isA<Purchased>());
    expect(store.bought, [r'$rc_annual']);
    expect(p.entitled.value, isTrue);
    expect(await events(p), ['purchase.complete.yearly']);
  });

  test("cancelling isn't an error: no failure event, nothing unlocked", () async {
    final p = await purchases({Plan.yearly});
    store.nextResult = const PurchaseCancelled();

    expect(await p.buy((await p.offers()).single), isA<PurchaseCancelled>());
    expect(p.entitled.value, isFalse);
    expect(await events(p), isEmpty);
  });

  test('a pending purchase (Ask to Buy) is not a failure either', () async {
    final p = await purchases({Plan.yearly});
    store.nextResult = const PurchasePending();

    expect(await p.buy((await p.offers()).single), isA<PurchasePending>());
    expect(await events(p), isEmpty);
  });

  test('a failed purchase sends purchase.fail.<reason>', () async {
    final p = await purchases({Plan.weekly});
    store.nextResult = const PurchaseFailed(PurchaseFailure.notAllowed, 'parental controls');

    final result = await p.buy((await p.offers()).single);
    expect((result as PurchaseFailed).reason, PurchaseFailure.notAllowed);
    expect(await events(p), ['purchase.fail.not_allowed']);
  });

  test('a purchase that throws is a failure, never an exception', () async {
    final p = await purchases({Plan.weekly});
    final offer = (await p.offers()).single;
    final throwing = Purchases(backend: _ThrowingStore(), analytics: p.analytics, plans: p.plans);

    final result = await throwing.buy(offer);
    expect((result as PurchaseFailed).reason, PurchaseFailure.other);
    expect(await events(p), ['purchase.fail.other']);
  });

  test('restore with an entitlement on the store account unlocks it', () async {
    final p = await purchases({Plan.lifetime});
    store.ownedOnStore = true;

    expect(await p.restore(), RestoreResult.restored);
    expect(p.entitled.value, isTrue);
  });

  test('restore without an entitlement says there was nothing to restore', () async {
    final p = await purchases({Plan.lifetime});

    expect(await p.restore(), RestoreResult.nothingToRestore);
    expect(p.entitled.value, isFalse);
  });

  test('restore that cannot reach the store fails, and says so', () async {
    final p = await purchases({Plan.lifetime});
    store.failRestore = true;

    expect(await p.restore(), RestoreResult.failed);
  });
}

class _ThrowingStore extends FakePurchasesBackend {
  @override
  Future<PurchaseResult> buy(String id) async => throw StateError('store crashed');
}
