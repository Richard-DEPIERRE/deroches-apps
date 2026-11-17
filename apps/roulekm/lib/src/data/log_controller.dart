import 'dart:math';

import 'package:app_kit/app_kit.dart';
import 'package:flutter/foundation.dart';

import 'logbook.dart';

/// The logbook the screens read and change. Every change is saved at once, one after the other; a save that fails
/// puts the logbook back as it was before that change and throws, so the screen can tell the user.
class LogController extends ChangeNotifier {
  LogController(this._store);

  final DataStore _store;

  /// Null until [open] has read it.
  Logbook? logbook;

  /// Throws a [DataException] when the saved log can't be read: never shows it as empty.
  Future<void> open() async {
    logbook = Logbook.fromJson(await _store.open());
    notifyListeners();
  }

  /// The vehicles in use: archived ones don't count (DAPP-140 §1).
  List<VehicleRecord> get inUse => [...?logbook?.vehicles.where((v) => !v.archived)];

  /// Adds [vehicle], or replaces the one with its id in place.
  Future<void> saveVehicle(VehicleRecord vehicle) =>
      _save(vehicles: (vehicles) => _put(vehicles, vehicle, (v) => v.id));

  /// Archiving keeps the vehicle's trips and totals; `archived: false` brings it back (Undo).
  Future<void> archiveVehicle(String id, {bool archived = true}) =>
      _save(vehicles: (vehicles) => [for (final v in vehicles) v.id == id ? v.copyWith(archived: archived) : v]);

  /// Adds [trip], or replaces the one with its id in place.
  Future<void> saveTrip(TripRecord trip) => _save(trips: (trips) => _put(trips, trip, (t) => t.id));

  Future<void> deleteTrip(String id) => _save(trips: (trips) => [...trips.where((t) => t.id != id)]);

  /// Adds [favourite], or replaces the one with its id in place.
  Future<void> saveFavourite(FavouriteTrip favourite) =>
      _save(favourites: (favourites) => _put(favourites, favourite, (f) => f.id));

  Future<void> deleteFavourite(String id) =>
      _save(favourites: (favourites) => [...favourites.where((f) => f.id != id)]);

  /// Adds [pattern], or replaces the one with its id in place; [at] puts a deleted one back where it was (Undo). It
  /// fills nothing by itself: see [confirmRecurring].
  Future<void> saveRecurring(RecurringTrip pattern, {int? at}) => _save(
    recurring: (recurring) => at == null || recurring.any((r) => r.id == pattern.id)
        ? _put(recurring, pattern, (r) => r.id)
        : (List.of(recurring)..insert(min(at, recurring.length), pattern)),
  );

  Future<void> deleteRecurring(String id) => _save(recurring: (recurring) => [...recurring.where((r) => r.id != id)]);

  /// Pattern [id]'s new days; the days already confirmed or skipped stay so.
  Future<void> editRecurring(String id, List<int> weekdays) =>
      _save(recurring: (recurring) => [for (final r in recurring) r.id == id ? r.copyWith(weekdays: weekdays) : r]);

  /// Pauses pattern [id] on [now]'s day, or resumes it: see [RecurringTrip.pause] and [RecurringTrip.resume]. Resuming
  /// one that isn't paused (a double tap) changes nothing.
  Future<void> pauseRecurring(String id, {required bool paused, required DateTime now}) => _save(
    recurring: (recurring) => [
      for (final r in recurring)
        if (r.id != id || r.paused == paused) r else paused ? r.pause(now) : r.resume(now),
    ],
  );

  /// Adds one trip on pattern [id]'s route for each of [days], and marks every day through [through] as seen, in
  /// one save: a confirmed or skipped day is never offered again. Decided in the save queue, against the pattern as
  /// the earlier saves left it, so a second confirm of the same days (a double tap) adds nothing. Completes with the
  /// new trips' ids, for Undo; null when every day was already seen and nothing changed.
  Future<List<String>?> confirmRecurring(String id, List<DateTime> days, {required DateTime through}) async {
    List<String>? added;
    await _save(
      // Runs before `recurring` below, while [logbook] is still the logbook this save starts from.
      trips: (trips) {
        final pattern = logbook!.recurring.firstWhere((r) => r.id == id);
        final seen = pattern.checkedThrough;
        if (seen != null && !seen.isBefore(through)) return trips;
        final fresh = [
          for (final d in days)
            if (seen == null || d.isAfter(seen)) TripRecord(id: newId(), date: d, route: pattern.route),
        ];
        added = [for (final t in fresh) t.id];
        return [...trips, ...fresh];
      },
      recurring: (recurring) => [
        for (final r in recurring) r.id == id && added != null ? r.copyWith(checkedThrough: through) : r,
      ],
    );
    return added;
  }

  /// Undo for [confirmRecurring], in one save: removes the trips [tripIds] and puts back each pattern's
  /// [checkedThrough] (by pattern id), so its days wait again.
  Future<void> undoConfirm(List<String> tripIds, Map<String, DateTime?> checkedThrough) => _save(
    trips: (trips) => [...trips.where((t) => !tripIds.contains(t.id))],
    recurring: (recurring) => [
      for (final r in recurring) checkedThrough.containsKey(r.id) ? r.withCheckedThrough(checkedThrough[r.id]) : r,
    ],
  );

  static List<T> _put<T>(List<T> items, T item, String Function(T) id) {
    final i = items.indexWhere((e) => id(e) == id(item));
    return i < 0 ? [...items, item] : (List.of(items)..[i] = item);
  }

  /// The last save in line: the next one starts once it is done, so a rollback never undoes a later change.
  Future<void> _saving = Future.value();

  Future<void> _save({
    List<VehicleRecord> Function(List<VehicleRecord>)? vehicles,
    List<TripRecord> Function(List<TripRecord>)? trips,
    List<FavouriteTrip> Function(List<FavouriteTrip>)? favourites,
    List<RecurringTrip> Function(List<RecurringTrip>)? recurring,
  }) {
    final done = _saving.then((_) async {
      final previous = logbook!;
      final next = Logbook(
        vehicles: vehicles?.call(previous.vehicles) ?? previous.vehicles,
        trips: trips?.call(previous.trips) ?? previous.trips,
        favourites: favourites?.call(previous.favourites) ?? previous.favourites,
        recurring: recurring?.call(previous.recurring) ?? previous.recurring,
      );
      logbook = next;
      notifyListeners();
      try {
        await _store.save(next.toJson());
      } catch (_) {
        logbook = previous;
        notifyListeners();
        rethrow;
      }
    });
    _saving = done.onError((_, _) {});
    return done;
  }
}

final _random = Random.secure();

/// A random id for a new record: 16 hex digits.
String newId() => [for (var i = 0; i < 8; i++) _random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
