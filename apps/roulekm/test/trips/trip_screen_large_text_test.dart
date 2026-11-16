import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/rates/distance.dart';

import '../vehicles/vehicle_screen_large_text_test.dart' show loadRoboto;
import 'trip_screen_test.dart' show bron, openTrip, pickup, type;

void main() {
  testWidgets('at 2× text, Swap is a text button under the places and nothing is cut off on the odometer', (
    tester,
  ) async {
    await tester.runAsync(loadRoboto);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openTrip(tester, const Locale('fr', 'FR'), trips: [bron], size: const Size(360, 2000));
    await type(tester, 'Départ', 'Domicile');
    await type(tester, 'Arrivée', 'Chantier Bron');
    await tester.tap(find.text('Compteur'));
    await tester.pump();
    await type(tester, 'Compteur départ', '45210');
    await type(tester, 'Compteur arrivée', '45244');

    expect(find.widgetWithIcon(IconButton, Icons.swap_vert), findsNothing);
    expect(
      tester.getTopLeft(find.text('Inverser')).dx,
      tester.getTopLeft(find.text('Domicile')).dx,
      reason: 'the text button lines up with the fields',
    );
    expect(
      tester.getTopLeft(find.text('Inverser')).dy,
      greaterThan(tester.getBottomLeft(find.text('Chantier Bron')).dy),
    );
    await tester.tap(find.text('Inverser'));
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Départ')).controller!.text, 'Chantier Bron');

    // A layout overflow fails the test by itself; labels and chips fade or ellipsize instead.
    for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
      expect(p.debugHasOverflowShader || p.didExceedMaxLines, isFalse, reason: '"${p.text.toPlainText()}" is cut off');
    }
  });

  testWidgets('at 2× text in English, the typed distance and its segments fit', (tester) async {
    await tester.runAsync(loadRoboto);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openTrip(tester, const Locale('en', 'US'), vehicles: [pickup], size: const Size(360, 2000));
    expect(find.text('Swap'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing, reason: 'no icons on the segments at large text sizes');
    expect(find.byIcon(Icons.speed), findsNothing);
    for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
      expect(p.debugHasOverflowShader || p.didExceedMaxLines, isFalse, reason: '"${p.text.toPlainText()}" is cut off');
    }
  });

  testWidgets('at 1.3× on a 360 dp phone the readings stack, so their labels fit', (tester) async {
    await tester.runAsync(loadRoboto);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openTrip(tester, const Locale('fr', 'FR'), size: const Size(360, 2000));
    await tester.tap(find.text('Compteur'));
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('Compteur arrivée')).dy,
      greaterThan(tester.getBottomLeft(find.text('Compteur départ')).dy),
    );
    for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
      expect(p.debugHasOverflowShader || p.didExceedMaxLines, isFalse, reason: '"${p.text.toPlainText()}" is cut off');
    }
  });

  testWidgets('a long purpose chip ends in an ellipsis, at full size', (tester) async {
    await tester.runAsync(loadRoboto);
    final long = TripRecord(
      id: 't9',
      date: DateTime.utc(2026, 11, 2),
      route: const TripRoute(
        from: 'Domicile',
        to: 'Chantier Bron',
        purpose: 'Réunion de chantier avec le maître d’ouvrage et le bureau de contrôle',
        distance: Distance(34, DistanceUnit.km),
        vehicleId: 'v1',
      ),
    );
    await openTrip(tester, const Locale('fr', 'FR'), trips: [long], size: const Size(360, 2000));
    final chip = find.descendant(of: find.byType(ActionChip), matching: find.byType(RichText));
    final paragraph = tester.renderObject<RenderParagraph>(chip);
    expect(paragraph.didExceedMaxLines, isTrue, reason: 'cut with an ellipsis, not shrunk until unreadable');
  });

  testWidgets('at 2× text on a 360 dp phone (360 × 640), the repeat sheet keeps its button on screen', (tester) async {
    await tester.runAsync(loadRoboto);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openTrip(
      tester,
      const Locale('fr', 'FR'),
      trips: [bron],
      size: const Size(360, 640),
      date: DateTime.utc(2025, 12, 30),
    );
    await tester.scrollUntilVisible(find.text('Répéter ce trajet'), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Répéter ce trajet'));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Répéter du lundi au vendredi');
    expect(tester.getBottomLeft(button).dy, lessThanOrEqualTo(640));
    // A long day drops under "À partir du", which stays on one line, as tall as the day.
    final label = find.text('À\u00a0partir\u00a0du');
    final day = find.text('Mar.\u00a030\u00a0déc.\u00a02025');
    expect(tester.getTopLeft(day).dy, greaterThanOrEqualTo(tester.getBottomLeft(label).dy));
    expect(tester.getTopLeft(day).dx, tester.getTopLeft(label).dx);
    expect(tester.getSize(label).height, tester.getSize(day).height);
    // The promise's icon grows with the text, up to 1.5×.
    expect(tester.getSize(find.byIcon(Icons.check_circle_outline)).height, 30);
    for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
      expect(p.debugHasOverflowShader || p.didExceedMaxLines, isFalse, reason: '"${p.text.toPlainText()}" is cut off');
    }
  });
}
