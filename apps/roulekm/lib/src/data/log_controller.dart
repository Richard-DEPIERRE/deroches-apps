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
  Future<void> saveVehicle(VehicleRecord vehicle) => _save((vehicles) {
    final i = vehicles.indexWhere((v) => v.id == vehicle.id);
    return i < 0 ? [...vehicles, vehicle] : (List.of(vehicles)..[i] = vehicle);
  });

  /// Archiving keeps the vehicle's trips and totals; `archived: false` brings it back (Undo).
  Future<void> archiveVehicle(String id, {bool archived = true}) =>
      _save((vehicles) => [for (final v in vehicles) v.id == id ? v.copyWith(archived: archived) : v]);

  /// The last save in line: the next one starts once it is done, so a rollback never undoes a later change.
  Future<void> _saving = Future.value();

  Future<void> _save(List<VehicleRecord> Function(List<VehicleRecord>) change) {
    final done = _saving.then((_) async {
      final previous = logbook!;
      final next = Logbook(
        vehicles: change(previous.vehicles),
        trips: previous.trips,
        favourites: previous.favourites,
        recurring: previous.recurring,
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
