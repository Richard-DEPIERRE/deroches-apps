import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('paywall_gate_'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<KitStateController> loadKit() async {
    final kit = KitStateController(directory: dir, appId: 'carnet-km');
    await kit.load();
    return kit;
  }

  test('closed on a fresh install, closed after onboarding alone, open after markFirstValue()', () async {
    final kit = await loadKit();
    final gate = PaywallGate(kit);
    expect(gate.canShow('settings'), isFalse, reason: 'fresh install');

    await kit.update((s) => s.copyWith(onboardingCompleted: true));
    expect(gate.canShow('settings'), isFalse, reason: 'onboarding alone');

    await gate.markFirstValue();
    expect(gate.canShow('settings'), isTrue);
  });

  test('closed when the first useful moment came before onboarding was complete', () async {
    final gate = PaywallGate(await loadKit());
    await gate.markFirstValue();
    expect(gate.canShow('settings'), isFalse);
  });

  test('both steps are saved in the kit state document', () async {
    final kit = await loadKit();
    await kit.update((s) => s.copyWith(onboardingCompleted: true));
    await PaywallGate(kit).markFirstValue();

    expect(PaywallGate(await loadKit()).canShow('settings'), isTrue, reason: 'after a restart');
  });

  test('closed while the kit state is not loaded', () {
    final gate = PaywallGate(KitStateController(directory: dir, appId: 'carnet-km'));
    expect(gate.canShow('settings'), isFalse);
  });

  test('a placement must be an analytics detail, since it becomes paywall.view.<placement>', () async {
    final gate = PaywallGate(await loadKit());
    expect(() => gate.canShow('Settings screen'), throwsArgumentError);
  });
}
