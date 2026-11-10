import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Roulekm asks for no location and runs nothing in the background (DAPP-133, A3 to A6): the store privacy answers
/// and Play's declarations rely on these manifests saying so.
void main() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('iOS: no location, no background mode, no network exception of its own', () {
    for (final key in ['NSLocation', 'UIBackgroundModes', 'BGTaskScheduler', 'NSAppTransportSecurity']) {
      expect(plist, isNot(contains(key)), reason: key);
    }
  });

  test('Android: the only permission is Play Billing, declared by the app itself', () {
    // Play Console only lets Richard create the in-app products once an uploaded bundle declares it (DAPP-238).
    final permissions = RegExp(r'<uses-permission\s+android:name="([^"]+)"').allMatches(manifest).map((m) => m.group(1));
    expect(permissions, ['com.android.vending.BILLING']);
    expect(RegExp('<uses-permission').allMatches(manifest), hasLength(1));
  });

  test('Android: no service or receiver of its own', () {
    for (final tag in ['<service', '<receiver']) {
      expect(manifest, isNot(contains(tag)), reason: tag);
    }
  });

  test('the bundle ID and Play package are fr.roulekm.app (app-setup A1)', () {
    final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final ids = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);').allMatches(pbxproj).map((m) => m.group(1)).toSet();
    expect(ids, {'fr.roulekm.app', 'fr.roulekm.app.RunnerTests'});
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationId = "fr.roulekm.app"'));
    expect(gradle, contains('namespace = "fr.roulekm.app"'));
  });
}
