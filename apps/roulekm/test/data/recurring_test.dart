import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/rates/distance.dart';

void main() {
  const route = TripRoute(
    from: 'Domicile',
    to: 'Chantier Bron',
    purpose: 'Suivi de chantier',
    distance: Distance(34, DistanceUnit.km),
    vehicleId: 'v1',
    roundTrip: true,
  );

  /// Monday to Friday from Monday 2 November 2026, unless told otherwise.
  RecurringTrip pattern({
    List<int> weekdays = const [1, 2, 3, 4, 5],
    DateTime? start,
    DateTime? checkedThrough,
    bool paused = false,
  }) => RecurringTrip(
    id: 'r1',
    route: route,
    weekdays: weekdays,
    startDate: start ?? DateTime.utc(2026, 11, 2),
    checkedThrough: checkedThrough,
    paused: paused,
  );

  List<String> days(List<DateTime> days) => [for (final d in days) d.toIso8601String().substring(0, 10)];

  test('a week: its weekdays through today, the weekend left out', () {
    expect(days(pattern().waitingDays(DateTime(2026, 11, 8, 20))), [
      '2026-11-02',
      '2026-11-03',
      '2026-11-04',
      '2026-11-05',
      '2026-11-06',
    ]);
  });

  test("today's trip waits from the first minute of the day", () {
    expect(days(pattern().waitingDays(DateTime(2026, 11, 4, 0, 1))), ['2026-11-02', '2026-11-03', '2026-11-04']);
  });

  test('across the year end, each day in the year it falls in', () {
    final days_ = pattern(start: DateTime.utc(2026, 12, 28)).waitingDays(DateTime(2027, 1, 5, 9));
    expect(days(days_), [
      '2026-12-28',
      '2026-12-29',
      '2026-12-30',
      '2026-12-31',
      '2027-01-01',
      '2027-01-04',
      '2027-01-05',
    ]);
    expect(days_.every((d) => d.isUtc), isTrue);
  });

  test('one weekday only: every Sunday', () {
    expect(days(pattern(weekdays: [7]).waitingDays(DateTime(2026, 11, 16))), ['2026-11-08', '2026-11-15']);
  });

  test('every day across a daylight-saving change: none added, none dropped', () {
    final every = pattern(weekdays: [1, 2, 3, 4, 5, 6, 7], start: DateTime.utc(2026, 10, 24));
    expect(days(every.waitingDays(DateTime(2026, 10, 27, 12))), [
      '2026-10-24',
      '2026-10-25',
      '2026-10-26',
      '2026-10-27',
    ]);
  });

  test('days already confirmed or skipped never come back', () {
    final checked = pattern(checkedThrough: DateTime.utc(2026, 11, 4));
    expect(days(checked.waitingDays(DateTime(2026, 11, 8))), ['2026-11-05', '2026-11-06']);
    expect(checked.waitingDays(DateTime(2026, 11, 4, 23, 59)), isEmpty);
  });

  test('a start date still to come, or a paused pattern, has no day waiting', () {
    expect(pattern(start: DateTime.utc(2026, 11, 9)).waitingDays(DateTime(2026, 11, 8, 23)), isEmpty);
    expect(pattern(paused: true).waitingDays(DateTime(2026, 11, 8)), isEmpty);
  });

  test('copyWith moves the checked-through day and keeps the rest', () {
    final p = pattern(paused: true);
    final moved = p.copyWith(checkedThrough: DateTime.utc(2026, 11, 6));
    expect(moved.toJson(), {...p.toJson(), 'checked_through': '2026-11-06'});
  });
}
