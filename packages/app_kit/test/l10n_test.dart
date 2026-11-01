import 'dart:convert';
import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the language is the device\'s when it is French or English, English otherwise', () {
    expect(resolveKitLocale(const [Locale('fr', 'CA')]), const Locale('fr'));
    expect(resolveKitLocale(const [Locale('en', 'GB')]), const Locale('en'));
    expect(resolveKitLocale(const [Locale('de', 'DE'), Locale('fr', 'FR')]), const Locale('en'));
    expect(resolveKitLocale(const []), const Locale('en'));
    expect(resolveKitLocale(null), const Locale('en'));
  });

  test('every kit message is in English and in French', () {
    expect(arbProblems('lib/l10n/kit_en.arb', 'lib/l10n/kit_fr.arb'), isEmpty);
  });

  test('arbProblems names missing and empty messages', () {
    final dir = Directory.systemTemp.createTempSync('arb');
    addTearDown(() => dir.deleteSync(recursive: true));
    File(
      '${dir.path}/en.arb',
    ).writeAsStringSync(jsonEncode({'@@locale': 'en', 'a': 'A', '@a': <String, Object>{}, 'b': 'B', 'c': 'C'}));
    File('${dir.path}/fr.arb').writeAsStringSync(jsonEncode({'@@locale': 'fr', 'a': 'A fr', 'c': ' '}));
    expect(arbProblems('${dir.path}/en.arb', '${dir.path}/fr.arb'), ['missing "b"', 'empty "c"']);
  });

  testWidgets('the error screen fits the longest French string on a small phone at large text', (tester) async {
    final fr = (jsonDecode(File('lib/l10n/kit_fr.arb').readAsStringSync()) as Map<String, dynamic>)
      ..removeWhere((key, _) => key.startsWith('@'));
    final longest = fr.values.cast<String>().reduce((a, b) => a.length >= b.length ? a : b);

    await pumpOnSmallPhone(tester, const Locale('fr'), const KitErrorView());
    expect(find.text(longest), findsOneWidget, reason: 'the error screen holds the longest French kit string');
    expect(tester.takeException(), isNull);
  });
}
