import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/rates/distance.dart';

import '../home/home_screen_test.dart' show civic, clio;
import '../vehicles/vehicle_screen_large_text_test.dart' show loadRoboto;
import 'year_screen_test.dart' show dayTrip, openYear;

/// With the phone's font (Roboto), in its own file so the other tests keep the test font.
void main() {
  for (final (lang, vehicle, unit, label) in [
    ('fr', clio, DistanceUnit.km, 'Calcul'),
    ('en', civic, DistanceUnit.mile, 'Calculation'),
  ]) {
    testWidgets('$lang: the rows stack and nothing is cut on a 360 × 640 phone at 2× text', (tester) async {
      await tester.runAsync(loadRoboto);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openYear(
        tester,
        lang,
        Logbook(
          vehicles: [vehicle],
          trips: [
            dayTrip('a', vehicle.id, DateTime.utc(2026, 3, 1), 12345, unit, to: 'Fournisseur, zone industrielle'),
            dayTrip('b', vehicle.id, DateTime.utc(2026, 8, 1), 678, unit),
          ],
        ),
      );
      await tester.scrollUntilVisible(find.text(label), 100);
      expect(
        tester.getTopLeft(find.text(label)).dx,
        tester.getTopLeft(find.textContaining('×')).dx,
        reason: 'the label sits over its value',
      );
      await tester.scrollUntilVisible(find.textContaining('Fournisseur'), 100);
      // A layout overflow fails the test by itself; a faded or clipped line is checked here.
      for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
        expect(
          p.debugHasOverflowShader || p.didExceedMaxLines,
          isFalse,
          reason: '"${p.text.toPlainText()}" is cut off',
        );
      }
    });
  }
}
