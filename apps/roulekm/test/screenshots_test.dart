@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/l10n/roulekm_localizations.dart';
import 'package:roulekm/main.dart';
import 'package:roulekm/src/data/log_controller.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/home/home_screen.dart';
import 'package:roulekm/src/rates/distance.dart';
import 'package:roulekm/src/rates/french_bareme.dart';
import 'package:roulekm/src/rates/rates.dart';
import 'package:roulekm/src/trips/trip_screen.dart';
import 'package:roulekm/src/vehicles/vehicle_screen.dart';
import 'package:roulekm/src/year/year_screen.dart';

/// The store set (ADR 0001, section 11; DAPP-142's `store-captions`), made by `tool/screenshots.sh apps/roulekm`:
/// iPhone and Android, in French (barème, km, €) and US English (IRS, miles, $), light mode, a free user, made-up data
/// on a fixed clock.
const locales = [Locale('fr', 'FR'), Locale('en', 'US')];
const devices = [ScreenshotDevice.iPhone, ScreenshotDevice.androidPhone];
const shots = ['01_home', '02_add_trip', '03_vehicle', '04_year', '05_onboarding'];

/// The band and type of DAPP-142 §1: milestone orange, Barlow 700 34.
const band = Color(0xFFC4511A);
const style = TextStyle(fontFamily: 'Barlow', fontSize: 34, height: 1.2, fontWeight: FontWeight.w700);

/// A Friday in November: the year so far is full, and the rates are the ones a user sees then.
final today = DateTime(2026, 11, 13, 9);

/// Made-up content, never a user's: a tradesperson's year so far, in one vehicle.
Logbook sampleLog(String lang) {
  final fr = lang == 'fr';
  final system = fr ? RateSystem.france : RateSystem.us;
  TripRoute route(String from, String to, String purpose, int distance, {bool roundTrip = true}) => TripRoute(
    from: from,
    to: to,
    purpose: purpose,
    distance: Distance(distance, system.unit),
    vehicleId: 'car',
    roundTrip: roundTrip,
  );
  final client = fr
      ? route('Bureau', 'Client Martin, Villeurbanne', 'Rendez-vous client', 12)
      : route('Office', 'Client, Riverside', 'Client meeting', 8);
  final site = fr
      ? route('Domicile', 'Chantier Durand', 'Suivi de chantier', 34)
      : route('Shop', 'Job site, Oak Street', 'Site visit', 21);
  final supplies = fr
      ? route('Chantier Durand', 'Négoce matériaux, Vénissieux', 'Achat de matériaux', 9, roundTrip: false)
      : route('Job site, Oak Street', 'Lumber yard', 'Supplies', 6, roundTrip: false);
  final week = [client, site, supplies, site]; // Monday to Thursday
  final trips = <TripRecord>[];
  for (
    var day = DateTime.utc(2026, 1, 5);
    !day.isAfter(DateTime.utc(2026, 11, 12));
    day = day.add(const Duration(days: 1))
  ) {
    if (day.weekday <= week.length) {
      trips.add(TripRecord(id: 't${trips.length}', date: day, route: week[day.weekday - 1]));
    }
  }
  return Logbook(
    vehicles: [
      VehicleRecord(
        id: 'car',
        name: fr ? 'Citadine' : 'Pickup truck',
        rates: system,
        type: VehicleType.car,
        horsepower: fr ? 5 : null,
      ),
    ],
    trips: trips,
    favourites: [
      for (final (i, r) in [site, client, supplies].indexed) FavouriteTrip(id: 'f$i', route: r),
    ],
  );
}

