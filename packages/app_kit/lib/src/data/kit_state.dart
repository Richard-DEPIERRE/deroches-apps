import 'dart:io';

import 'package:flutter/foundation.dart';

import 'data_store.dart';

/// The kit's own saved state: document `kit`, schema 1 (ADR 0001, section 8).
@immutable
class KitState {
  const KitState({
    required this.installedAt,
    this.onboardingCompleted = false,
    this.firstValueReached = false,
    this.languageOverride,
    this.analyticsEnabled = true,
    this.ratingPrompts = const [],
  });

  /// Day 0 of `days_since_install`.
  final DateTime installedAt;
  final bool onboardingCompleted;

  /// The app reported its first useful moment; the paywall may show after it.
  final bool firstValueReached;

  /// `fr` or `en` chosen in settings; null follows the device.
  final String? languageOverride;

  /// The "share anonymous usage statistics" switch.
  final bool analyticsEnabled;

  /// When the rating prompt was shown, oldest first.
  final List<DateTime> ratingPrompts;

  KitState copyWith({
    bool? onboardingCompleted,
    bool? firstValueReached,
    String? languageOverride,
    bool clearLanguageOverride = false,
    bool? analyticsEnabled,
    List<DateTime>? ratingPrompts,
  }) => KitState(
    installedAt: installedAt,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    firstValueReached: firstValueReached ?? this.firstValueReached,
    languageOverride: clearLanguageOverride ? null : languageOverride ?? this.languageOverride,
    analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
    ratingPrompts: ratingPrompts == null ? this.ratingPrompts : List.unmodifiable(ratingPrompts),
  );

  Map<String, Object?> toJson() => {
    'installed_at': installedAt.toUtc().toIso8601String(),
    'onboarding_completed': onboardingCompleted,
    'first_value_reached': firstValueReached,
    'language_override': languageOverride,
    'analytics_enabled': analyticsEnabled,
    'rating_prompts': [for (final d in ratingPrompts) d.toUtc().toIso8601String()],
  };

  factory KitState.fromJson(Map<String, Object?> json) => KitState(
    installedAt: DateTime.parse(json['installed_at']! as String),
    onboardingCompleted: json['onboarding_completed']! as bool,
    firstValueReached: json['first_value_reached']! as bool,
    languageOverride: json['language_override'] as String?,
    analyticsEnabled: json['analytics_enabled']! as bool,
    ratingPrompts: List.unmodifiable([for (final d in json['rating_prompts']! as List) DateTime.parse(d as String)]),
  );

  @override
  bool operator ==(Object other) =>
      other is KitState &&
      other.installedAt == installedAt &&
      other.onboardingCompleted == onboardingCompleted &&
      other.firstValueReached == firstValueReached &&
      other.languageOverride == languageOverride &&
      other.analyticsEnabled == analyticsEnabled &&
      listEquals(other.ratingPrompts, ratingPrompts);

  @override
  int get hashCode => Object.hash(
    installedAt,
    onboardingCompleted,
    firstValueReached,
    languageOverride,
    analyticsEnabled,
    Object.hashAll(ratingPrompts),
  );
}

/// Loads and saves [KitState]. Loading, ready and error are distinct:
/// [loading], then [state] or [error]. Nothing is saved over a document that
/// failed to open.
class KitStateController extends ChangeNotifier {
  KitStateController({required Directory directory, required String appId, DateTime Function()? now})
    : _now = now ?? DateTime.now,
      _store = DataStore(directory: directory, appId: appId, name: 'kit', initial: () => const {}, now: now);

  final DataStore _store;
  final DateTime Function() _now;

  KitState? state;
  Object? error;
  bool get loading => state == null && error == null;

  Future<void> load() async {
    error = null;
    try {
      final data = await _store.open();
      if (data.isEmpty) {
        state = KitState(installedAt: _now().toUtc());
        await _store.save(state!.toJson());
      } else {
        state = KitState.fromJson(data);
      }
    } catch (e) {
      state = null;
      error = e;
    }
    notifyListeners();
  }

  /// Applies [change] at once and saves the result. Updates may run without
  /// an await: each builds on the last, and [DataStore] writes them in order.
  Future<void> update(KitState Function(KitState) change) async {
    final current = state;
    if (current == null) throw StateError('the kit state is not loaded');
    final next = change(current);
    state = next;
    notifyListeners();
    await _store.save(next.toJson());
  }
}
