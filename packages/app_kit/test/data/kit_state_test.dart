import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('kit_state_'));
  tearDown(() => dir.deleteSync(recursive: true));

  var today = DateTime.utc(2026, 11, 1);
  KitStateController controller() =>
      KitStateController(directory: dir, appId: 'carnet-km', now: () => today);

  test('the defaults on a first launch', () async {
    final kit = controller();
    expect(kit.loading, isTrue);
    await kit.load();

    final state = kit.state!;
    expect(state.installedAt, DateTime.utc(2026, 11, 1));
    expect(state.onboardingCompleted, isFalse);
    expect(state.firstValueReached, isFalse);
    expect(state.languageOverride, isNull);
    expect(state.analyticsEnabled, isTrue);
    expect(state.ratingPrompts, isEmpty);
    expect(File('${dir.path}/kit.json').existsSync(), isTrue, reason: 'the install date is kept');
  });

  test('changes are saved and read back on the next launch', () async {
    final kit = controller();
    await kit.load();
    await kit.update(
      (s) => s.copyWith(
        onboardingCompleted: true,
        firstValueReached: true,
        languageOverride: 'fr',
        analyticsEnabled: false,
        ratingPrompts: [DateTime.utc(2026, 11, 4)],
      ),
    );

    today = DateTime.utc(2027, 1, 1);
    final next = controller();
    await next.load();
    expect(next.state, kit.state);
    expect(next.state!.installedAt, DateTime.utc(2026, 11, 1));
  });

  test('clearing the language override goes back to the device language', () async {
    final kit = controller();
    await kit.load();
    await kit.update((s) => s.copyWith(languageOverride: 'en'));
    await kit.update((s) => s.copyWith(clearLanguageOverride: true));
    expect(kit.state!.languageOverride, isNull);
  });

  test('a corrupt kit document is an error state, and nothing is saved over it', () async {
    final file = File('${dir.path}/kit.json')..writeAsStringSync('not json');
    final kit = controller();
    await kit.load();

    expect(kit.state, isNull);
    expect(kit.error, isA<DataException>());
    await expectLater(kit.update((s) => s), throwsStateError);
    expect(file.readAsStringSync(), 'not json');
  });

  test('two updates without an await both stay, in memory and on disk', () async {
    final kit = controller();
    await kit.load();
    final first = kit.update((s) => s.copyWith(analyticsEnabled: false));
    final second = kit.update((s) => s.copyWith(ratingPrompts: [...s.ratingPrompts, today]));
    await Future.wait([first, second]);

    final expected = kit.state!;
    expect(expected.analyticsEnabled, isFalse);
    expect(expected.ratingPrompts, [today]);
    final next = controller();
    await next.load();
    expect(next.state, expected);
  });

  test('the rating prompt history cannot be changed in place', () async {
    final kit = controller();
    await kit.load();
    final copied = kit.state!.copyWith(ratingPrompts: [today]);
    expect(() => copied.ratingPrompts.add(today), throwsUnsupportedError);
    final read = KitState.fromJson(copied.toJson());
    expect(() => read.ratingPrompts.add(today), throwsUnsupportedError);
  });

  test('a successful reload clears an earlier error', () async {
    final file = File('${dir.path}/kit.json')..writeAsStringSync('not json');
    final kit = controller();
    await kit.load();
    expect(kit.error, isNotNull);

    file.deleteSync();
    await kit.load();
    expect(kit.state, isNotNull);
    expect(kit.error, isNull);
  });
}
