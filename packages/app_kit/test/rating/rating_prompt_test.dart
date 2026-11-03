import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late KitStateController kit;
  late FakeStoreReview review;
  late FakeAnalyticsBackend backend;
  late Analytics analytics;

  RatingPrompt prompt({int goodMoments = 1}) =>
      RatingPrompt(kitState: kit, review: review, analytics: analytics, goodMoments: goodMoments, now: () => now);

  setUp(() async {
    final dir = Directory.systemTemp.createTempSync('rating_');
    addTearDown(() => dir.deleteSync(recursive: true));
    now = DateTime(2026, 1, 10, 10); // installed on the 10th, 10:00 on the device
    kit = KitStateController(directory: dir, appId: 'kit-test', now: () => now);
    await kit.load();
    await kit.update((s) => s.copyWith(onboardingCompleted: true));
    review = FakeStoreReview();
    backend = FakeAnalyticsBackend();
    analytics = Analytics(backend: backend, kitState: kit, appId: 'kit-test', appVersion: '1.0.0', locale: () => 'en');
  });

  test('not on day 2, from day 3 after install', () async {
    final rating = prompt();
    now = DateTime(2026, 1, 12, 23, 59);
    expect(await rating.goodMoment(), isFalse);
    expect(review.requests, 0);

    now = DateTime(2026, 1, 13);
    expect(await rating.goodMoment(), isTrue);
    expect(review.requests, 1);
  });

  test('only after the app\'s threshold of good moments', () async {
    final rating = prompt(goodMoments: 3);
    now = DateTime(2026, 1, 20);
    expect([await rating.goodMoment(), await rating.goodMoment()], [false, false]);
    expect(await rating.goodMoment(), isTrue);
    expect(review.requests, 1);
  });

  test('at most once every 120 days, and each request is recorded', () async {
    final rating = prompt();
    final first = DateTime(2026, 1, 13, 9);
    now = first;
    expect(await rating.goodMoment(), isTrue);
    expect(kit.state!.ratingPrompts, [first.toUtc()]);

    now = first.add(const Duration(days: 119));
    expect(await rating.goodMoment(), isFalse);

    now = first.add(const Duration(days: 120));
    expect(await rating.goodMoment(), isTrue);
    expect(review.requests, 2);
    expect(kit.state!.ratingPrompts, hasLength(2));
  });

  test('nothing is asked before onboarding is complete', () async {
    await kit.update((s) => s.copyWith(onboardingCompleted: false));
    now = DateTime(2026, 3, 1);
    expect(await prompt().goodMoment(), isFalse);
    expect(review.requests, 0);
    expect(kit.state!.ratingPrompts, isEmpty);
  });

  test('sends rating.view.prompt when it asks, and only then', () async {
    final rating = prompt();
    now = DateTime(2026, 1, 11);
    await rating.goodMoment();
    now = DateTime(2026, 1, 13);
    await rating.goodMoment();
    await analytics.idle;
    expect(backend.events.map((e) => e.name), ['rating.view.prompt']);
  });

  test('a platform without the store prompt breaks nothing', () async {
    review.available = false;
    now = DateTime(2026, 1, 13);
    await prompt().goodMoment();
    expect(review.requests, 0);
  });
}
