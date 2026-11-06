import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_example/main.dart';
import 'package:kit_example/notes.dart';

void main() {
  test('the sample app sells its plans through the kit, only after its first useful moment', () async {
    final dir = Directory.systemTemp.createTempSync('example_purchases_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final kit = KitStateController(directory: dir, appId: notesAppId);
    await kit.load();
    final sent = FakeAnalyticsBackend();
    final analytics = Analytics(
      backend: sent,
      kitState: kit,
      appId: notesAppId,
      appVersion: '0.1.0',
      locale: () => 'en',
    );
    final purchases = Purchases(backend: FakePurchasesBackend(), analytics: analytics, plans: exampleConfig.plans);
    final gate = PaywallGate(kit);

    expect(gate.canShow('settings'), isFalse);
    await kit.update((s) => s.copyWith(onboardingCompleted: true));
    await gate.markFirstValue(); // in a real app: the first note saved
    expect(gate.canShow('settings'), isTrue);

    final lifetime = (await purchases.offers()).last;
    expect(await purchases.buy(lifetime), isA<Purchased>());
    expect(purchases.entitled.value, isTrue);
    await analytics.idle;
    expect(sent.events.single.name, 'purchase.complete.lifetime');
  });
}