void main() {
  late Directory dir;
  late KitStateController kitState;
  final pro = ValueNotifier(false);
  Future<bool> openPaywall(BuildContext context, String placement) async => false;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('roulekm_shots_');
    addTearDown(() => dir.deleteSync(recursive: true));
    kitState = KitStateController(directory: dir, appId: roulekmConfig.slug);
    await kitState.load();
  });

  ({String caption, String subline}) captionOf(RoulekmLocalizations l10n, int shot) => switch (shot) {
    1 => (caption: l10n.storeCaption1, subline: l10n.storeSubline1),
    2 => (caption: l10n.storeCaption2, subline: l10n.storeSubline2),
    3 => (caption: l10n.storeCaption3, subline: l10n.storeSubline3),
    4 => (caption: l10n.storeCaption4, subline: l10n.storeSubline4),
    _ => (caption: l10n.storeCaption5, subline: l10n.storeSubline5),
  };

  /// Shot [shot] (from 1) of [screen], over the sample log in each language, on each phone.
  Future<void> shoot(WidgetTester tester, int shot, Widget Function(LogController log) screen) async {
    for (final locale in locales) {
      final data = RoulekmData(Directory('${dir.path}/${locale.languageCode}')..createSync(), files: FakeBackupFiles());
      await tester.runAsync(() => data.log.replace(sampleLog(locale.languageCode).toJson()));
      final log = LogController(data.log);
      await tester.runAsync(log.open);
      final text = captionOf(lookupRoulekmLocalizations(locale), shot);
      for (final device in devices) {
        await takeScreenshot(
          tester,
          roulekmApp(kitState: kitState, home: (_) => screen(log)),
          device: device,
          locale: locale,
          name: shots[shot - 1],
          caption: StoreCaption(text.caption, subline: text.subline, background: band, style: style),
        );
      }
    }
  }

  testWidgets('1, the home of a free user with one vehicle', (tester) {
    return shoot(
      tester,
      1,
      (log) => HomeScreen(
        log: log,
        settings: (_) => const SizedBox(),
        pro: pro,
        openPaywall: openPaywall,
        editFavourites: () {},
        openYear: () {},
        now: () => today,
      ),
    );
  });

  testWidgets('2, a trip from a favourite', (tester) {
    return shoot(
      tester,
      2,
      (log) => TripScreen(
        log: log,
        route: log.logbook!.favourites.first.route,
        date: today,
        pro: pro,
        openPaywall: openPaywall,
        now: () => today,
      ),
    );
  });

  testWidgets('3, a vehicle and its rate', (tester) {
    return shoot(tester, 3, (log) => VehicleScreen(log: log, vehicle: log.inUse.first));
  });

  // TODO(DAPP-362): run again once the Year screen's PDF button is merged, so the store shows it.
  testWidgets('4, the year', (tester) {
    return shoot(tester, 4, (log) => YearScreen(log: log, pro: pro, openPaywall: openPaywall, now: () => today));
  });

  testWidgets('5, onboarding page 2: no account, no GPS', (tester) async {
    final analytics = Analytics(kitState: kitState, appId: roulekmConfig.slug, appVersion: '1.0.0', locale: () => 'fr');
    for (final locale in locales) {
      final text = captionOf(lookupRoulekmLocalizations(locale), 5);
      for (final device in devices) {
        final data = RoulekmData(Directory(dir.createTempSync().path), files: FakeBackupFiles());
        // Under a GlobalKey, the app keeps its page between the first take (page 1, thrown away) and the second.
        final app = KeyedSubtree(
          key: GlobalKey(),
          child: buildApp(kitState: kitState, analytics: analytics, data: data),
        );
        await takeScreenshot(tester, app, device: device, locale: locale, name: shots[4], dir: dir.path);
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        await takeScreenshot(
          tester,
          app,
          device: device,
          locale: locale,
          name: shots[4],
          caption: StoreCaption(text.caption, subline: text.subline, background: band, style: style),
        );
        expect(find.text(lookupRoulekmLocalizations(locale).onboardingTitle2), findsOneWidget);
      }
    }
  });

  test('the store set is complete, in both languages, at the store sizes', () {
    for (final device in devices) {
      for (final locale in locales) {
        final folder = Directory('store/${device.folder(locale)}');
        final files = folder.listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
        expect(
          [for (final f in files) f.uri.pathSegments.last],
          [for (final s in shots) '$s.png'],
          reason: folder.path,
        );
        for (final file in files) {
          final pixels = device.size * device.pixelRatio;
          expect(pngInfo(file), (width: pixels.width.round(), height: pixels.height.round(), alpha: false));
        }
      }
    }
  });
}
