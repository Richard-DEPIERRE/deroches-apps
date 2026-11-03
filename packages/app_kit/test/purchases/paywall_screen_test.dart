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
    plans: [
      'Weekly',
      '0,99\u00a0€ per\u00a0week',
      'Yearly',
      '9,99\u00a0€ per\u00a0year',
      'Lifetime',
      '24,99\u00a0€',
    ],
    renewals: [
      'Renews automatically every week at 0,99\u00a0€ until you cancel.',
      'Renews automatically every year at 9,99\u00a0€ until you cancel.',
    ],
    oneTime: 'One-time purchase, never renews.',
    cancelPlay: 'Cancel anytime in Google Play\u00a0› Payments & subscriptions\u00a0› Subscriptions.',
    cancelAppStore:
        'Cancel anytime in Settings\u00a0› your name\u00a0› Subscriptions, at least 24\u00a0hours before renewal.',
    restore: 'Restore purchases',
    terms: 'Terms',
    privacy: 'Privacy',
    close: 'Close',
    buttons: [
      'Subscribe for 0,99\u00a0€ per\u00a0week',
      'Subscribe for 9,99\u00a0€ per\u00a0year',
      'Buy for 24,99\u00a0€',
    ],
    error: 'Prices couldn’t load. Check your connection, then try again.',
    retry: 'Try again',
    entitled: 'You already have full access.',
    manage: 'Manage subscription',
    purchased: 'Purchase confirmed, thank you!',
    restored: 'Purchases restored.',
    nothingToRestore: 'No purchases to restore on this account.',
    pending: 'Purchase waiting for approval.',
    buyFailed: 'The purchase didn’t go through. Try again in a moment.',
    restoreFailed: 'Purchases couldn’t be restored. Check your connection, then try again.',
  ),
  'fr': (
    plans: [
      'Hebdomadaire',
      '0,99\u00a0€ par\u00a0semaine',
      'Annuel',
      '9,99\u00a0€ par\u00a0an',
      'À vie',
      '24,99\u00a0€',
    ],
    renewals: [
      'Se renouvelle automatiquement chaque semaine à 0,99\u00a0€, jusqu’à résiliation.',
      'Se renouvelle automatiquement chaque année à 9,99\u00a0€, jusqu’à résiliation.',
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
      'S’abonner pour 0,99\u00a0€ par\u00a0semaine',
      'S’abonner pour 9,99\u00a0€ par\u00a0an',
      'Acheter pour 24,99\u00a0€',
    ],
    error: 'Les prix n’ont pas pu se charger. Vérifiez votre connexion, puis réessayez.',
    retry: 'Réessayer',
    entitled: 'Vous avez déjà accès à tout.',
    manage: 'Gérer l’abonnement',
    purchased: 'Achat confirmé, merci\u00a0!',
    restored: 'Achats restaurés.',
    nothingToRestore: 'Aucun achat à restaurer sur ce compte.',
    pending: 'Achat en attente de validation.',
    buyFailed: 'L’achat n’a pas abouti. Réessayez dans un instant.',
    restoreFailed: 'Les achats n’ont pas pu être restaurés. Vérifiez votre connexion, puis réessayez.',
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

  /// The paywall alone, as the screen of the app. With [snackBars], on a
  /// 390×844 phone, still at 2× text: the test font's square glyphs leave a
  /// snackbar no room above the footer on the smallest phone.
  Future<void> pumpPaywall(
    WidgetTester tester,
    String lang, {
    String header = 'Unlimited exports',
    bool snackBars = false,
  }) async {
    await pumpOnSmallPhone(
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
    if (snackBars) {
      tester.view.physicalSize = const Size(780, 1688);
      await tester.pumpAndSettle();
    }
  }

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
        final footer = find.ancestor(of: find.text(want.cancelPlay), matching: find.byType(SingleChildScrollView));
        expect(button.top - tester.getRect(footer).bottom, 8, reason: 'a gap, so the cut-off line reads as more below');
        // Titles grow less than body text: the header stops at 1.5×, the plans keep 2×.
        expect(MediaQuery.of(tester.element(find.textContaining('Unlimited exports'))).textScaler.scale(10), 15);
        expect(MediaQuery.of(tester.element(find.text(want.plans[2]))).textScaler.scale(10), 20);
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

      Future<void> tapRestore(WidgetTester tester) async {
        await tester.ensureVisible(find.text(want.restore));
        await tester.tap(find.text(want.restore));
        await tester.pumpAndSettle();
      }

      testWidgets('a restore that finds a purchase says so and shows it active', (tester) async {
        store.ownedOnStore = true;
        await pumpPaywall(tester, lang, snackBars: true);
        await tapRestore(tester);

        expect(purchases.entitled.value, isTrue);
        expect(find.text(want.restored), findsOneWidget);
        expect(find.text(want.entitled), findsOneWidget);
        expect(await events(tester), ['paywall.view.export', 'paywall.tap.restore']);
      });

      testWidgets('restore says when there is nothing to restore, or the store is out of reach', (tester) async {
        await pumpPaywall(tester, lang, snackBars: true);
        await tapRestore(tester);
        expect(find.text(want.nothingToRestore), findsOneWidget);

        ScaffoldMessenger.of(tester.element(find.byType(PaywallScreen))).removeCurrentSnackBar();
        store.failRestore = true;
        await tapRestore(tester);
        expect(find.text(want.restoreFailed), findsOneWidget);
        expect(find.byType(FilledButton), findsOneWidget, reason: 'the plans stay on sale');
      });

      testWidgets('when prices are unavailable, the user can try again or leave', (tester) async {
        store.failPackages = true;
        await pumpPaywall(tester, lang);

        expect(find.text(want.error), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        store.failPackages = false;
        await tester.ensureVisible(find.text(want.retry));
        await tester.tap(find.text(want.retry));
        await tester.pumpAndSettle();
        expect(find.text(want.plans[2]), findsOneWidget);
        expect(find.text(want.error), findsNothing);
      });

      testWidgets('when prices are unavailable, close still works', (tester) async {
        final result = ValueNotifier<bool?>(null);
        store.failPackages = true;
        await pumpApp(tester, lang, result);
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text(want.error), findsOneWidget);

        await tester.tap(find.byTooltip(want.close));
        await tester.pumpAndSettle();
        expect(find.byType(PaywallScreen), findsNothing);
        expect(result.value, isFalse);
      });

      testWidgets('an active subscription shows as such, with nothing to buy and a way to manage it', (tester) async {
        store
          ..entitled.value = true
          ..manageUrl = Uri.parse('https://apps.apple.com/account/subscriptions');
        await pumpPaywall(tester, lang);

        expect(find.text(want.entitled), findsOneWidget);
        expect(find.text(want.plans[2]), findsNothing);
        expect(find.text(want.restore), findsNothing);
        await tester.tap(find.text(want.manage));
        expect(opened, [store.manageUrl]);
        final manage = tester.getSize(find.widgetWithText(OutlinedButton, want.manage));
        expect(tester.getSize(find.widgetWithText(FilledButton, want.close)).width, manage.width, reason: 'one width');
        expect(manage.width, lessThanOrEqualTo(340));
        expect(manage.height, greaterThanOrEqualTo(48));
      });

      testWidgets('a lifetime purchase has nothing to manage', (tester) async {
        store.entitled.value = true;
        await pumpPaywall(tester, lang);

        expect(find.text(want.entitled), findsOneWidget);
        expect(find.text(want.manage), findsNothing);
      });

      testWidgets('a failed purchase says so and keeps the paywall open', (tester) async {
        store.nextResult = const PurchaseFailed(PurchaseFailure.store, 'test');
        await pumpPaywall(tester, lang, snackBars: true);
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();

        expect(find.text(want.buyFailed), findsOneWidget);
        expect(find.byType(FilledButton), findsOneWidget);
        expect(tester.widget<FilledButton>(find.byType(FilledButton)).enabled, isTrue);
      });

      testWidgets('a pending purchase says it waits for approval; a cancelled one says nothing', (tester) async {
        store.nextResult = const PurchasePending();
        await pumpPaywall(tester, lang, snackBars: true);
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(find.text(want.pending), findsOneWidget);

        ScaffoldMessenger.of(tester.element(find.byType(PaywallScreen))).removeCurrentSnackBar();
        await tester.pumpAndSettle();
        store.nextResult = const PurchaseCancelled();
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('a purchase is confirmed on the screen underneath, once the paywall closes', (tester) async {
        await pumpApp(tester, lang, ValueNotifier(null));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();

        expect(find.byType(PaywallScreen), findsNothing);
        expect(find.text(want.purchased), findsOneWidget);
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

  testWidgets('while buying, the button spins and the plans and restore wait; close stays on', (tester) async {
    final store = _HeldStore();
    purchases = Purchases(backend: store, analytics: purchases.analytics, plans: config.plans);
    await pumpPaywall(tester, 'en', snackBars: true);
    final width = tester.getSize(find.byType(FilledButton)).width;
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    final colors = Theme.of(tester.element(find.byType(FilledButton))).colorScheme;
    final spinner = find.descendant(of: find.byType(FilledButton), matching: find.byType(CircularProgressIndicator));
    expect(tester.widget<CircularProgressIndicator>(spinner).color, colors.onPrimary);
    final fill = find.descendant(of: find.byType(FilledButton), matching: find.byType(Material));
    expect(tester.widget<Material>(fill).color, colors.primary, reason: 'in progress, not greyed out');
    expect(tester.getSize(find.byType(FilledButton)).width, width);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Restore purchases')).enabled, isFalse);
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Weekly')).onTap, isNull);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close)).onPressed, isNotNull);

    store.held.completeError(StateError('store crashed'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).enabled, isTrue, reason: 'never stuck busy');
    expect(find.text('The purchase didn’t go through. Try again in a moment.'), findsOneWidget);
  });

  testWidgets('while restoring, Restore spins and the buy button waits', (tester) async {
    final store = _HeldStore();
    purchases = Purchases(backend: store, analytics: purchases.analytics, plans: config.plans);
    await pumpPaywall(tester, 'en', snackBars: true);
    final restore = find.widgetWithText(TextButton, 'Restore purchases');
    await tester.ensureVisible(restore);
    final size = tester.getSize(restore);
    await tester.tap(restore);
    await tester.pump();

    expect(find.descendant(of: restore, matching: find.byType(CircularProgressIndicator)), findsOne);
    expect(tester.getSize(restore), size);
    expect(
      find.descendant(of: find.byType(FilledButton), matching: find.byType(CircularProgressIndicator)),
      findsNothing,
    );
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).enabled, isFalse);
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Weekly')).onTap, isNull);

    store.restoring.complete();
    await tester.pumpAndSettle();
    expect(find.text('No purchases to restore on this account.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).enabled, isTrue);
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

  testWidgets('a period of several units is said in words, and a price never breaks at its space', (tester) async {
    store.storePackages[0] = const StorePackage(id: r'$rc_weekly', price: '2,99 €', period: 'P3M');
    await pumpPaywall(tester, 'en');

    expect(find.text('2,99\u00a0€ per\u00a03\u00a0months'), findsOneWidget);
    expect(find.text('Renews automatically every 3\u00a0months at 2,99\u00a0€ until you cancel.'), findsOneWidget);
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

/// A store whose purchase waits on [held].
class _HeldStore extends FakePurchasesBackend {
  final held = Completer<PurchaseResult>();

  /// [restore] waits on it.
  final restoring = Completer<void>();

  @override
  Future<PurchaseResult> buy(String id) => held.future;

  @override
  Future<void> restore() async {
    await restoring.future;
    await super.restore();
  }
}
