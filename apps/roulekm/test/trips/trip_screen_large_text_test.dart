import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

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
    for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
      expect(p.debugHasOverflowShader || p.didExceedMaxLines, isFalse, reason: '"${p.text.toPlainText()}" is cut off');
    }
  });
}
