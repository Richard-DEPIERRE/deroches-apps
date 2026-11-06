import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const pages = [
  OnboardingPage(title: 'One', body: 'First page', illustration: Icon(Icons.star)),
  OnboardingPage(title: 'Two', body: 'Second page', illustration: Icon(Icons.star)),
  OnboardingPage(title: 'Three', body: 'Third page', illustration: Icon(Icons.star)),
];

void main() {
  late Directory dir;
  late FakeAnalyticsBackend backend;
  KitStateController? last;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('onboarding_');
    addTearDown(() => dir.deleteSync(recursive: true));
    backend = FakeAnalyticsBackend();
    last = null;
  });

  /// Opens the app as a fresh launch would: the kit state read from disk,
  /// once the last launch's saves are written.
  Future<KitStateController> launch(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    if (last case final previous?) await waitForKitSaves(tester, previous);
    final kit = last = KitStateController(directory: dir, appId: 'kit-test');
    await tester.runAsync(kit.load);
    final analytics = Analytics(
      backend: backend,
      kitState: kit,
      appId: 'kit-test',
      appVersion: '1',
      locale: () => 'en',
    );
    await pumpOnSmallPhone(
      tester,
      locale,
      OnboardingFlow(kitState: kit, analytics: analytics, pages: pages, child: const Text('Home')),
    );
    return kit;
  }

  Future<void> tapAndSave(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    // The save is real file work: let it run, step by step.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pumpAndSettle();
    }
  }

  List<String> sent() => backend.events.map((e) => e.name).toList();

  testWidgets('skip on the first page saves completion, and onboarding never shows again', (tester) async {
    await launch(tester);
    expect(find.text('One'), findsOneWidget);
    await tapAndSave(tester, 'Skip');
    expect(find.text('Home'), findsOneWidget);
    expect(sent(), contains('onboarding.dismiss.skipped'));

    final kit = await launch(tester);
    expect(kit.state!.onboardingCompleted, isTrue);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('One'), findsNothing);
  });

  testWidgets('finishing the pages saves completion', (tester) async {
    await launch(tester);
    await tapAndSave(tester, 'Next');
    expect(find.text('Two'), findsOneWidget);
    await tapAndSave(tester, 'Next');
    expect(find.text('Skip').hitTestable(), findsNothing, reason: 'no Skip on the last page');
    await tapAndSave(tester, 'Get started');
    expect(find.text('Home'), findsOneWidget);
    expect(sent(), contains('onboarding.complete.finished'));
    expect((await launch(tester)).state!.onboardingCompleted, isTrue);
  });

  testWidgets('a double tap on Skip counts once', (tester) async {
    await launch(tester);
    await tester.tap(find.text('Skip'));
    await tapAndSave(tester, 'Skip');
    expect(sent().where((e) => e == 'onboarding.dismiss.skipped'), hasLength(1));
  });

  testWidgets('back goes to the previous page, and on the first page leaves the app', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await launch(tester);
    await tapAndSave(tester, 'Next');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('One'), findsOneWidget);
    expect(calls, isNot(contains('SystemNavigator.pop')));

    await tester.binding.handlePopRoute();
    expect(calls, contains('SystemNavigator.pop'));
  });

  testWidgets('fits a small phone at twice the text size, in French', (tester) async {
    await launch(tester, locale: const Locale('fr'));
    expect(find.text('Passer'), findsOneWidget);
    expect(find.text('Suivant'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('takes 2 to 4 pages', () {
    final kit = KitStateController(directory: Directory.systemTemp, appId: 'kit-test');
    final analytics = Analytics(kitState: kit, appId: 'kit-test', appVersion: '1', locale: () => 'en');
    OnboardingFlow make(int n) =>
        OnboardingFlow(kitState: kit, analytics: analytics, pages: List.filled(n, pages.first), child: const Text(''));
    expect(() => make(1), throwsArgumentError);
    expect(() => make(5), throwsArgumentError);
    expect(make(4).pages, hasLength(4));
  });
}
