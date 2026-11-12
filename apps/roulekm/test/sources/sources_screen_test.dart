import 'package:app_kit/app_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulekm/l10n/roulekm_localizations.dart';
import 'package:roulekm/src/sources/sources_screen.dart';

import '../home/home_screen_test.dart' show civic, clio, golf, openHome;

const _brochure =
    'https://www.impots.gouv.fr/www2/fichiers/documentation/brochure/ir_2026/pdf_integral/Brochure-IR-2026.pdf';
const _hmrc =
    'https://www.gov.uk/government/publications/rates-and-allowances-travel-mileage-and-fuel-allowances/travel-mileage-and-fuel-rates-and-allowances';
const _irs = 'https://www.irs.gov/tax-professionals/standard-mileage-rates';

// dart format off
final _copy = {
  'fr': (
    title: 'Sources des barèmes',
    cards: [
      ('Barème kilométrique 2025',
       'Pour les revenus 2025, publié par l’administration fiscale. Voitures et motos selon la puissance fiscale, cyclomoteurs, par tranches de kilomètres de l’année ; +20 % pour l’électrique.',
       'Brochure pratique 2026, Déclaration des revenus 2025 (DGFiP) · impots.gouv.fr, lu le 5\u00a0nov.\u00a02026', _brochure),
      ('Indemnités kilométriques HMRC, 2026–\u206027',
       'Miles professionnels de l’année fiscale, du 6 avril au 5 avril : voitures et utilitaires, à un taux plus bas après les 10 000 premiers miles ; motos ; vélos.',
       'Travel — mileage and fuel rates and allowances (HMRC) · gov.uk, lu le 5\u00a0nov.\u00a02026', _hmrc),
      ('Taux kilométrique standard IRS, 2026',
       'Usage professionnel d’une voiture, d’un van, d’un pick-up ou d’une camionnette, électrique ou non : un taux par mile, qui peut changer en cours d’année.',
       'Standard mileage rates (IRS) · irs.gov, lu le 5\u00a0nov.\u00a02026', _irs),
    ],
    nextYear: 'Le barème des trajets de 2026 paraît début 2027. D’ici là, Roulekm applique le dernier publié, puis recalcule vos totaux quand le nouveau sort.',
    footer: 'Roulekm n’est pas un service de l’administration. Ces montants aident à préparer votre déclaration ; ils ne sont pas un conseil fiscal.',
    homeSource: 'Barème kilométrique 2025, le dernier publié · source : impots.gouv.fr',
  ),
  'en': (
    title: 'Where the rates come from',
    cards: [
      ('French barème kilométrique, 2025',
       'For 2025 income, published by the French tax office. Cars and motorbikes by fiscal horsepower, mopeds, in brackets of the year’s kilometres; +20% for electric.',
       'Brochure pratique 2026, Déclaration des revenus 2025 (DGFiP) · impots.gouv.fr, read Nov\u00a05,\u00a02026', _brochure),
      ('HMRC approved mileage allowance payments, 2026–\u206027',
       'Business miles in the tax year, 6 April to 5 April: cars and vans, at a lower rate after the first 10,000 miles; motorcycles; bicycles.',
       'Travel — mileage and fuel rates and allowances (HMRC) · gov.uk, read Nov\u00a05,\u00a02026', _hmrc),
      ('IRS standard mileage rate, 2026',
       'Business use of a car, van, pickup or panel truck, electric or not: one rate per mile, which can change during the year.',
       'Standard mileage rates (IRS) · irs.gov, read Nov\u00a05,\u00a02026', _irs),
    ],
    nextYear: 'The barème for 2026 trips comes out early in 2027. Until then, Roulekm uses the latest one published, then works out your totals again when the new one is out.',
    footer: 'Roulekm is not affiliated with any tax authority. These amounts help you prepare your return; they are not tax advice.',
    homeSource: 'Barème kilométrique 2025, the latest published · source: impots.gouv.fr',
  ),
};
// dart format on

void main() {
  for (final MapEntry(key: lang, value: t) in _copy.entries) {
    testWidgets('one card per table in use, each linking its official page, then the footer ($lang)', (tester) async {
      final log = await openHome(tester, lang, [clio, golf, civic]);
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: const [...RoulekmLocalizations.localizationsDelegates, KitLocalizations.delegate],
          supportedLocales: RoulekmLocalizations.supportedLocales,
          home: SourcesScreen(
            log: log,
            now: () => DateTime(2026, 11, 11),
            openLink: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, t.title), findsOneWidget);
      for (final (name, covers, link, url) in t.cards) {
        expect(find.text(name), findsOneWidget);
        expect(find.text(covers), findsOneWidget);
        await tester.scrollUntilVisible(find.text(link), 100);
        await tester.tap(find.text(link));
        expect(opened.last, Uri.parse(url));
      }
      expect(find.byIcon(Icons.open_in_new), findsNWidgets(3));
      await tester.scrollUntilVisible(find.text(t.nextYear), 100);
      await tester.scrollUntilVisible(find.text(t.footer), 100);
    });

    testWidgets('a US vehicle alone: only the IRS card, no sentence on next year’s barème ($lang)', (tester) async {
      final log = await openHome(tester, lang, [civic]);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: const [...RoulekmLocalizations.localizationsDelegates, KitLocalizations.delegate],
          supportedLocales: RoulekmLocalizations.supportedLocales,
          home: SourcesScreen(log: log, now: () => DateTime(2026, 11, 11)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.cards[2].$1), findsOneWidget);
      expect(find.text(t.cards[0].$1), findsNothing);
      expect(find.text(t.cards[1].$1), findsNothing);
      expect(find.text(t.nextYear), findsNothing);
      expect(find.text(t.footer), findsOneWidget);
    });

    testWidgets('the home’s source line opens it ($lang)', (tester) async {
      await openHome(tester, lang, [clio]);
      await tester.tap(find.text(t.homeSource));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, t.title), findsOneWidget);
      expect(find.text(t.cards[0].$1), findsOneWidget);
    });
  }
}
