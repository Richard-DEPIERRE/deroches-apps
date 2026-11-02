import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Without CFBundleLocalizations, iOS treats the app as English-only: the
  // App Store lists English only and Settings offers no French.
  test('iOS declares French and English', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final match = RegExp(
      r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist);
    expect(match, isNotNull, reason: 'CFBundleLocalizations is missing');
    final languages = RegExp(r'<string>(.*?)</string>')
        .allMatches(match!.group(1)!)
        .map((m) => m.group(1))
        .toSet();
    expect(languages, {'en', 'fr'});
  });
}
