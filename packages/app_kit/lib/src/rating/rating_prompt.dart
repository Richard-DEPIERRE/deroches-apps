import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import '../analytics/analytics.dart';
import '../data/kit_state.dart';

/// The platform's own rating prompt: `InAppStoreReview` in the app,
/// `FakeStoreReview` from `package:app_kit/testing.dart` in tests.
abstract interface class StoreReview {
  Future<bool> isAvailable();
  Future<void> requestReview();
}

/// [StoreReview] through `in_app_review`.
class InAppStoreReview implements StoreReview {
  const InAppStoreReview();

  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();
}

/// Asks for a rating after good moments (ADR 0001, section 10).
///
/// Asks only once onboarding is complete, from day 3 after install, after
/// [goodMoments] good moments since the app started, and at most once every
/// 120 days. Each request is saved in the kit state and sends
/// `rating.view.prompt`; the platform decides whether its prompt shows. Never
/// tie it to a reward or let it gate a feature.
class RatingPrompt {
  RatingPrompt({
    required this._kitState,
    required this.review,
    required this.analytics,
    this.goodMoments = 3,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    if (goodMoments < 1) throw ArgumentError.value(goodMoments, 'goodMoments', 'must be at least 1');
  }

  final KitStateController _kitState;
  final StoreReview review;
  final Analytics analytics;
  final int goodMoments;
  final DateTime Function() _now;
  int _count = 0;

  static const firstDay = 3;
  static const daysBetween = 120;

  /// The app reports a good moment; returns whether the kit asked for a rating.
  Future<bool> goodMoment() async {
    _count++;
    final state = _kitState.state;
    final now = _now();
    final last = state?.ratingPrompts.lastOrNull;
    if (state == null ||
        !state.onboardingCompleted ||
        _count < goodMoments ||
        daysSinceInstall(state.installedAt.toLocal(), now) < firstDay ||
        (last != null && daysSinceInstall(last.toLocal(), now) < daysBetween)) {
      return false;
    }
    _count = 0;
    final saved = _kitState.update((s) => s.copyWith(ratingPrompts: [...s.ratingPrompts, now.toUtc()]));
    analytics.track('rating.view.prompt');
    try {
      if (await review.isAvailable()) await review.requestReview();
    } catch (e) {
      debugPrint('rating: $e'); // the prompt never breaks the app
    }
    await saved;
    return true;
  }
}
