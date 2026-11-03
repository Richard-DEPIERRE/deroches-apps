import 'dart:async';
import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the paywall must say, word for word, in each language, with the
/// [FakePurchasesBackend]'s prices.
const expected = {
  'en': (
    plans: ['Weekly', '0,99 € / week', 'Yearly', '9,99 € / year', 'Lifetime', '24,99 €'],
    renewals: [
      'Renews automatically at 0,99 € / week, at the end of each period, until you cancel.',
      'Renews automatically at 9,99 € / year, at the end of each period, until you cancel.',
    ],
    oneTime: 'One-time purchase, never renews.',
    cancelPlay: 'Cancel anytime in Google Play › Payments & subscriptions › Subscriptions.',
    cancelAppStore: 'Cancel anytime, at least 24 hours before renewal, in Settings › your name › Subscriptions.',
    restore: 'Restore purchases',
    terms: 'Terms of use',
    privacy: 'Privacy policy',
    close: 'Close',
    buttons: ['Subscribe for 0,99 € / week', 'Subscribe for 9,99 € / year', 'Buy for 24,99 €'],
  ),
  'fr': (
    plans: ['Hebdomadaire', '0,99 € / semaine', 'Annuel', '9,99 € / an', 'À vie', '24,99 €'],
    renewals: [
      'Se renouvelle automatiquement à 0,99 € / semaine, à la fin de chaque période, jusqu’à résiliation.',
      'Se renouvelle automatiquement à 9,99 € / an, à la fin de chaque période, jusqu’à résiliation.',
    ],
    oneTime: 'Achat unique, sans renouvellement.',
    cancelPlay: 'Résiliez à tout moment dans Google Play › Paiements et abonnements › Abonnements.',
    cancelAppStore:
        'Résiliez à tout moment, au moins 24 heures avant le renouvellement, dans Réglages › votre nom › Abonnements.',
    restore: 'Restaurer les achats',
    terms: 'Conditions d’utilisation',
    privacy: 'Politique de confidentialité',
    close: 'Fermer',
    buttons: ['S’abonner pour 0,99 € / semaine', 'S’abonner pour 9,99 € / an', 'Acheter pour 24,99 €'],
  ),
};

final legal = {
  for (final lang in kitLanguages)
    lang: LegalLinks(
      legalNotice: Uri.parse('https://carnet.example/$lang/mentions'),
      privacy: Uri.parse('https://carnet.example/$lang/privacy'),
      terms: Uri.parse('https://carnet.example/$lang/terms'),
    ),
};

final config = AppConfig(
  slug: 'carnet-km',
  names: const {'fr': 'Carnet', 'en': 'Logbook'},
  supportEmail: 'support@carnet.example',
  legal: legal,
  plans: Plan.values.toSet(),
);

