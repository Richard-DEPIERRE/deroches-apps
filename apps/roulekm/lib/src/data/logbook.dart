/// What Roulekm saves on the phone: one versioned JSON document, `log`, in the kit's envelope (ADR 0001, section 8).
///
/// Schema 2. A change to any `toJson` below is a new schema: its migration in [logMigrations], a fixture of the old
/// one under `test/data_upgrade/fixtures/`, and the upgrade test, in the same PR.
library;

import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:flutter/foundation.dart';

import '../rates/distance.dart';
import '../rates/french_bareme.dart';
import '../rates/rates.dart';

const roulekmAppId = 'roulekm';
const logDocument = 'log';

/// The log is at schema `logMigrations.length + 1` = 2.
const List<Migration> logMigrations = [_pauseDays];

/// Schema 2 (DAPP-297): a recurring trip keeps the day its pause began and the days its pauses skipped.
Map<String, Object?> _pauseDays(Map<String, Object?> data) => {
  ...data,
  'recurring': [
    for (final r in (data['recurring']! as List).cast<Map<String, Object?>>())
      {...r, 'paused_from': null, 'skipped': <Object?>[]},
  ],
};

/// The app's data, made once at start-up in `getApplicationSupportDirectory()`. The screens and the [backup] share
/// this one [DataStore]: after a restore it refuses to save until opened again, so a stale log can't overwrite it.
class RoulekmData {
  RoulekmData(Directory directory, {BackupFiles files = const SystemBackupFiles()})
    : log = DataStore(
        directory: directory,
        appId: roulekmAppId,
        name: logDocument,
        migrations: logMigrations,
        initial: () => Logbook.empty,
      ) {
    backup = BackupService(appId: roulekmAppId, stores: [log], files: files);
  }

  final DataStore log;
  late final BackupService backup;
}

/// Value equality from [props], so a decoded log can be compared item by item.
@immutable
abstract class _Value {
  const _Value();

  List<Object?> get props;

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType && listEquals((other as _Value).props, props);

  @override
  int get hashCode => Object.hashAll(props);

  @override
  String toString() => '$runtimeType$props';
}

class Logbook extends _Value {
  const Logbook({
    this.vehicles = const [],
    this.trips = const [],
    this.favourites = const [],
    this.recurring = const [],
  });

  static const Map<String, Object?> empty = {'vehicles': [], 'trips': [], 'favourites': [], 'recurring': []};

  final List<VehicleRecord> vehicles;
  final List<TripRecord> trips;
  final List<FavouriteTrip> favourites;
  final List<RecurringTrip> recurring;

  factory Logbook.fromJson(Map<String, Object?> json) {
    List<T> list<T>(String key, T Function(Map<String, Object?>) item) => [
      for (final e in (json[key]! as List).cast<Map<String, Object?>>()) item(e),
    ];
    return Logbook(
      vehicles: list('vehicles', VehicleRecord.fromJson),
      trips: list('trips', TripRecord.fromJson),
      favourites: list('favourites', FavouriteTrip.fromJson),
      recurring: list('recurring', RecurringTrip.fromJson),
    );
  }

  Map<String, Object?> toJson() => {
    'vehicles': [for (final v in vehicles) v.toJson()],
    'trips': [for (final t in trips) t.toJson()],
    'favourites': [for (final f in favourites) f.toJson()],
    'recurring': [for (final r in recurring) r.toJson()],
  };

  /// The trips, latest day first; on the same day, the one added last first.
  List<TripRecord> get latestFirst => [
    for (final (_, t) in [
      ...trips.indexed,
    ]..sort((a, b) => b.$2.date == a.$2.date ? b.$1 - a.$1 : b.$2.date.compareTo(a.$2.date)))
      t,
  ];

  /// The places the user has typed, latest first, each once: the trip form's suggestions (on the phone only).
  List<String> get places => _distinct([
    for (final t in latestFirst) ...[t.route.from, t.route.to],
    for (final f in favourites) ...[f.route.from, f.route.to],
  ]);

  /// The purposes the user has typed, latest first, each once.
  List<String> get purposes => _distinct([for (final t in latestFirst) t.route.purpose]);

  static List<String> _distinct(Iterable<String> texts) => {
    for (final s in texts.map((s) => s.trim()))
      if (s.isNotEmpty) s,
  }.toList();

  /// Every record, for the data-upgrade test's count and item checks.
  List<Object> get items => [...vehicles, ...trips, ...favourites, ...recurring];

  @override
  List<Object?> get props => items;
}

class VehicleRecord extends _Value {
  const VehicleRecord({
    required this.id,
    required this.name,
    required this.rates,
    required this.type,
    this.horsepower,
    this.electric = false,
    this.archived = false,
  });

  final String id;
  final String name;
  final RateSystem rates;
  final VehicleType type;

