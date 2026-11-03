import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/kit_state.dart';
import 'events.dart';

/// A property value: a number, a yes/no, or one of the app's own enum values.
/// Never text, so nothing the user typed or made can reach an event.
extension type const Prop._(Object value) {
  const Prop.number(num number) : value = number;
  const Prop.flag(bool flag) : value = flag;
  Prop.choice(Enum choice) : value = choice.name;
}

/// Where checked events go: PostHog in a release build (its backend is the
/// next kit issue), `FakeAnalyticsBackend` from `package:app_kit/testing.dart`
/// in tests.
abstract interface class AnalyticsBackend {
  Future<void> start();
  Future<void> stop();
  Future<void> capture(String event, Map<String, Object> properties);
}

/// The only way an app sends analytics (ADR 0001, section 5).
///
/// Checks each name against [kitEvents] and the app's own events, adds the
/// envelope, and sends only while the kit state's analytics switch is on: the
/// backend starts on the first event sent and stops as soon as the switch
/// goes off. A bad name or property key throws in debug builds and tests, and
/// is dropped in release builds.
class Analytics {
  Analytics({
    this.backend,
    required KitStateController kitState,
    required this.appId,
    required this.appVersion,
    required this._locale,
    List<AnalyticsEvent> appEvents = const [],
    this._now = DateTime.now,
  }) : _kitState = kitState,
       _events = [...kitEvents, ...appEvents] {
    final problems = [for (final e in appEvents) ...e.problems];
    if (problems.isNotEmpty) throw ArgumentError('bad app events: ${problems.join('; ')}');
    kitState.addListener(_stopWhenOff);
  }

  /// `null` sends nothing (no PostHog key, or a debug build); names are still checked.
  final AnalyticsBackend? backend;
  final String appId;
  final String appVersion;
  final KitStateController _kitState;
  final String Function() _locale;
  final DateTime Function() _now;
  final List<AnalyticsEvent> _events;

  static final _key = RegExp(r'^[a-z][a-z0-9_]*$');
  static const _envelope = {'app_id', 'app_version', 'platform', 'locale', 'days_since_install'};

  bool _started = false;
  Future<void> _pending = Future.value();

  /// Completes when every event tracked so far has reached the backend.
  @visibleForTesting
  Future<void> get idle => _pending;

  bool get _on => backend != null && (_kitState.state?.analyticsEnabled ?? false);

  void track(String event, [Map<String, Prop> properties = const {}]) {
    if (!_events.any((e) => e.matches(event))) {
      return _reject('"$event" is not on the event list (kit or app), or is not category.action.detail');
    }
    for (final key in properties.keys) {
      if (!_key.hasMatch(key) || _envelope.contains(key)) return _reject('bad property key "$key" on "$event"');
    }
    if (!_on) return;
    final backend = this.backend!;
    final sent = <String, Object>{
      'app_id': appId,
      'app_version': appVersion,
      'platform': defaultTargetPlatform.name.toLowerCase(),
      'locale': _locale(),
      'days_since_install': daysSinceInstall(_kitState.state!.installedAt.toLocal(), _now().toLocal()),
      for (final MapEntry(:key, :value) in properties.entries) key: value.value,
    };
    if (!_started) {
      _started = true;
      _then(backend.start);
    }
    _then(() => backend.capture(event, sent));
  }

  void _stopWhenOff() {
    if (_started && !_on) {
      _started = false;
      _then(backend!.stop);
    }
  }

  // In order, one after the other; analytics never breaks the app.
  void _then(Future<void> Function() step) =>
      _pending = _pending.then((_) => step()).catchError((Object e) => debugPrint('analytics: $e'));

  void _reject(String why) {
    if (kDebugMode) throw ArgumentError(why);
  }
}

/// Whole calendar days from the install to now, both read on the device's
/// wall clock (`toLocal()`): 0 on the install day, 1 from the next midnight.
/// Never negative.
int daysSinceInstall(DateTime installed, DateTime now) {
  DateTime day(DateTime t) => DateTime.utc(t.year, t.month, t.day);
  return max(0, day(now).difference(day(installed)).inDays);
}
