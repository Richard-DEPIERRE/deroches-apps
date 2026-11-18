import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/data/logbook.dart';

import '../vehicles/vehicle_screen_large_text_test.dart' show loadRoboto;
import 'home_lists_test.dart' show dated, route;
import 'home_screen_test.dart' show change, civic, clio, golf, openHome;
import 'recurring_card_test.dart' show openWithPattern, weekdays;

/// With the phone's font (Roboto), in its own file so the other tests keep the test font.
void main() {
  for (final (lang, vehicle, header, from, to, purpose) in [
    ('fr', clio, 'Derniers trajets', 'Domicile', 'Fournisseur Vénissieux', 'Rendez-vous client'),
    ('en', golf, 'Recent trips', 'Office', 'Supplier, Riverside Industrial Estate', 'Client meeting'),
  ]) {
    testWidgets('$lang: nothing in the favourites and recent trips is cut on a 360 × 640 phone at 2× text', (
      tester,
    ) async {
      await tester.runAsync(loadRoboto);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final log = await openHome(tester, lang, [vehicle]);
      final trip = route(from, to, 1234, vehicle, purpose: purpose, back: true);
      await change(tester, () => log.saveFavourite(FavouriteTrip(id: 'f1', route: trip)));
      await change(tester, () => log.saveTrip(dated('t1', 4, trip)));
      await tester.scrollUntilVisible(find.text(header), 100);
      await tester.scrollUntilVisible(find.textContaining(purpose), 100);
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

  for (final (lang, vehicle, all, confirm) in [
    ('fr', clio, 'Tout confirmer', 'Confirmer 3\u00a0trajets'),
    ('en', civic, 'Confirm all', 'Confirm 3\u00a0trips'),
  ]) {
    testWidgets('$lang: the regular-trips card and its review sheet keep their actions on a 360 dp phone at 2× text', (
      tester,
    ) async {
      await tester.runAsync(loadRoboto);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openWithPattern(tester, lang, vehicle, weekdays(vehicle));
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpAndSettle();
      final review = find.text(lang == 'fr' ? 'Voir' : 'Review');
      await tester.ensureVisible(review);
      await tester.ensureVisible(find.text(all));
      await tester.pumpAndSettle();
      for (final action in [review, find.text(all)]) {
        expect(const Rect.fromLTWH(0, 0, 360, 640).contains(tester.getCenter(action)), isTrue, reason: '$action');
      }
      expectNothingCut(tester);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text(confirm)).bottom, lessThanOrEqualTo(640), reason: 'the button stays on screen');
      expectNothingCut(tester);
    });
  }
}

void expectNothingCut(WidgetTester tester) {
  for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
    expect(p.debugHasOverflowShader || p.didExceedMaxLines, isFalse, reason: '"${p.text.toPlainText()}" is cut off');
  }
}