void main() {
  late KitStateController kit;
  late FakePurchasesBackend store;
  late FakeAnalyticsBackend sent;
  late Purchases purchases;
  late List<Uri> opened;

  setUp(() async {
    final dir = Directory.systemTemp.createTempSync('paywall_');
    addTearDown(() => dir.deleteSync(recursive: true));
    kit = KitStateController(directory: dir, appId: config.slug);
    await kit.load();
    await kit.update((s) => s.copyWith(onboardingCompleted: true, firstValueReached: true));
    sent = FakeAnalyticsBackend();
    store = FakePurchasesBackend();
    purchases = Purchases(
      backend: store,
      plans: config.plans,
      analytics: Analytics(backend: sent, kitState: kit, appId: config.slug, appVersion: '1.0.0', locale: () => 'fr'),
    );
    opened = [];
  });

  /// The events sent so far. The analytics queue was made outside the test's
  /// fake clock, so it drains on the real one.
  Future<List<String>> events(WidgetTester tester) async {
    await tester.runAsync(() => purchases.analytics.idle);
    return [for (final e in sent.events) e.name];
  }

  /// The paywall alone, as the screen of the app.
  Future<void> pumpPaywall(WidgetTester tester, String lang) => pumpOnSmallPhone(
    tester,
    Locale(lang),
    PaywallScreen(
      placement: 'export',
      purchases: purchases,
      legal: legal[lang]!,
      header: const Text('Unlimited exports'),
      openLink: (uri) async {
        opened.add(uri);
        return true;
      },
    ),
  );

  /// An app screen whose button opens the paywall through the gate; the
  /// result lands in [result].
  Future<void> pumpApp(WidgetTester tester, String lang, ValueNotifier<bool?> result) => pumpOnSmallPhone(
    tester,
    Locale(lang),
    KitScope(
      config: config,
      crashReporter: FakeCrashReporter(),
      languageOverride: ValueNotifier(null),
      child: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result.value = await showPaywall(
              context,
              placement: 'export',
              gate: PaywallGate(kit),
              purchases: purchases,
              header: const Text('Unlimited exports'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  for (final MapEntry(key: lang, value: want) in expected.entries) {
    group(lang, () {
      testWidgets('every plan shows its store price, period and renewal, with how to cancel', (tester) async {
        await pumpPaywall(tester, lang);

        for (final line in [...want.plans, ...want.renewals, want.oneTime, want.cancelPlay]) {
          expect(find.text(line), findsOneWidget, reason: line);
        }
        expect(find.text(want.restore), findsOneWidget);
        expect(find.text(want.terms), findsOneWidget);
        expect(find.text(want.privacy), findsOneWidget);
        expect(find.byTooltip(want.close), findsOneWidget);
        expect(find.text('Unlimited exports'), findsOneWidget);
      });

      testWidgets("the button's price is the store's price string, for each plan", (tester) async {
        await pumpPaywall(tester, lang);

        // The yearly plan is picked at first.
        expect(find.widgetWithText(FilledButton, want.buttons[1]), findsOneWidget);
        for (final (i, plan) in [want.plans[0], want.plans[2], want.plans[4]].indexed) {
          await tester.ensureVisible(find.text(plan));
          await tester.tap(find.text(plan));
          await tester.pump();
          expect(find.widgetWithText(FilledButton, want.buttons[i]), findsOneWidget);
          expect(want.buttons[i], contains(store.storePackages[i].price));
        }
      });

      testWidgets('on iPhone, how to cancel points to the App Store subscriptions', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await pumpPaywall(tester, lang);
        expect(find.text(want.cancelAppStore), findsOneWidget);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets("the terms and privacy links open the app's pages in the user's language", (tester) async {
        await pumpPaywall(tester, lang);

        for (final label in [want.terms, want.privacy]) {
          await tester.ensureVisible(find.text(label));
          await tester.tap(find.text(label));
        }
        expect(opened, [legal[lang]!.terms, legal[lang]!.privacy]);
      });

      testWidgets('close is there and works on the first frame, while prices load', (tester) async {
        final result = ValueNotifier<bool?>(null);
        await pumpApp(tester, lang, result);
        store.holdPackages = Completer();

        await tester.tap(find.text('open'));
        await tester.pump(); // the route's first frame, built offstage
        await tester.pump(); // the first frame the user sees
        expect(find.byType(PaywallScreen), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(find.byTooltip(want.close));
        await tester.pumpAndSettle();

        expect(find.byType(PaywallScreen), findsNothing);
        expect(result.value, isFalse);
        expect(await events(tester), ['paywall.view.export', 'paywall.dismiss.export']);
      });

      testWidgets('restore calls the purchases module', (tester) async {
        store.ownedOnStore = true;
        await pumpPaywall(tester, lang);

        await tester.ensureVisible(find.text(want.restore));
        await tester.tap(find.text(want.restore));
        await tester.pumpAndSettle();

        expect(purchases.entitled.value, isTrue);
        expect(await events(tester), ['paywall.view.export', 'paywall.tap.restore']);
      });

    });
  }

  testWidgets('buying the picked plan closes the paywall, entitled, without a dismiss', (tester) async {
    final result = ValueNotifier<bool?>(null);
    await pumpApp(tester, 'en', result);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(store.bought, [r'$rc_annual']);
    expect(find.byType(PaywallScreen), findsNothing);
    expect(result.value, isTrue);
    expect(await events(tester), ['paywall.view.export', 'paywall.tap.yearly', 'purchase.complete.yearly']);
  });

  testWidgets("the gate's soft-paywall rule decides: no paywall before the first useful moment", (tester) async {
    await tester.runAsync(() => kit.update((s) => s.copyWith(firstValueReached: false)));
    final result = ValueNotifier<bool?>(null);
    await pumpApp(tester, 'en', result);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsNothing);
    expect(result.value, isFalse);
    expect(await events(tester), isEmpty);
  });
}
