import 'dart:io';

import 'package:app_kit/testing.dart';
import 'package:flutter/material.dart';
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

  testWidgets('a caption frame puts the caption above the screen, at the same store size', (tester) async {
    final file = await takeScreenshot(
      tester,
      app(),
      device: ScreenshotDevice.iPhone,
      locale: const Locale('fr', 'FR'),
      name: '01_home',
      caption: 'Vos notes, rien qu’à vous',
      dir: dir.path,
    );
    expect(find.text('Vos notes, rien qu’à vous'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Vos notes, rien qu’à vous')).dy,
      lessThan(tester.getTopLeft(find.byType(Scaffold)).dy),
    );
    expect(pngInfo(file), (width: 1320, height: 2868, alpha: false));
  });
}
