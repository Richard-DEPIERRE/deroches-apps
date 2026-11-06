/// The kit's event list (ADR 0001, section 5; skill `apps-kit-conventions`, section 2).
library;

final _segment = RegExp(r'^[a-z0-9_]+$');

/// One event, or a family of them, an app may send, and who reads it.
///
/// [pattern] is `category.action.detail`, each segment lowercase `a-z`, `0-9`
/// and `_`. The detail may instead be `a|b|c` (one of these) or `*` (any
/// well-formed detail the code chooses: a placement, a reason; never text the
/// user typed).
class AnalyticsEvent {
  const AnalyticsEvent(this.pattern, {required this.readBy});

  final String pattern;

  /// Who reads it: a funnel, a gate, the dashboard, an epic's expected effect.
  /// No reader, no event.
  final String readBy;

  /// Everything wrong with this entry, in plain words; empty when valid.
  List<String> get problems {
    final parts = pattern.split('.');
    return [
      if (readBy.trim().isEmpty) '"$pattern" says nobody reads it',
      if (parts.length != 3 ||
          !_segment.hasMatch(parts[0]) ||
          !_segment.hasMatch(parts[1]) ||
          (parts[2] != '*' && !parts[2].split('|').every(_segment.hasMatch)))
        '"$pattern" is not category.action.detail in lowercase a-z, 0-9 and _',
    ];
  }

  bool matches(String name) {
    final want = pattern.split('.');
    final got = name.split('.');
    return got.length == 3 &&
        got.every(_segment.hasMatch) &&
        got[0] == want[0] &&
        got[1] == want[1] &&
        (want[2] == '*' || want[2].split('|').contains(got[2]));
  }
}

/// What every app sends through the kit. An app adds its own with
/// `Analytics(appEvents: ...)`; a new kit event comes in the same PR as the
/// code that sends it.
const kitEvents = [
  AnalyticsEvent('app.open.cold', readBy: 'dashboard: active users and retention by days since install'),
  AnalyticsEvent('onboarding.complete.finished', readBy: 'funnel: onboarding'),
  AnalyticsEvent('onboarding.dismiss.skipped', readBy: 'funnel: onboarding'),
  AnalyticsEvent('paywall.view.*', readBy: 'funnel: paywall conversion, by placement (Product Lead)'),
  AnalyticsEvent('paywall.tap.weekly|yearly|lifetime|restore', readBy: 'funnel: paywall conversion, by plan'),
  AnalyticsEvent('paywall.dismiss.*', readBy: 'funnel: paywall conversion, by placement'),
  AnalyticsEvent('purchase.complete.weekly|yearly|lifetime', readBy: 'dashboard: conversion by day since install; funnel: paywall'),
  AnalyticsEvent('purchase.fail.*', readBy: 'dashboard: purchase failures, by reason'),
  AnalyticsEvent('backup.complete.export|restore', readBy: 'dashboard: backup use'),
  AnalyticsEvent('backup.fail.*', readBy: 'dashboard: backup failures, by reason'),
  AnalyticsEvent('rating.view.prompt', readBy: 'dashboard: rating prompts shown, against store ratings'),
  AnalyticsEvent('support.tap.email', readBy: 'dashboard: support contacts, against support emails received'),
];
