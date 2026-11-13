import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/home/home_screen.dart';
import 'package:roulekm/src/rates/distance.dart';

import 'home_screen_test.dart' show change, civic, clio, golf, openHome;

const _nbsp = '\u00a0';

TripRoute route(
  String from,
  String to,
  int distance,
  VehicleRecord vehicle, {
  String purpose = 'P',
  bool back = false,
}) => TripRoute(
  from: from,
  to: to,
  purpose: purpose,
  distance: Distance(distance, vehicle.rates.unit),
  vehicleId: vehicle.id,
  roundTrip: back,
);

TripRecord dated(String id, int day, TripRoute route) =>
    TripRecord(id: id, date: DateTime.utc(2026, 11, day), route: route);

/// The route row's screen-reader label and its arrow, which is an icon: Barlow has no glyph for U+2192.
void expectRoute(String label, {int count = 1}) {
  expect(find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}')), findsNWidgets(count), reason: label);
}

/// A tall phone, so every row is built without scrolling.
void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The same home, with "Gérer" and "Tout voir" wired to [edit] and [year].
Future<void> wire(WidgetTester tester, VoidCallback edit, VoidCallback year) async {
  final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
  final home = app.home! as HomeScreen;
  await tester.pumpWidget(
    MaterialApp(
      locale: app.locale,
      localizationsDelegates: app.localizationsDelegates,
      supportedLocales: app.supportedLocales,
      home: HomeScreen(log: home.log, settings: home.settings, now: home.now, editFavourites: edit, openYear: year),
    ),
  );
}

void main() {
  testWidgets('in French: the favourites and the last 3 trips follow what is added and deleted', (tester) async {
    tall(tester);
    final log = await openHome(tester, 'fr', [clio]);
    expect(find.text('Favoris'), findsNothing);
    expect(find.text('Derniers trajets'), findsNothing);

    final bron = route('Domicile', 'Chantier Bron', 34, clio, back: true);
    await change(tester, () => log.saveFavourite(FavouriteTrip(id: 'f1', route: bron)));
    await change(
      tester,
      () => log.saveFavourite(FavouriteTrip(id: 'f2', route: route('Agence', 'Vénissieux', 18, clio))),
    );
    expect(find.text('Favoris'), findsOneWidget);
    expect(find.text('Gérer'), findsNothing, reason: 'hidden until its screen exists');
    expectRoute('Domicile vers Chantier Bron');
    expect(find.text('34${_nbsp}km$_nbsp· aller-retour'), findsOneWidget);
    expect(find.text('18${_nbsp}km'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNWidgets(2));
    expect(find.byIcon(Icons.add_circle_outline), findsNWidgets(2));

    await change(tester, () => log.saveTrip(dated('t1', 2, route('Domicile', 'Lyon', 10, clio))));
    await change(
      tester,
      () => log.saveTrip(
        dated('t2', 4, route('Domicile', 'Chantier Bron', 34, clio, purpose: 'Suivi de chantier', back: true)),
      ),
    );
    await change(tester, () => log.saveTrip(dated('t3', 3, route('Domicile', 'Villeurbanne', 12, clio))));
    await change(tester, () => log.saveTrip(dated('t4', 1, route('Domicile', 'Oullins', 7, clio))));
    expect(find.text('Derniers trajets'), findsOneWidget);
    expect(find.text('Tout voir'), findsNothing, reason: 'hidden until the Year screen exists');
    expect(find.text('Mer.${_nbsp}4${_nbsp}nov.$_nbsp· Clio$_nbsp· Suivi de chantier'), findsOneWidget);
    expect(find.text('68${_nbsp}km'), findsOneWidget, reason: 'the distance counted, both ways');
    expectRoute('Domicile vers Chantier Bron', count: 2);
    expectRoute('Domicile vers Oullins', count: 0);
    final order = [
      'Chantier Bron',
      'Villeurbanne',
      'Lyon',
    ].map((to) => tester.getTopLeft(find.bySemanticsLabel(RegExp('^Domicile vers $to')).last).dy);
    expect(order.toList(), orderedEquals([...order]..sort()), reason: 'latest first');

    await change(tester, () => log.deleteTrip('t2'));
    expectRoute('Domicile vers Oullins');
    await change(tester, () => log.deleteFavourite('f1'));
    await change(tester, () => log.deleteFavourite('f2'));
    expect(find.text('Favoris'), findsNothing);
    expect(find.text('Derniers trajets'), findsOneWidget);
  });

  testWidgets('in English (US): favorites, recent trips and the route read aloud', (tester) async {
    tall(tester);
    final log = await openHome(tester, 'en', [civic]);
    final site = route('Home', 'Job site', 21, civic, purpose: 'Site visit', back: true);
    await change(tester, () => log.saveFavourite(FavouriteTrip(id: 'f1', route: site)));
    await change(tester, () => log.saveTrip(dated('t1', 4, site)));
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('21${_nbsp}mi$_nbsp· round trip'), findsOneWidget);
    expect(find.text('Recent trips'), findsOneWidget);
    expect(find.text('Wed,${_nbsp}Nov${_nbsp}4$_nbsp· Civic$_nbsp· Site visit'), findsOneWidget);
    expect(find.text('42${_nbsp}mi'), findsOneWidget);
    expectRoute('Home to Job site', count: 2);

    final tapped = <String>[];
    await wire(tester, () => tapped.add('edit'), () => tapped.add('year'));
    await tester.tap(find.text('Edit'));
    await tester.tap(find.text('See all'));
    expect(tapped, ['edit', 'year']);
  });

  testWidgets('in English with an HMRC vehicle: "Favourites" and UK dates', (tester) async {
    tall(tester);
    final log = await openHome(tester, 'en', [golf]);
    final site = route('Home', 'Job site', 21, golf, purpose: 'Site visit');
    await change(tester, () => log.saveFavourite(FavouriteTrip(id: 'f1', route: site)));
    await change(tester, () => log.saveTrip(dated('t1', 4, site)));
    expect(find.text('Favourites'), findsOneWidget);
    expect(find.text('Wed${_nbsp}4${_nbsp}Nov$_nbsp· Golf$_nbsp· Site visit'), findsOneWidget);
  });

  testWidgets('the route arrow is an icon, never the U+2192 character', (tester) async {
    tall(tester);
    final log = await openHome(tester, 'fr', [clio]);
    await change(tester, () => log.saveFavourite(FavouriteTrip(id: 'f1', route: route('A', 'B', 3, clio))));
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    expect(find.textContaining('→', findRichText: true), findsNothing);
  });
}