  /// Puissance fiscale (CV), France only; null for mopeds and outside France.
  final int? horsepower;
  final bool electric;

  /// Archived vehicles keep their trips and totals and don't count as in use (DAPP-140 §1).
  final bool archived;

  VehicleRecord copyWith({bool? archived}) => VehicleRecord(
    id: id,
    name: name,
    rates: rates,
    type: type,
    horsepower: horsepower,
    electric: electric,
    archived: archived ?? this.archived,
  );

  factory VehicleRecord.fromJson(Map<String, Object?> json) => VehicleRecord(
    id: json['id']! as String,
    name: json['name']! as String,
    rates: RateSystem.values.byName(json['rates']! as String),
    type: VehicleType.values.byName(json['type']! as String),
    horsepower: json['horsepower'] as int?,
    electric: json['electric']! as bool,
    archived: json['archived']! as bool,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'rates': rates.name,
    'type': type.name,
    'horsepower': horsepower,
    'electric': electric,
    'archived': archived,
  };

  @override
  List<Object?> get props => [id, name, rates, type, horsepower, electric, archived];
}

/// What a trip, a favourite and a recurring trip share. Its fields sit flat in their record's JSON.
class TripRoute extends _Value {
  const TripRoute({
    required this.from,
    required this.to,
    required this.purpose,
    required this.distance,
    required this.vehicleId,
    this.roundTrip = false,
  });

  final String from;
  final String to;
  final String purpose;

  /// One way, in the unit it was typed in.
  final Distance distance;
  final String vehicleId;
  final bool roundTrip;

  /// What the trip counts for: both ways for a round trip.
  Distance get counted => roundTrip ? Distance(distance.value * 2, distance.unit) : distance;

  factory TripRoute.fromJson(Map<String, Object?> json) => TripRoute(
    from: json['from']! as String,
    to: json['to']! as String,
    purpose: json['purpose']! as String,
    distance: Distance(json['distance']! as int, DistanceUnit.values.byName(json['unit']! as String)),
    vehicleId: json['vehicle']! as String,
    roundTrip: json['round_trip']! as bool,
  );

  Map<String, Object?> toJson() => {
    'from': from,
    'to': to,
    'purpose': purpose,
    'distance': distance.value,
    'unit': distance.unit.name,
    'vehicle': vehicleId,
    'round_trip': roundTrip,
  };

  @override
  List<Object?> get props => [from, to, purpose, distance.value, distance.unit, vehicleId, roundTrip];
}

class TripRecord extends _Value {
  const TripRecord({required this.id, required this.date, required this.route, this.odometerStart, this.odometerEnd});

  final String id;

  /// A calendar day, as `DateTime.utc(y, m, d)`.
  final DateTime date;
  final TripRoute route;

  /// The readings, when the distance came from the odometer; null when it was typed.
  final int? odometerStart;
  final int? odometerEnd;

  factory TripRecord.fromJson(Map<String, Object?> json) => TripRecord(
    id: json['id']! as String,
    date: _day(json['date']! as String),
    route: TripRoute.fromJson(json),
    odometerStart: json['odometer_start'] as int?,
    odometerEnd: json['odometer_end'] as int?,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'date': _dayJson(date),
    ...route.toJson(),
    'odometer_start': odometerStart,
    'odometer_end': odometerEnd,
  };

  @override
  List<Object?> get props => [id, date, route, odometerStart, odometerEnd];
}

/// The distance between two odometer readings; null until the arrival reading is above the departure one.
int? odometerDistance(int? start, int? end) => start != null && end != null && end > start ? end - start : null;

class FavouriteTrip extends _Value {
  const FavouriteTrip({required this.id, required this.route});

  final String id;
  final TripRoute route;

  factory FavouriteTrip.fromJson(Map<String, Object?> json) =>
      FavouriteTrip(id: json['id']! as String, route: TripRoute.fromJson(json));

  Map<String, Object?> toJson() => {'id': id, ...route.toJson()};

  @override
  List<Object?> get props => [id, route];
}

/// A weekday pattern (Pro). Its days wait on the home screen; nothing is counted until the user confirms.
class RecurringTrip extends _Value {
  const RecurringTrip({
    required this.id,
    required this.route,
    required this.weekdays,
    required this.startDate,
    this.checkedThrough,
    this.paused = false,
    this.pausedFrom,
    this.skipped = const [],
  });

  final String id;
  final TripRoute route;

  /// `DateTime.monday` (1) to `DateTime.sunday` (7), ascending.
  final List<int> weekdays;
  final DateTime startDate;

  /// The last day already confirmed or skipped; null when none was yet.
  final DateTime? checkedThrough;
  final bool paused;

  /// While [paused]: the day the pause began; the days before it still wait. Null when paused before schema 2: then
  /// the pause began on the first day not yet seen.
  final DateTime? pausedFrom;

