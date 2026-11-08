import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/data/log_controller.dart';
import 'package:roulekm/src/data/logbook.dart';
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

  test('new ids are unique', () {
    expect({for (var i = 0; i < 100; i++) newId()}, hasLength(100));
  });
}
