import 'package:app_kit/app_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every kit event is well formed and says who reads it', () {
    for (final event in kitEvents) {
      expect(event.problems, isEmpty, reason: event.pattern);
    }
    expect(kitEvents.map((e) => e.pattern).toSet().length, kitEvents.length, reason: 'no event twice');
  });

  test('the starting list is there', () {
    for (final name in [
      'app.open.cold',
      'onboarding.complete.finished',
      'onboarding.dismiss.skipped',
      'paywall.view.settings',
      'paywall.tap.weekly',
      'paywall.tap.yearly',
      'paywall.tap.lifetime',
      'paywall.tap.restore',
      'paywall.dismiss.settings',
      'purchase.complete.weekly',
      'purchase.complete.yearly',
      'purchase.complete.lifetime',
      'purchase.fail.cancelled',
      'backup.complete.export',
      'backup.complete.restore',
      'backup.fail.unreadable_file',
      'rating.view.prompt',
      'support.tap.email',
    ]) {
      expect(kitEvents.any((e) => e.matches(name)), isTrue, reason: name);
    }
  });

  test('names off the list or badly formed match nothing', () {
    for (final name in [
      'paywall.tap.monthly',
      'purchase.complete.monthly',
      'backup.complete.icloud',
      'app.open.warm',
      'paywall.tap',
      'paywall.tap.yearly.extra',
      'Paywall.Tap.Yearly',
      'paywall-tap.yearly.x',
      'paywall.view.',
      'paywall.view.Home Screen',
      'notes.create.note',
    ]) {
      expect(kitEvents.any((e) => e.matches(name)), isFalse, reason: name);
    }
  });

  test('a badly written event or one without a reader is reported', () {
    expect(const AnalyticsEvent('notes.create.note', readBy: '').problems, isNotEmpty);
    expect(const AnalyticsEvent('notes.Create.note', readBy: 'dashboard').problems, isNotEmpty);
    expect(const AnalyticsEvent('notes.create', readBy: 'dashboard').problems, isNotEmpty);
    expect(const AnalyticsEvent('notes.create.a|', readBy: 'dashboard').problems, isNotEmpty);
    expect(const AnalyticsEvent('notes.create.*', readBy: 'dashboard').problems, isEmpty);
    expect(const AnalyticsEvent('notes.create.note|list', readBy: 'dashboard').problems, isEmpty);
  });
}
