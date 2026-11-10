import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/l10n/roulekm_localizations.dart';
import 'package:roulekm/src/data/log_controller.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/rates/french_bareme.dart';
import 'package:roulekm/src/rates/rates.dart';
import 'package:roulekm/src/vehicles/vehicle_screen.dart';

late RoulekmData data;

/// Opens the vehicle form on a phone in [device] (its language and region), over a host screen.
Future<LogController> openForm(
  WidgetTester tester,
  Locale device, {
  VehicleRecord? vehicle,
  Size size = const Size(390, 844),
  double textScale = 1,
  VoidCallback? firstVehicleDone,
}) async {
  final dir = Directory.systemTemp.createTempSync('roulekm_vehicle_');
  addTearDown(() => dir.deleteSync(recursive: true));
  data = RoulekmData(dir);
  final log = LogController(data.log);
  if (vehicle != null) await tester.runAsync(() => data.log.replace(Logbook(vehicles: [vehicle]).toJson()));
  await tester.runAsync(log.open);

  tester.platformDispatcher.localesTestValue = [device];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(device.languageCode),
      localizationsDelegates: RoulekmLocalizations.localizationsDelegates,
      supportedLocales: RoulekmLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => VehicleScreen(log: log, vehicle: vehicle, firstVehicleDone: firstVehicleDone),
              ),
            ),
            child: const Text('host'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('host'));
  await tester.pumpAndSettle();
  return log;
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// Taps [label] and waits until the save is on disk. A save started by a tap runs in the test's fake time, so this
/// pumps while real time passes, as the kit's `waitForKitSaves` does.
Future<void> save(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  var saved = false;
  unawaited(data.log.flush().then((_) => saved = true));
  for (var i = 0; !saved; i++) {
    if (i == 1000) fail('the log was still saving after 10 seconds');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

bool selected(WidgetTester tester, String chip) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, chip)).selected;

