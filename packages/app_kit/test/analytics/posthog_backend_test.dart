import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/src/analytics/posthog_backend.dart' show postHogConfig;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'phc_publicProjectKey123';

  test('PostHog is set up EU, anonymous, with nothing captured on its own', () {
    final config = postHogConfig(key).toMap();
    expect(config['projectToken'], key);
    expect(config['host'], 'https://eu.i.posthog.com');
    expect(config['personProfiles'], 'never');
    expect(config['sessionReplay'], isFalse);
    expect(config['captureApplicationLifecycleEvents'], isFalse);
    expect((config['rageClickConfig'] as Map)['enabled'], isFalse, reason: 'tap autocapture on iOS');
    expect(config['preloadFeatureFlags'], isFalse);
    expect(config['sendFeatureFlagEvents'], isFalse);
    expect(config['surveys'], isFalse);
    expect(config['capturePushNotificationSubscriptions'], isFalse);
    expect(config['capturePushNotificationOpened'], isFalse);
    expect(config['bootstrap'], isNull);
    expect((config['errorTrackingConfig'] as Map)['captureNativeExceptions'], isFalse);
  });

  test('the backend sets up, captures and closes, and never identifies anyone', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('posthog_flutter'),
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('posthog_flutter'),
        null,
      ),
    );

    final backend = PostHogBackend(key);
    await backend.start();
    await backend.capture('app.open.cold', {'app_id': 'carnet-km', 'days_since_install': 0});
    await backend.stop();

    expect(calls.map((c) => c.method), ['setup', 'capture', 'close']);
    expect((calls[0].arguments as Map)['host'], 'https://eu.i.posthog.com');
    expect((calls[1].arguments as Map)['eventName'], 'app.open.cold');
    expect((calls[1].arguments as Map)['properties'], {'app_id': 'carnet-km', 'days_since_install': 0});
  });

  test('start-up gives PostHog only to a release build with a key, with the app\'s version', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Carnet',
      packageName: 'fr.example.carnet',
      version: '1.2.0',
      buildNumber: '7',
      buildSignature: '',
    );
    final dir = Directory.systemTemp.createTempSync('start_analytics_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final kit = KitStateController(directory: dir, appId: 'carnet-km');
    AppConfig config(String? postHogKey) => AppConfig(
      slug: 'carnet-km',
      names: const {'fr': 'Carnet', 'en': 'Logbook'},
      supportEmail: 'support@example.fr',
      legal: {
        for (final lang in kitLanguages)
          lang: LegalLinks(
            legalNotice: Uri.parse('https://example.fr/$lang/legal'),
            privacy: Uri.parse('https://example.fr/$lang/privacy'),
            terms: Uri.parse('https://example.fr/$lang/terms'),
          ),
      },
      plans: const {Plan.yearly},
      postHogKey: postHogKey,
    );

    Future<Analytics> start(String? key, {required bool release}) =>
        startAnalytics(config(key), kitState: kit, locale: () => 'fr', releaseBuild: release);

    expect((await start(key, release: false)).backend, isNull);
    expect((await start(null, release: true)).backend, isNull);
    final analytics = await start(key, release: true);
    expect(analytics.backend, isA<PostHogBackend>());
    expect(analytics.appVersion, '1.2.0');
  });
}
