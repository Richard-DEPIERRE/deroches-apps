import 'dart:async';
import 'dart:io';

import 'package:app_kit/app_kit.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/data/log_controller.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/rates/distance.dart';
import 'package:roulekm/src/rates/french_bareme.dart';
import 'package:roulekm/src/rates/rates.dart';

import '../data_upgrade/sample.dart';

void main() {
  late Directory dir;
  late RoulekmData data;
  late LogController log;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('roulekm_log_');
    data = RoulekmData(dir);
    log = LogController(data.log);
    await log.open();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  const clio = VehicleRecord(id: 'v1', name: 'Clio', rates: RateSystem.france, type: VehicleType.car, horsepower: 5);

  test('a new install opens an empty logbook, with no vehicle in use', () {
    expect(log.logbook, const Logbook());
    expect(log.inUse, isEmpty);
  });

  test('a vehicle saved is in use, and still there when the log is opened again', () async {
    await log.saveVehicle(clio);
    expect(log.inUse, [clio]);

    final reopened = LogController(RoulekmData(dir).log);
    await reopened.open();
    expect(reopened.logbook!.vehicles, [clio]);
  });

  test('saving a vehicle again replaces it in place and keeps its trips', () async {
    await data.log.replace(schema1Logbook.toJson());
    await log.open();
    const edited = VehicleRecord(
      id: 'v1',
      name: 'Clio V',
      rates: RateSystem.france,
      type: VehicleType.car,
      horsepower: 4,
    );
    await log.saveVehicle(edited);
    expect(log.logbook!.vehicles.map((v) => v.name), ['Clio V', 'Zoé', 'Pickup']);
    expect(log.logbook!.trips, schema1Logbook.trips);
  });

  test('an archived vehicle is no longer in use and keeps its trips', () async {
    await data.log.replace(schema1Logbook.toJson());
    await log.open();
    expect(log.inUse.map((v) => v.id), ['v1', 'v3'], reason: 'v2 is archived in the sample');

    await log.archiveVehicle('v1');
    expect(log.inUse.map((v) => v.id), ['v3']);
    expect(log.logbook!.vehicles.firstWhere((v) => v.id == 'v1').archived, isTrue);
    expect(log.logbook!.trips, schema1Logbook.trips);
  });

  test('an archived vehicle can be brought back as it was (Undo)', () async {
    await data.log.replace(schema1Logbook.toJson());
    await log.open();
    await log.archiveVehicle('v1');
    await log.archiveVehicle('v1', archived: false);
    expect(log.logbook, schema1Logbook);
  });

  test('a save that fails leaves the logbook as it was and says so', () async {
    await data.log.replace(const Logbook().toJson()); // a restore: saving is refused until opened again
    await expectLater(log.saveVehicle(clio), throwsStateError);
    expect(log.logbook, const Logbook());
  });

  test('a save that fails while the next waits takes back only its own change', () async {
    final store = _HeldStore(dir);
    final held = LogController(store);
    await held.open();
    final first = held.saveVehicle(clio);
    final second = held.saveVehicle(
      const VehicleRecord(id: 'v2', name: 'Kangoo', rates: RateSystem.us, type: VehicleType.car),
    );
    await pumpEventQueue();
    expect(store.writes, hasLength(1), reason: 'the second save waits for the first');
    store.writes.first.completeError(StateError('disk full'));
    await expectLater(first, throwsStateError);
    await pumpEventQueue();
    store.writes.last.complete();
    await second;
    expect(held.logbook!.vehicles.map((v) => v.name), ['Kangoo']);
    expect(store.saved.last, held.logbook!.toJson(), reason: 'what is on disk is what is shown');
  });

  test('a trip is added, edited in place and deleted, and saved each time', () async {
    await log.saveVehicle(clio);
    final trip = TripRecord(
      id: 't1',
      date: DateTime.utc(2026, 11, 3),
      route: const TripRoute(
        from: 'A',
        to: 'B',
        purpose: 'P',
        distance: Distance(34, DistanceUnit.km),
        vehicleId: 'v1',
      ),
    );
    await log.saveTrip(trip);
    final edited = TripRecord(id: 't1', date: trip.date, route: trip.route, odometerStart: 10, odometerEnd: 44);
    await log.saveTrip(edited);
    expect(log.logbook!.trips, [edited]);
    final reopened = LogController(RoulekmData(dir).log);
    await reopened.open();
    expect(reopened.logbook!.trips, [edited]);

    await log.deleteTrip('t1');
    expect(log.logbook!.trips, isEmpty);
    expect(log.logbook!.vehicles, [clio]);
  });

  test('new ids are unique', () {
    expect({for (var i = 0; i < 100; i++) newId()}, hasLength(100));
  });

  test('a favourite saved is still there when the log is opened again, and a deleted one is gone', () async {
    const route = TripRoute(from: 'A', to: 'B', purpose: 'P', distance: Distance(3, DistanceUnit.km), vehicleId: 'v1');
    await log.saveFavourite(const FavouriteTrip(id: 'f1', route: route));
    await log.saveFavourite(const FavouriteTrip(id: 'f2', route: route));
    await log.deleteFavourite('f1');

    final reopened = LogController(RoulekmData(dir).log);
    await reopened.open();
    expect(reopened.logbook!.favourites, [const FavouriteTrip(id: 'f2', route: route)]);
  });

  group('a recurring pattern', () {
    const route = TripRoute(from: 'A', to: 'B', purpose: 'P', distance: Distance(34, DistanceUnit.km), vehicleId: 'v1');
    final weekdays = RecurringTrip(
      id: 'r1',
      route: route,
      weekdays: const [1, 2, 3, 4, 5],
      startDate: DateTime.utc(2026, 11, 2),
    );

    test('is saved, replaced in place and deleted, and fills nothing by itself', () async {
      await log.saveRecurring(weekdays);
      final paused = RecurringTrip(
        id: 'r1',
        route: route,
        weekdays: const [1],
        startDate: weekdays.startDate,
        paused: true,
      );
      await log.saveRecurring(paused);
      final reopened = LogController(RoulekmData(dir).log);
      await reopened.open();
      expect(reopened.logbook!.recurring, [paused]);
      expect(reopened.logbook!.trips, isEmpty);

      await log.deleteRecurring('r1');
      expect(log.logbook!.recurring, isEmpty);
    });

    test('confirming adds one trip per day picked, skips the others, and offers no day twice', () async {
      await log.saveRecurring(weekdays);
      final friday = DateTime(2026, 11, 6, 18);
      final waiting = log.logbook!.recurring.single.waitingDays(friday);
      expect(waiting, hasLength(5));

      // Wednesday was a day off.
      await log.confirmRecurring('r1', [waiting[0], waiting[1], waiting[3], waiting[4]], through: waiting.last);
      final trips = log.logbook!.trips;
      expect([for (final t in trips) t.date.day], [2, 3, 5, 6]);
      expect(trips.every((t) => t.route == route && t.odometerStart == null), isTrue);
      expect({for (final t in trips) t.id}, hasLength(4));
      expect(log.logbook!.recurring.single.checkedThrough, DateTime.utc(2026, 11, 6));
      expect(log.logbook!.recurring.single.waitingDays(friday), isEmpty);

      final reopened = LogController(RoulekmData(dir).log);
      await reopened.open();
      expect(reopened.logbook, log.logbook, reason: 'trips and the checked-through day are saved together');
    });

    test('skipping every day adds no trip and the days never come back', () async {
      await log.saveRecurring(weekdays);
      await log.confirmRecurring('r1', const [], through: DateTime.utc(2026, 11, 6));
      expect(log.logbook!.trips, isEmpty);
      expect(log.logbook!.recurring.single.waitingDays(DateTime(2026, 11, 9)), [DateTime.utc(2026, 11, 9)]);
    });
  });

  test('there is no trip limit: a year of daily trips at once, then one more', () async {
    final daily = RecurringTrip(
      id: 'r1',
      route: const TripRoute(from: 'A', to: 'B', purpose: 'P', distance: Distance(5, DistanceUnit.km), vehicleId: 'v1'),
      weekdays: const [1, 2, 3, 4, 5, 6, 7],
      startDate: DateTime.utc(2026),
    );
    await log.saveRecurring(daily);
    await log.confirmRecurring('r1', daily.waitingDays(DateTime(2026, 12, 31)), through: DateTime.utc(2026, 12, 31));
    await log.saveTrip(TripRecord(id: 'last', date: DateTime.utc(2027), route: daily.route));
    expect(log.logbook!.trips, hasLength(366));
  });
}

/// Holds each save until the test completes it.
class _HeldStore extends DataStore {
  _HeldStore(Directory dir)
    : super(
        directory: dir,
        appId: roulekmAppId,
        name: logDocument,
        migrations: logMigrations,
        initial: () => Logbook.empty,
      );

  final writes = <Completer<void>>[];
  final saved = <Map<String, Object?>>[];

  @override
  Future<void> save(Map<String, Object?> data) async {
    writes.add(Completer());
    await writes.last.future;
    saved.add(data);
  }
}
