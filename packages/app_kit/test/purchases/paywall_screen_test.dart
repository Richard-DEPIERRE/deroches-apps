import 'dart:async';
import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the paywall must say, word for word, in each language, with the
/// [FakePurchasesBackend]'s prices.
const expected = {
  'en': (
    plans: ['Weekly', '0,99 €\u00a0per\u00a0week', 'Yearly', '9,99 €\u00a0per\u00a0year', 'Lifetime', '24,99 €'],
    renewals: [
      'Renews automatically every week at 0,99 € until you cancel.',
      'Renews automatically every year at 9,99 € until you cancel.',
    ],
    oneTime: 'One-time purchase, never renews.',
    cancelPlay: 'Cancel anytime in Google Play\u00a0› Payments & subscriptions\u00a0› Subscriptions.',
    cancelAppStore:
        'Cancel anytime in Settings\u00a0› your name\u00a0› Subscriptions, at least 24\u00a0hours before renewal.',
    restore: 'Restore purchases',
    terms: 'Terms',
    privacy: 'Privacy',
    close: 'Close',
    buttons: ['Subscribe for 0,99 €\u00a0per\u00a0week', 'Subscribe for 9,99 €\u00a0per\u00a0year', 'Buy for 24,99 €'],
  ),
  'fr': (
    plans: ['Hebdomadaire', '0,99 €\u00a0par\u00a0semaine', 'Annuel', '9,99 €\u00a0par\u00a0an', 'À vie', '24,99 €'],
    renewals: [
      'Se renouvelle automatiquement chaque semaine à 0,99 €, jusqu’à résiliation.',
      'Se renouvelle automatiquement chaque année à 9,99 €, jusqu’à résiliation.',
    ],
    oneTime: 'Achat unique, sans renouvellement.',
    cancelPlay: 'Résiliez à tout moment dans Google Play\u00a0› Paiements et abonnements\u00a0› Abonnements.',
    cancelAppStore:
        'Résiliez à tout moment dans Réglages\u00a0› votre nom\u00a0› Abonnements, au moins 24\u00a0heures avant le renouvellement.',
    restore: 'Restaurer les achats',
    terms: 'Conditions',
    privacy: 'Confidentialité',
    close: 'Fermer',
    buttons: [
      'S’abonner pour 0,99 €\u00a0par\u00a0semaine',
      'S’abonner pour 9,99 €\u00a0par\u00a0an',
      'Acheter pour 24,99 €',
    ],
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
  Future<void> pumpPaywall(WidgetTester tester, String lang, {String header = 'Unlimited exports'}) => pumpOnSmallPhone(
    tester,
    Locale(lang),
    PaywallScreen(
      placement: 'export',
      purchases: purchases,
      legal: legal[lang]!,
      header: Text(header),
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

      testWidgets('the footer says what the button does, for the picked plan', (tester) async {
        await pumpPaywall(tester, lang);
        await tester.ensureVisible(find.text(want.plans[4]));
        await tester.tap(find.text(want.plans[4]));
        await tester.pump();

        expect(find.text(want.cancelPlay), findsNothing);
        expect(find.text(want.oneTime), findsNWidgets(2)); // the lifetime card and the footer
      });

      testWidgets('on a small phone at large text, the button and what it does stay on screen', (tester) async {
        await pumpPaywall(tester, lang, header: 'Unlimited exports, backups to your own cloud and every report');
        final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;

        final button = tester.getRect(find.byType(FilledButton));
        expect(screen.contains(button.topLeft) && screen.contains(button.bottomRight - const Offset(1, 1)), isTrue);
        expect(screen.contains(tester.getRect(find.text(want.cancelPlay)).topLeft), isTrue, reason: 'disclosure');
      });

      testWidgets('the plans are one choice for screen readers, the picked one checked', (tester) async {
        await pumpPaywall(tester, lang);
        bool choice(Widget w, {bool? checked}) =>
            w is Semantics &&
            w.properties.inMutuallyExclusiveGroup == true &&
            (checked == null || w.properties.checked == checked);

        expect(find.byWidgetPredicate(choice), findsNWidgets(3));
        expect(find.byWidgetPredicate((w) => choice(w, checked: true)), findsOneWidget);
      });

      testWidgets(
        'on iPhone, how to cancel points to the App Store subscriptions',
        (tester) async {
          await pumpPaywall(tester, lang);
          expect(find.text(want.cancelAppStore), findsOneWidget);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

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

  testWidgets('in French on a 375dp phone, Terms and Privacy stay together on one line', (tester) async {
    // Real line breaks need real glyph widths: the SDK's Roboto, as on Android.
    final fonts = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
    await tester.runAsync(() async {
      final roboto = FontLoader('Roboto');
      for (final weight in ['Regular', 'Medium']) {
        roboto.addFont(File('$fonts/Roboto-$weight.ttf').readAsBytes().then(ByteData.sublistView));
      }
      await roboto.load();
    });
    tester.view
      ..physicalSize = const Size(750, 1334)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        locale: const Locale('fr'),
        supportedLocales: kitLocales,
        localizationsDelegates: KitLocalizations.localizationsDelegates,
        home: PaywallScreen(
          placement: 'export',
          purchases: purchases,
          legal: legal['fr']!,
          header: const Text('Exports illimités'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final terms = tester.getRect(find.text('Conditions'));
    final privacy = tester.getRect(find.text('Confidentialité'));
    expect(privacy.center.dy, terms.center.dy, reason: 'Confidentialité alone on its line');
  });

  testWidgets('a period of several units is said in words', (tester) async {
    store.storePackages[0] = const StorePackage(id: r'$rc_weekly', price: '2,99 €', period: 'P3M');
    await pumpPaywall(tester, 'en');

    expect(find.text('2,99 €\u00a0per\u00a03\u00a0months'), findsOneWidget);
    expect(find.text('Renews automatically every 3\u00a0months at 2,99 € until you cancel.'), findsOneWidget);
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
