import 'dart:math';

import 'package:app_kit/app_kit.dart';
import 'package:flutter/foundation.dart';

import 'logbook.dart';

/// The logbook the screens read and change. Every change is saved at once; a save that fails puts the logbook back
/// as it was and throws, so the screen can tell the user.
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
  Future<void> saveVehicle(VehicleRecord vehicle) {
    final vehicles = logbook!.vehicles;
    final i = vehicles.indexWhere((v) => v.id == vehicle.id);
    return _save(_with(vehicles: i < 0 ? [...vehicles, vehicle] : (List.of(vehicles)..[i] = vehicle)));
  }

  /// Archiving keeps the vehicle's trips and totals.
  Future<void> archiveVehicle(String id) => _save(
    _with(
      vehicles: [
        for (final v in logbook!.vehicles)
          v.id != id
              ? v
              : VehicleRecord(
                  id: v.id,
                  name: v.name,
                  rates: v.rates,
                  type: v.type,
                  horsepower: v.horsepower,
                  electric: v.electric,
                  archived: true,
                ),
      ],
    ),
  );

  Logbook _with({required List<VehicleRecord> vehicles}) {
    final l = logbook!;
    return Logbook(vehicles: vehicles, trips: l.trips, favourites: l.favourites, recurring: l.recurring);
  }

  Future<void> _save(Logbook next) async {
    final previous = logbook;
    logbook = next;
    notifyListeners();
    try {
      await _store.save(next.toJson());
    } catch (_) {
      logbook = previous;
      notifyListeners();
      rethrow;
    }
  }
}

final _random = Random.secure();

/// A random id for a new record: 16 hex digits.
String newId() => [for (var i = 0; i < 8; i++) _random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