void main() {
  testWidgets('in France: the barème, its horsepower bands and +20 % for electric, saved', (tester) async {
    final log = await openForm(tester, const Locale('fr', 'FR'));
    expect(find.text('Nouveau véhicule'), findsOneWidget);
    expect(selected(tester, 'France'), isTrue, reason: 'the default follows the phone’s region');
    for (final chip in [
      'Voiture',
      'Moto',
      'Cyclomoteur',
      '3\u00A0CV et moins',
      '4\u00A0CV',
      '5\u00A0CV',
      '6\u00A0CV',
      '7\u00A0CV et plus',
    ]) {
      expect(find.widgetWithText(ChoiceChip, chip), findsOneWidget, reason: chip);
    }
    expect(find.text('Sur la carte grise, case P.6.'), findsOneWidget);
    expect(find.text('Le barème est majoré de 20\u00a0%.'), findsOneWidget);

    expect(find.text('Pour le reconnaître\u00A0: «\u00A0Clio\u00A0», «\u00A0Utilitaire\u00A0»…'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Nom'), 'Clio');
    await tapText(tester, '5\u00A0CV');
    await tapText(tester, 'Électrique');
    await save(tester, 'Enregistrer');

    expect(find.text('Nouveau véhicule'), findsNothing);
    final [v] = log.inUse;
    expect(
      [v.name, v.rates, v.type, v.horsepower, v.electric, v.archived],
      ['Clio', RateSystem.france, VehicleType.car, 5, true, false],
    );
  });

  testWidgets('in France: nothing is saved without a name and a horsepower', (tester) async {
    final log = await openForm(tester, const Locale('fr', 'FR'));
    await save(tester, 'Enregistrer');
    expect(find.text('Donnez-lui un nom.'), findsOneWidget);
    final error = find.text('Choisissez sa puissance fiscale.');
    final theme = Theme.of(tester.element(error));
    expect(tester.widget<Text>(error).style, theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.error));
    expect(
      find.ancestor(
        of: error,
        matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true),
      ),
      findsOneWidget,
      reason: 'screen readers announce it',
    );
    expect(log.logbook!.vehicles, isEmpty);
  });

  testWidgets('in France: a motorbike has its own bands, a moped none', (tester) async {
    final log = await openForm(tester, const Locale('fr', 'FR'));
    await tapText(tester, 'Moto');
    for (final chip in ['2\u00A0CV et moins', '3 à 5\u00A0CV', '6\u00A0CV et plus']) {
      expect(find.widgetWithText(ChoiceChip, chip), findsOneWidget, reason: chip);
    }
    expect(find.text('3\u00A0CV et moins'), findsNothing);

    await tapText(tester, 'Cyclomoteur');
    expect(find.textContaining('\u00A0CV'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Nom'), 'Booster');
    await save(tester, 'Enregistrer');
    expect([log.inUse.single.type, log.inUse.single.horsepower], [VehicleType.moped, null]);
  });

  testWidgets('changing the rate system keeps only the types it has', (tester) async {
    await openForm(tester, const Locale('fr', 'FR'));
    await tapText(tester, 'Royaume-Uni (HMRC)');
    expect(find.text('Cyclomoteur'), findsNothing);
    expect(find.text('Électrique'), findsNothing);
    await tapText(tester, 'Vélo');
    await tapText(tester, 'France');
    expect(selected(tester, 'Voiture'), isTrue, reason: 'France has no rate for bicycles');
  });

  testWidgets('in the UK: HMRC, its types and the rates in force from the engine', (tester) async {
    final hmrc = hmrcYearOn(DateTime.now());
    final log = await openForm(tester, const Locale('en', 'GB'));
    expect(find.text('New vehicle'), findsOneWidget);
    expect(selected(tester, 'UK · HMRC'), isTrue);
    for (final chip in ['Car or van', 'Motorcycle', 'Bicycle']) {
      expect(find.widgetWithText(ChoiceChip, chip), findsOneWidget, reason: chip);
    }
    expect(find.text('Moped'), findsNothing);
    expect(find.text('Electric'), findsNothing);
    final (car, above) = (hmrc.carFirst10k ~/ 10, hmrc.carAbove10k ~/ 10);
    expect(
      find.text(
        'Cars and vans: ${car}p a mile for the first 10,000 business miles in the tax year, ${above}p after. '
        'The tax year starts on 6\u00a0April.',
      ),
      findsOneWidget,
    );
    await tapText(tester, 'Motorcycle');
    expect(
      find.text(
        'Motorcycles: ${hmrc.motorcycle ~/ 10}p a mile, whatever the distance. '
        'The tax year starts on 6\u00a0April.',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Bike');
    await tapText(tester, 'Bicycle');
    expect(
      find.text('Bicycles: ${hmrc.cycle ~/ 10}p a mile, whatever the distance. The tax year starts on 6\u00a0April.'),
      findsOneWidget,
    );
    await save(tester, 'Save');
    final v = log.inUse.single;
    expect([v.rates, v.type, v.horsepower, v.electric], [RateSystem.uk, VehicleType.bicycle, null, false]);
  });

  testWidgets('in the US: the IRS rate, for every vehicle the same', (tester) async {
    final log = await openForm(tester, const Locale('en', 'US'));
    expect(selected(tester, 'US · IRS'), isTrue);
    expect(find.text('Car or van'), findsNothing, reason: 'one IRS rate: no type to pick');
    expect(find.textContaining('One IRS rate for cars, vans, pickups and panel trucks'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Pickup');
    await save(tester, 'Save');
    expect([log.inUse.single.rates, log.inUse.single.type], [RateSystem.us, VehicleType.car]);
  });

  const clio = VehicleRecord(id: 'v1', name: 'Clio', rates: RateSystem.france, type: VehicleType.car, horsepower: 5);

  testWidgets('editing a vehicle keeps its id', (tester) async {
    final log = await openForm(tester, const Locale('en', 'US'), vehicle: clio);
    expect(find.text('Edit vehicle'), findsOneWidget);
    expect(selected(tester, 'France'), isTrue, reason: 'its own system, not the region’s');
    expect(selected(tester, '5\u00A0CV'), isTrue);
    await tapText(tester, '6\u00A0CV');
    await save(tester, 'Save');
    expect(log.logbook!.vehicles, [
      const VehicleRecord(id: 'v1', name: 'Clio', rates: RateSystem.france, type: VehicleType.car, horsepower: 6),
    ]);
  });

  testWidgets('archiving a vehicle takes it out of use, and Undo brings it back', (tester) async {
    final log = await openForm(tester, const Locale('fr', 'FR'), vehicle: clio);
    expect(find.text('Modifier le véhicule'), findsOneWidget);
    await tester.ensureVisible(find.text('Archiver ce véhicule'));
    await save(tester, 'Archiver ce véhicule');
    expect(find.text('Modifier le véhicule'), findsNothing);
    expect(log.inUse, isEmpty);
    expect(log.logbook!.vehicles.single.archived, isTrue);

    expect(find.text('«\u00a0Clio\u00a0» est archivé.'), findsOneWidget, reason: 'on the screen underneath');
    await save(tester, 'Annuler');
    expect(log.logbook!.vehicles, [clio]);
  });

  testWidgets('in English: the Undo snackbar', (tester) async {
    final log = await openForm(tester, const Locale('en', 'GB'), vehicle: clio);
    await tester.ensureVisible(find.text('Archive this vehicle'));
    await save(tester, 'Archive this vehicle');
    expect(find.text('“Clio” archived.'), findsOneWidget);
    await save(tester, 'Undo');
    expect(log.inUse, [clio]);
  });

  testWidgets('a save that fails keeps the form open and says so', (tester) async {
    final log = await openForm(tester, const Locale('en', 'US'), vehicle: clio);
    await tester.runAsync(
      () => data.log.replace(const Logbook(vehicles: [clio]).toJson()),
    ); // saving refused until reopened
    await save(tester, 'Save');
    expect(find.text('The vehicle couldn’t be saved. Try again.'), findsOneWidget);
    expect(find.text('Edit vehicle'), findsOneWidget);
    expect(log.logbook!.vehicles, [clio]);
  });
}
