// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'kit_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class KitLocalizationsFr extends KitLocalizations {
  KitLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get kitErrorTitle => 'Un problème est survenu';

  @override
  String get kitErrorBody =>
      'Cette partie de l’application n’a pas pu s’afficher. Fermez l’application, puis rouvrez‑la. Si le problème persiste, écrivez‑nous depuis les réglages.';

  @override
  String get paywallClose => 'Fermer';

  @override
  String get paywallPlanWeekly => 'Hebdomadaire';

  @override
  String get paywallPlanYearly => 'Annuel';

  @override
  String get paywallPlanLifetime => 'À vie';

  @override
  String paywallPeriod(String unit, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: 'jour',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semaines',
      one: 'semaine',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mois',
      one: 'mois',
    );
    String _temp3 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ans',
      one: 'an',
    );
    String _temp4 = intl.Intl.selectLogic(unit, {
      'day': '$_temp0',
      'week': '$_temp1',
      'month': '$_temp2',
      'other': '$_temp3',
    });
    return '$_temp4';
  }

  @override
  String paywallPricePerPeriod(String price, String period) {
    return '$price / $period';
  }

  @override
  String paywallRenews(String price, String period) {
    return 'Se renouvelle automatiquement à $price / $period, à la fin de chaque période, jusqu’à résiliation.';
  }

  @override
  String get paywallOneTime => 'Achat unique, sans renouvellement.';

  @override
  String get paywallCancelAppStore =>
      'Résiliez à tout moment, au moins 24 heures avant le renouvellement, dans Réglages › votre nom › Abonnements.';

  @override
  String get paywallCancelGooglePlay =>
      'Résiliez à tout moment dans Google Play › Paiements et abonnements › Abonnements.';

  @override
  String paywallSubscribe(String price, String period) {
    return 'S’abonner pour $price / $period';
  }

  @override
  String paywallBuyOnce(String price) {
    return 'Acheter pour $price';
  }

  @override
  String get paywallRestore => 'Restaurer les achats';

  @override
  String get paywallTerms => 'Conditions d’utilisation';

  @override
  String get paywallPrivacy => 'Politique de confidentialité';

  @override
  String get paywallLoading => 'Chargement des prix';
}
