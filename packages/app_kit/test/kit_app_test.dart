import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final config = AppConfig(
  slug: 'kit-test',
  names: const {'fr': 'Essai', 'en': 'Trial'},
  supportEmail: 'support@example.com',
  legal: {
    for (final lang in kitLanguages)
      lang: LegalLinks(
        legalNotice: Uri.parse('https://example.com/$lang/legal'),
        privacy: Uri.parse('https://example.com/$lang/privacy'),
        terms: Uri.parse('https://example.com/$lang/terms'),
      ),
  },
  plans: const {Plan.yearly},
);

/// A home screen that shows one kit string, so a test can see the language.
Widget home(BuildContext context) => Text(KitLocalizations.of(context).kitErrorTitle);

Future<void> pumpWithDeviceLocales(WidgetTester tester, List<Locale> locales, Widget app) async {
  tester.platformDispatcher.localesTestValue = locales;
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  test('KitApp refuses an invalid config', () {
    final bad = AppConfig(
      slug: 'Bad Slug',
      names: config.names,
      supportEmail: config.supportEmail,
      legal: config.legal,
      plans: config.plans,
    );
    expect(() => KitApp(config: bad, seedColor: Colors.teal, home: home), throwsStateError);
  });

  testWidgets('loads in French on a French device', (tester) async {
    await pumpWithDeviceLocales(tester, const [
      Locale('fr', 'FR'),
    ], KitApp(config: config, seedColor: Colors.teal, home: home));
    expect(find.text('Un problème est survenu'), findsOneWidget);
  });

  testWidgets('loads in English on an English device', (tester) async {
    await pumpWithDeviceLocales(tester, const [
      Locale('en', 'GB'),
    ], KitApp(config: config, seedColor: Colors.teal, home: home));
    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('a device in German gets English', (tester) async {
    await pumpWithDeviceLocales(tester, const [
      Locale('de', 'DE'),
      Locale('fr', 'FR'),
    ], KitApp(config: config, seedColor: Colors.teal, home: home));
    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('the language override wins over the device and can be cleared', (tester) async {
    final override = ValueNotifier<Locale?>(const Locale('fr'));
    addTearDown(override.dispose);
    await pumpWithDeviceLocales(tester, const [
      Locale('en', 'US'),
    ], KitApp(config: config, seedColor: Colors.teal, home: home, languageOverride: override));
    expect(find.text('Un problème est survenu'), findsOneWidget);

    override.value = null;
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('KitScope hands the services to widgets', (tester) async {
    final crash = FakeCrashReporter();
    late KitScope scope;
    await tester.pumpWidget(
      KitApp(
        config: config,
        seedColor: Colors.teal,
        crashReporter: crash,
        home: (context) {
          scope = KitScope.of(context);
          return const SizedBox();
        },
      ),
    );
    expect(scope.config, same(config));
    expect(scope.crashReporter, same(crash));
    expect(scope.languageOverride.value, isNull);
  });

  testWidgets('light and dark themes come from the seed colour and font', (tester) async {
    late ThemeData light;
    await tester.pumpWidget(
      KitApp(
        config: config,
        seedColor: Colors.teal,
        fontFamily: 'Inter',
        home: (context) {
          light = Theme.of(context);
          return const SizedBox();
        },
      ),
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(light.colorScheme, ColorScheme.fromSeed(seedColor: Colors.teal));
    expect(app.darkTheme!.colorScheme, ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark));
    expect(light.textTheme.bodyMedium!.fontFamily, 'Inter');
    expect(app.darkTheme!.textTheme.bodyMedium!.fontFamily, 'Inter');
  });

  testWidgets('an error thrown in a widget reaches the CrashReporter', (tester) async {
    final crash = FakeCrashReporter();
    await tester.pumpWidget(
      KitApp(
        config: config,
        seedColor: Colors.teal,
        crashReporter: crash,
        home: (_) => throw StateError('boom in build'),
      ),
    );
    // Unmount first: it gives the error handlers back to the test framework,
    // so a failed expectation below fails the test instead of hanging it.
    await tester.pumpWidget(const SizedBox());
    expect(crash.errors, hasLength(1));
    expect(crash.errors.single.error, isA<StateError>());
    expect(crash.errors.single.stack, isNotNull);
  });

  testWidgets('an uncaught async error reaches the CrashReporter', (tester) async {
    final crash = FakeCrashReporter();
    await tester.pumpWidget(KitApp(config: config, seedColor: Colors.teal, crashReporter: crash, home: home));
    final handled = tester.binding.platformDispatcher.onError!(StateError('boom async'), StackTrace.current);
    await tester.pumpWidget(const SizedBox());
    expect(handled, isTrue);
    expect(crash.errors.single.error, isA<StateError>());
    expect(crash.errors.single.fatal, isTrue);
  });
}
