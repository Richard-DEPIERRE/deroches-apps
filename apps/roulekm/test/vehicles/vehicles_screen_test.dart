import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/l10n/roulekm_localizations.dart';
import 'package:roulekm/src/data/log_controller.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/rates/french_bareme.dart';
import 'package:roulekm/src/rates/rates.dart';
import 'package:roulekm/src/vehicles/vehicles_screen.dart';

import '../data_upgrade/sample.dart';

/// The placements the paywall was asked for, and its answer.
final paywalls = <String>[];
var bought = false;

/// The list in [lang], on a 2026-11-09 clock, over the sample log (Clio and Pickup in use, Zoé archived, 3 trips).
Future<LogController> openList(WidgetTester tester, String lang, {Logbook? logbook, bool pro = false}) async {
  paywalls.clear();
  bought = false;
  final dir = Directory.systemTemp.createTempSync('roulekm_vehicles_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final data = RoulekmData(dir);
  final log = LogController(data.log);
  await tester.runAsync(() => data.log.replace((logbook ?? schema1Logbook).toJson()));
  await tester.runAsync(log.open);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: RoulekmLocalizations.localizationsDelegates,
      supportedLocales: RoulekmLocalizations.supportedLocales,
      home: VehiclesScreen(
        log: log,
        pro: ValueNotifier(pro),
        openPaywall: (_, placement) async {
          paywalls.add(placement);
          return bought;
        },
        now: () => DateTime(2026, 11, 9),
      ),
    ),
  );
  return log;
}

const clio = VehicleRecord(id: 'v1', name: 'Clio', rates: RateSystem.france, type: VehicleType.car, horsepower: 5);

void main() {
  testWidgets('in French: the vehicles in use with their year, the Pro add button, then the archived ones', (
    tester,
  ) async {
    await openList(tester, 'fr');
    expect(find.text('Véhicules'), findsOneWidget);
    expect(find.text('Clio'), findsOneWidget);
    expect(find.text('Voiture\u00A0· 5\u00A0CV\u00A0· thermique'), findsOneWidget);
    expect(find.text('68\u00A0km'), findsOneWidget, reason: '34 km there and back, this year only');
    expect(find.text('43\u00A0€'), findsOneWidget, reason: '68 × 0,636 at the 2025 barème, the latest published');
    expect(find.text('Voiture\u00A0· barème IRS'), findsOneWidget);
    expect(find.text('42\u00A0mi'), findsOneWidget);
    expect(find.text('32\u00A0\$'), findsOneWidget, reason: '42 miles × 76¢');
    expect(find.text('Ajouter un véhicule'), findsOneWidget);
    expect(find.text('Pro'), findsNWidgets(2), reason: 'on Add, and on putting Zoé back in use');
    expect(find.textContaining('Vous changez de voiture\u00A0? Archivez l’ancienne\u00A0:'), findsOneWidget);
    expect(find.text('Archivés'), findsOneWidget);
    expect(find.text('Zoé'), findsOneWidget);
    expect(find.text('Ses trajets restent dans les relevés des années passées'), findsOneWidget);
    final scheme = Theme.of(tester.element(find.text('Zoé'))).colorScheme;
    CircleAvatar avatarOf(String name) =>
        tester.widget(find.descendant(of: find.widgetWithText(ListTile, name), matching: find.byType(CircleAvatar)));
    expect(avatarOf('Zoé').backgroundColor, scheme.surfaceContainerHighest, reason: 'archived: muted');
    expect(avatarOf('Clio').backgroundColor, isNull, reason: 'in use: the theme default');
    expect(find.text('112\u00A0km'), findsNothing, reason: 'an archived row shows no total');
  });

  testWidgets('in English: the same list', (tester) async {
    await openList(tester, 'en');
    expect(find.text('Vehicles'), findsOneWidget);
    expect(find.text('Car or van\u00A0· 5\u00A0CV\u00A0· combustion'), findsOneWidget);
    expect(find.text('€43'), findsOneWidget);
    expect(find.text('Car or van\u00A0· IRS standard rate'), findsOneWidget);
    expect(find.text('\$32'), findsOneWidget);
    expect(find.text('Add a vehicle'), findsOneWidget);
    expect(find.text('Changing cars? Archive the old one: its trips stay, and the new one is free.'), findsOneWidget);
    expect(find.text('Archived'), findsOneWidget);
    expect(find.text('Its trips stay in past years’ logs'), findsOneWidget);
  });

  testWidgets('a tap on a row opens its form', (tester) async {
    await openList(tester, 'fr');
    await tester.tap(find.text('Clio'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier le véhicule'), findsOneWidget);
  });

  testWidgets('with no vehicle in use, adding one is free: no Pro tag, no hint', (tester) async {
    await openList(tester, 'en', logbook: const Logbook());
    expect(find.text('Pro'), findsNothing);
    expect(find.textContaining('Changing cars?'), findsNothing);
    await tester.tap(find.text('Add a vehicle'));
    await tester.pumpAndSettle();
    expect(find.text('New vehicle'), findsOneWidget);
    expect(paywalls, isEmpty);
  });

  testWidgets('a second vehicle before the first trip: the snackbar, no paywall', (tester) async {
    await openList(tester, 'fr', logbook: const Logbook(vehicles: [clio]));
    await tester.tap(find.text('Ajouter un véhicule'));
    await tester.pump();
    expect(find.text('Disponible avec Roulekm Pro, après votre premier trajet.'), findsOneWidget);
    expect(paywalls, isEmpty);
    expect(find.text('Nouveau véhicule'), findsNothing);
  });

  testWidgets('a second vehicle after the first trip: the paywall at second_vehicle; the form only once bought', (
    tester,
  ) async {
    await openList(tester, 'en');
    await tester.tap(find.text('Add a vehicle'));
    await tester.pumpAndSettle();
    expect(paywalls, ['second_vehicle']);
    expect(find.text('New vehicle'), findsNothing);

    bought = true;
    await tester.tap(find.text('Add a vehicle'));
    await tester.pumpAndSettle();
    expect(find.text('New vehicle'), findsOneWidget);
  });

  testWidgets('with Pro: no tag, no paywall', (tester) async {
    await openList(tester, 'en', pro: true);
    expect(find.text('Pro'), findsNothing);
    await tester.tap(find.text('Add a vehicle'));
    await tester.pumpAndSettle();
    expect(find.text('New vehicle'), findsOneWidget);
    expect(paywalls, isEmpty);
  });

  testWidgets('back in use: free when none is in use, the same Pro action when one is', (tester) async {
    final log = await openList(tester, 'en');
    await tester.tap(find.byTooltip('Back in use'));
    await tester.pumpAndSettle();
    expect(paywalls, ['second_vehicle']);
    expect(log.inUse.map((v) => v.id), ['v1', 'v3']);

    bought = true;
    await tester.tap(find.byTooltip('Back in use'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(log.inUse.map((v) => v.id), ['v1', 'v2', 'v3']);
    expect(find.text('Archived'), findsNothing);

    final free = await openList(tester, 'en', logbook: Logbook(vehicles: [clio.copyWith(archived: true)]));
    await tester.tap(find.byTooltip('Back in use'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(free.inUse, [clio]);
    expect(paywalls, isEmpty);
  });
}