  /// The days past pauses skipped, first and last day of each: they never wait.
  final List<(DateTime, DateTime)> skipped;

  /// The days waiting for the user's confirmation, oldest first: from [startDate], after [checkedThrough], through
  /// [now]'s day (or the day before the pause), on [weekdays] only, none [skipped]. Calendar days, so a clock change
  /// never adds or drops one.
  List<DateTime> waitingDays(DateTime now) {
    if (paused && pausedFrom == null) return const [];
    final today = _dayOf(now);
    final last = paused && pausedFrom!.isBefore(today.add(_oneDay)) ? pausedFrom!.subtract(_oneDay) : today;
    return [
      for (var d = _firstUnseen; !d.isAfter(last); d = d.add(_oneDay))
        if (weekdays.contains(d.weekday) && !skipped.any((s) => !d.isBefore(s.$1) && !d.isAfter(s.$2))) d,
    ];
  }

  DateTime get _firstUnseen {
    final after = checkedThrough;
    return after == null || after.isBefore(startDate) ? startDate : after.add(_oneDay);
  }

  /// Paused on [now]'s day: the days already waiting still wait, none after.
  RecurringTrip pause(DateTime now) =>
      _with(checkedThrough: checkedThrough, paused: true, pausedFrom: _dayOf(now), skipped: skipped);

  /// Resumed on [now]'s day: the pause's days through yesterday are skipped; the days before it and today wait.
  /// Skipped days the confirmed ones have passed are dropped.
  RecurringTrip resume(DateTime now) {
    final yesterday = _dayOf(now).subtract(_oneDay);
    final from = pausedFrom ?? _firstUnseen;
    final seen = checkedThrough;
    return _with(
      checkedThrough: seen,
      paused: false,
      pausedFrom: null,
      skipped: [
        for (final s in skipped)
          if (seen == null || s.$2.isAfter(seen)) s,
        if (!from.isAfter(yesterday)) (from, yesterday),
      ],
    );
  }

  RecurringTrip copyWith({List<int>? weekdays, DateTime? checkedThrough, bool? paused}) => RecurringTrip(
    id: id,
    route: route,
    weekdays: weekdays ?? this.weekdays,
    startDate: startDate,
    checkedThrough: checkedThrough ?? this.checkedThrough,
    paused: paused ?? this.paused,
    pausedFrom: pausedFrom,
    skipped: skipped,
  );

  /// With [checkedThrough] set as given, null included (Undo of a confirm).
  RecurringTrip withCheckedThrough(DateTime? checkedThrough) =>
      _with(checkedThrough: checkedThrough, paused: paused, pausedFrom: pausedFrom, skipped: skipped);

  RecurringTrip _with({
    required DateTime? checkedThrough,
    required bool paused,
    required DateTime? pausedFrom,
    required List<(DateTime, DateTime)> skipped,
  }) => RecurringTrip(
    id: id,
    route: route,
    weekdays: weekdays,
    startDate: startDate,
    checkedThrough: checkedThrough,
    paused: paused,
    pausedFrom: pausedFrom,
    skipped: skipped,
  );

  factory RecurringTrip.fromJson(Map<String, Object?> json) => RecurringTrip(
    id: json['id']! as String,
    route: TripRoute.fromJson(json),
    weekdays: (json['weekdays']! as List).cast<int>(),
    startDate: _day(json['start_date']! as String),
    checkedThrough: switch (json['checked_through']) {
      final String day => _day(day),
      _ => null,
    },
    paused: json['paused']! as bool,
    pausedFrom: switch (json['paused_from']) {
      final String day => _day(day),
      _ => null,
    },
    skipped: [
      for (final s in (json['skipped']! as List).cast<Map<String, Object?>>())
        (_day(s['from']! as String), _day(s['through']! as String)),
    ],
  );

  Map<String, Object?> toJson() => {
    'id': id,
    ...route.toJson(),
    'weekdays': weekdays,
    'start_date': _dayJson(startDate),
    'checked_through': checkedThrough == null ? null : _dayJson(checkedThrough!),
    'paused': paused,
    'paused_from': pausedFrom == null ? null : _dayJson(pausedFrom!),
    'skipped': [
      for (final (from, through) in skipped) {'from': _dayJson(from), 'through': _dayJson(through)},
    ],
  };

  @override
  List<Object?> get props => [id, route, ...weekdays, startDate, checkedThrough, paused, pausedFrom, ...skipped];
}

const _oneDay = Duration(days: 1);

DateTime _dayOf(DateTime now) => DateTime.utc(now.year, now.month, now.day);

/// `yyyy-mm-dd`: a day has no time zone, so a trip never moves to the day before when the phone travels.
DateTime _day(String json) {
  final [y, m, d] = json.split('-').map(int.parse).toList();
  return DateTime.utc(y, m, d);
}

String _dayJson(DateTime day) => day.toIso8601String().substring(0, 10);
