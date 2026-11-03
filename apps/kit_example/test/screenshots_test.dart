@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_example/l10n/example_localizations.dart';
import 'package:kit_example/main.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The store set (ADR 0001, section 11), made by `tool/screenshots.sh apps/kit_example`: onboarding, the paywall
/// and settings, iPhone and Android, French and English, with made-up data. The dark set, for design reviews,
/// goes to `build/screenshots-dark`, which no store reads.
const locales = [Locale('fr', 'FR'), Locale('en', 'US')];
const devices = [ScreenshotDevice.iPhone, ScreenshotDevice.androidPhone];
const shots = ['01_onboarding', '02_paywall', '03_settings'];

/// The sample app's own store-caption look; each app sets its brand colour and heading font.
const captionBand = Color(0xFF1B1B1F);
const captionStyle = TextStyle(fontFamily: 'Roboto', fontSize: 34, height: 1.2, fontWeight: FontWeight.w700);

void main() {
  late KitStateController kitState;

  setUp(() async {
    final dir = Directory.systemTemp.createTempSync('example_shots_');
    addTearDown(() => dir.deleteSync(recursive: true));
    kitState = KitStateController(directory: dir, appId: exampleConfig.slug);
    await kitState.load();
    PackageInfo.setMockInitialValues(
      appName: 'Kit example',
      packageName: 'fr.example.kit',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  /// Shot [name] of the app showing [screen] (null: its first launch, onboarding).
  Future<void> shoot(WidgetTester tester, String name, WidgetBuilder? screen) async {
    final analytics = Analytics(kitState: kitState, appId: exampleConfig.slug, appVersion: '1.0.0', locale: () => 'fr');
    for (final locale in locales) {
      final l10n = lookupExampleLocalizations(locale);
      final caption = switch (name) {
        '01_onboarding' => l10n.exampleShotOnboarding,
        '02_paywall' => l10n.exampleShotPaywall,
        _ => l10n.exampleShotSettings,
      };
      for (final device in devices) {
        for (final brightness in Brightness.values) {
          final light = brightness == Brightness.light;
          await takeScreenshot(
            tester,
            buildApp(screen: screen, kitState: kitState, analytics: analytics, review: FakeStoreReview()),
            device: device,
            locale: locale,
            name: name,
            brightness: brightness,
            caption: light ? StoreCaption(caption, background: captionBand, style: captionStyle) : null,
            dir: light ? 'store' : 'build/screenshots-dark',
          );
        }
      }
    }
  }

  testWidgets('onboarding', (tester) => shoot(tester, shots[0], null));

  testWidgets('the paywall, at made-up prices', (tester) async {
    final store = FakePurchasesBackend();
    final purchases = Purchases(
      backend: store,
      plans: exampleConfig.plans,
      analytics: Analytics(kitState: kitState, appId: exampleConfig.slug, appVersion: '1.0.0', locale: () => 'fr'),
    );
    await shoot(tester, shots[1], (context) {
      final lang = Localizations.localeOf(context).languageCode;
      if (lang == 'en') {
        store.storePackages.setAll(0, [
          const StorePackage(id: r'$rc_weekly', price: '€0.99', period: 'P1W'),
          const StorePackage(id: r'$rc_annual', price: '€9.99', period: 'P1Y'),
          const StorePackage(id: r'$rc_lifetime', price: '€24.99'),
        ]);
      }
      return PaywallScreen(
        placement: 'screenshots',
        purchases: purchases,
        legal: exampleConfig.legal[lang]!,
        header: Text(ExampleLocalizations.of(context).examplePaywallHeader),
      );
    });
  });

  testWidgets('settings', (tester) => shoot(tester, shots[2], (_) => SettingsScreen(kitState: kitState)));

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
