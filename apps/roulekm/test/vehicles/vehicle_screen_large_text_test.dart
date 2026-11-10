import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/src/data/logbook.dart';
import 'package:roulekm/src/rates/french_bareme.dart';
import 'package:roulekm/src/rates/rates.dart';

import 'vehicle_screen_test.dart' show openForm, selected;

/// The SDK's Roboto, the phone's font: the test font draws every glyph a full em wide and would cut lines no
/// phone cuts. In its own file, so the other tests keep the test font.
Future<void> loadRoboto() async {
  final fonts = Directory('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts');
  final loader = FontLoader('Roboto');
  for (final f in fonts.listSync().whereType<File>().where((f) => RegExp(r'/Roboto-\w+\.ttf$').hasMatch(f.path))) {
    loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  // DAPP-141 §10; the longest chip, "Royaume-Uni (HMRC)", comes close to a full line here.
  testWidgets('nothing is cut off on a 360 × 640 phone with text at 2×', (tester) async {
    await tester.runAsync(loadRoboto);
    const van = VehicleRecord(id: 'v2', name: 'Utilitaire', rates: RateSystem.uk, type: VehicleType.car);
    await openForm(tester, const Locale('fr', 'FR'), vehicle: van, size: const Size(360, 640), textScale: 2);
    expect(selected(tester, 'Royaume-Uni (HMRC)'), isTrue);
    await tester.ensureVisible(find.text('Archiver ce véhicule'));
    await tester.pumpAndSettle();
    expect(find.text('Archiver ce véhicule').hitTestable(), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Archiver ce véhicule')).dx,
      tester.getTopLeft(find.text('Utilitaire')).dx,
      reason: 'the text button lines up with the fields at any text size',
    );
    // A layout overflow fails the test by itself; a chip fades a label that's too long instead.
    for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
      expect(p.debugHasOverflowShader || p.didExceedMaxLines, isFalse, reason: '"${p.text.toPlainText()}" is cut off');
    }
  });

  testWidgets('the first-vehicle step keeps its title, "Plus tard" and "C’est parti" at 2× on 360 × 640', (
    tester,
  ) async {
    await tester.runAsync(loadRoboto);
    await openForm(tester, const Locale('fr', 'FR'), size: const Size(360, 640), textScale: 2, firstVehicleDone: () {});
    for (final text in ['Votre véhicule', 'Plus tard', 'C’est parti']) {
      expect(find.text(text).hitTestable(), findsOneWidget, reason: text);
    }
    for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
      expect(p.debugHasOverflowShader || p.didExceedMaxLines, isFalse, reason: '"${p.text.toPlainText()}" is cut off');
    }
  });
}
