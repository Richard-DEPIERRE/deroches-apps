import 'dart:io';

import 'package:app_kit/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('screenshots_'));
  tearDown(() => dir.deleteSync(recursive: true));

  Widget app() => MaterialApp(
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
    ),
    home: const Scaffold(body: Center(child: Text('iiiiiiiiii'))),
  );

  testWidgets('an iPhone shot is 1320×2868, with no alpha, in the App Store folder of its locale', (tester) async {
    final file = await takeScreenshot(
      tester,
      app(),
      device: ScreenshotDevice.iPhone,
      locale: const Locale('fr', 'FR'),
      name: '01_home',
      dir: dir.path,
    );
    expect(file.path, '${dir.path}/ios/screenshots/fr-FR/01_home.png');
    expect(find.byType(CheckedModeBanner), findsNothing, reason: 'no debug banner');
    expect(pngInfo(file), (width: 1320, height: 2868, alpha: false));
  });

  testWidgets('an Android shot is 1080×1920, with no alpha, in the Play folder of its locale', (tester) async {
    final file = await takeScreenshot(
      tester,
      app(),
      device: ScreenshotDevice.androidPhone,
      locale: const Locale('en', 'US'),
      name: '01_home',
      dir: dir.path,
    );
    expect(file.path, '${dir.path}/android/en-US/images/phoneScreenshots/01_home.png');
    expect(pngInfo(file), (width: 1080, height: 1920, alpha: false));
  });

  testWidgets('text is drawn in a real font, not the test font’s square glyphs', (tester) async {
    await takeScreenshot(
      tester,
      app(),
      device: ScreenshotDevice.iPhone,
      locale: const Locale('en', 'US'),
      name: 'font',
      dir: dir.path,
    );
    // The test font draws each glyph as wide as the font size (14): ten "i" would be 140.
    expect(tester.getSize(find.text('iiiiiiiiii')).width, lessThan(60));
  });

  testWidgets('a dark shot uses the dark theme', (tester) async {
    await takeScreenshot(
      tester,
      app(),
      device: ScreenshotDevice.androidPhone,
      locale: const Locale('en', 'US'),
      name: 'dark',
      brightness: Brightness.dark,
      dir: dir.path,
    );
    expect(Theme.of(tester.element(find.byType(Scaffold))).brightness, Brightness.dark);
  });

  const band = Color(0xFF1B1B1F);
  const style = TextStyle(fontFamily: 'Roboto', fontSize: 34, height: 1.2, fontWeight: FontWeight.w700);

  Future<File> captioned(WidgetTester tester, String text, {Color background = band, TextStyle style = style}) =>
      takeScreenshot(
        tester,
        app(),
        device: ScreenshotDevice.iPhone,
        locale: const Locale('fr', 'FR'),
        name: 'captioned',
        caption: StoreCaption(text, background: background, style: style),
        dir: dir.path,
      );

  testWidgets('a caption frame puts the caption above the screen, at the same store size', (tester) async {
    final file = await captioned(tester, 'Vos notes, rien qu’à vous');
    expect(
      tester.getTopLeft(find.text('Vos notes, rien qu’à vous')).dy,
      lessThan(tester.getTopLeft(find.byType(Scaffold)).dy),
    );
    expect(pngInfo(file), (width: 1320, height: 2868, alpha: false));
  });

  testWidgets('the screen has the same place in every captioned shot, whatever the caption’s length', (tester) async {
    await captioned(tester, 'Court');
    final short = tester.getRect(find.byType(Scaffold));
    await captioned(tester, 'Une légende sur deux lignes, pas plus');
    expect(tester.getRect(find.byType(Scaffold)), short);
  });

  testWidgets('a caption’s two lines are balanced', (tester) async {
    await captioned(tester, 'Your language, your choices');
    final paragraph = tester.renderObject<RenderParagraph>(find.text('Your language, your choices'));
    final boxes = paragraph.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 27));
    final lines = <double, double>{};
    for (final box in boxes) {
      lines[box.top] = (lines[box.top] ?? 0) + box.right - box.left;
    }
    expect(lines, hasLength(2));
    final widths = lines.values.toList()..sort();
    expect(widths.first / widths.last, greaterThan(0.6), reason: 'line widths $widths');
  });

  testWidgets('a caption longer than two lines fails the test', (tester) async {
    await expectLater(
      captioned(tester, 'Une légende beaucoup trop longue, qui prendrait trois lignes ou plus et écraserait l’écran'),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('a caption without enough contrast fails the test', (tester) async {
    await expectLater(
      captioned(tester, 'Gris sur gris', style: style.copyWith(color: const Color(0xFF555555))),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('a light band outlines the light screen; a dark one does not', (tester) async {
    bool outlined() => tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .any((b) => b.position == DecorationPosition.foreground && (b.decoration as BoxDecoration).border != null);
    await captioned(tester, 'Sombre');
    expect(outlined(), isFalse);
    await captioned(tester, 'Clair', background: Colors.white);
    expect(outlined(), isTrue);
  });

  testWidgets('the screen gets the phone’s safe area', (tester) async {
    for (final (device, insets) in [
      (ScreenshotDevice.iPhone, const EdgeInsets.only(top: 62, bottom: 34)),
      (ScreenshotDevice.androidPhone, const EdgeInsets.only(top: 24, bottom: 24)),
    ]) {
      await takeScreenshot(tester, app(), device: device, locale: const Locale('fr', 'FR'), name: 'x', dir: dir.path);
      expect(MediaQuery.paddingOf(tester.element(find.byType(Scaffold))), insets, reason: '$device');
    }
  });
}
