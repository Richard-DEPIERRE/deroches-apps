import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late KitStateController kit;
  late FakeAnalyticsBackend backend;
  var now = DateTime.utc(2026, 11, 1, 9);

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('analytics_');
    now = DateTime.utc(2026, 11, 1, 9);
    kit = KitStateController(directory: dir, appId: 'carnet-km', now: () => now);
    await kit.load();
    backend = FakeAnalyticsBackend();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Analytics analytics({List<AnalyticsEvent> appEvents = const []}) => Analytics(
    backend: backend,
    kitState: kit,
    appId: 'carnet-km',
    appVersion: '1.2.0',
    locale: () => 'fr',
    appEvents: appEvents,
    now: () => now,
  );

  test('every event carries the whole envelope', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final a = analytics();
    now = DateTime.utc(2026, 11, 4, 9);

    a.track('app.open.cold');
    await a.idle;

    expect(backend.events.single.name, 'app.open.cold');
    expect(backend.events.single.properties, {
      'app_id': 'carnet-km',
      'app_version': '1.2.0',
      'platform': 'ios',
      'locale': 'fr',
      'days_since_install': 3,
    });
  });

  test('properties are numbers, yes/no or the app\'s own choices, added to the envelope', () async {
    final a = analytics();
    a.track('paywall.view.settings', {
      'step': const Prop.number(2),
      'pro': const Prop.flag(false),
      'plan': Prop.choice(Plan.yearly),
    });
    await a.idle;

    final sent = backend.events.single.properties;
    expect(sent['step'], 2);
    expect(sent['pro'], false);
    expect(sent['plan'], 'yearly');
    expect(sent['platform'], 'android');
    expect(sent.keys, containsAll(['app_id', 'app_version', 'platform', 'locale', 'days_since_install']));
  });

  test('a name off the list or badly formed throws, and nothing is sent', () async {
    final a = analytics();
    for (final name in ['paywall.tap.monthly', 'PaywallTapped', 'paywall.tap', 'notes.create.note']) {
      expect(() => a.track(name), throwsArgumentError, reason: name);
    }
    expect(() => a.track('app.open.cold', {'Bad Key': const Prop.number(1)}), throwsArgumentError);
    expect(
      () => a.track('app.open.cold', {'app_id': const Prop.number(1)}),
      throwsArgumentError,
      reason: 'the envelope is the kit\'s',
    );
    await a.idle;
    expect(backend.events, isEmpty);
  });

  test('an app registers its own events', () async {
    final a = analytics(
      appEvents: const [AnalyticsEvent('notes.create.note', readBy: 'dashboard: notes made per day')],
    );
    a.track('notes.create.note');
    await a.idle;
    expect(backend.events.single.name, 'notes.create.note');
    expect(() => analytics(appEvents: const [AnalyticsEvent('Notes', readBy: '')]), throwsArgumentError);
  });

  test('with the switch off nothing is sent and the SDK is not started', () async {
    await kit.update((s) => s.copyWith(analyticsEnabled: false));
    final a = analytics();
    a.track('app.open.cold');
    await a.idle;
    expect(backend.started, isFalse);
    expect(backend.events, isEmpty);
    expect(() => a.track('paywall.tap.monthly'), throwsArgumentError, reason: 'names are still checked');
  });

  test('turning the switch off stops the SDK; turning it on starts it again', () async {
    final a = analytics();
    a.track('app.open.cold');
    await a.idle;
    expect(backend.started, isTrue);

    await kit.update((s) => s.copyWith(analyticsEnabled: false));
    await a.idle;
    expect(backend.started, isFalse, reason: 'stopped at once, not at the next event');
    a.track('support.tap.email');
    await a.idle;
    expect(backend.started, isFalse);

    await kit.update((s) => s.copyWith(analyticsEnabled: true));
    a.track('rating.view.prompt');
    await a.idle;
    expect(backend.started, isTrue);
    expect(backend.events.map((e) => e.name), ['app.open.cold', 'rating.view.prompt']);
  });

  test('nothing is sent before the kit state is loaded', () async {
    final unloaded = KitStateController(directory: dir, appId: 'carnet-km');
    final a = Analytics(
      backend: backend,
      kitState: unloaded,
      appId: 'carnet-km',
      appVersion: '1.2.0',
      locale: () => 'en',
    );
    a.track('app.open.cold');
    await a.idle;
    expect(backend.started, isFalse);
    expect(backend.events, isEmpty);
  });

  test('no backend (no PostHog key, or a debug build) sends nothing but still checks names', () async {
    final a = Analytics(kitState: kit, appId: 'carnet-km', appVersion: '1.2.0', locale: () => 'en');
    a.track('app.open.cold');
    await a.idle;
    expect(() => a.track('paywall.tap.monthly'), throwsArgumentError);
  });

  group('days since install, from the wall clock of the install and of now', () {
    // The platform turns each instant into the device's wall clock
    // (`toLocal()`, with the time-zone rules of that date); these tests give
    // the wall clocks directly.
    DateTime wall(DateTime utc, int hours) => utc.add(Duration(hours: hours));
    final installed = DateTime.utc(2026, 3, 1, 22, 30); // 23:30 in Paris (UTC+1)

    test('0 on the install day, 1 just after midnight', () {
      expect(daysSinceInstall(wall(installed, 1), wall(DateTime.utc(2026, 3, 1, 22, 59), 1)), 0); // 23:59
      expect(daysSinceInstall(wall(installed, 1), wall(DateTime.utc(2026, 3, 1, 23, 1), 1)), 1); // 00:01
      expect(daysSinceInstall(wall(installed, 1), wall(DateTime.utc(2026, 3, 31, 21, 59), 2)), 30);
    });

    test('after a time-zone change, counted on the device\'s new calendar', () {
      // Flown to New York: the install was at 17:30 on 1 March there, and the
      // instant that is 00:01 in Paris is still 1 March.
      expect(daysSinceInstall(wall(installed, -5), wall(DateTime.utc(2026, 3, 1, 23, 1), -5)), 0);
      expect(daysSinceInstall(wall(installed, -5), wall(DateTime.utc(2026, 3, 2, 5, 1), -5)), 1); // 00:01 in New York
    });

    test('across a daylight-saving change', () {
      // Paris moves to UTC+2 on 29 March 2026: 00:30 on 30 March is day 29.
      expect(daysSinceInstall(wall(installed, 1), wall(DateTime.utc(2026, 3, 29, 22, 30), 2)), 29);
    });

    test('never negative, if the clock goes back', () {
      expect(daysSinceInstall(wall(installed, 1), DateTime.utc(2026, 2, 27)), 0);
    });
  });
}
