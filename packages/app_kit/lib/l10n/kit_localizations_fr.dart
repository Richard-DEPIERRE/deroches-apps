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
  String get backupFailedUnreadable =>
      'Ces données n’ont pas pu être lues : elles sont abîmées, ou ne viennent pas de cette application. Vos données n’ont pas changé.';

  @override
  String get backupFailedOtherApp =>
      'Cette sauvegarde vient d’une autre application. Vos données n’ont pas changé.';

  @override
  String get backupFailedNewerSchema =>
      'Cette sauvegarde vient d’une version plus récente de l’application. Vos données n’ont pas changé. Mettez‑la à jour, puis réessayez.';

  @override
  String get backupFailedMigration =>
      'Impossible d’ouvrir cette sauvegarde. Vos données n’ont pas changé. Écrivez‑nous depuis les réglages.';

  @override
  String get backupFailedFile =>
      'Le fichier n’a pas pu être lu ou écrit. Vos données n’ont pas changé. Réessayez.';

  @override
  String get backupFailedTooLarge =>
      'Ce fichier est trop volumineux pour être une sauvegarde de cette application. Vos données n’ont pas changé.';

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
      other: '$count jours',
      one: 'jour',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semaines',
      one: 'semaine',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mois',
      one: 'mois',
    );
    String _temp3 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ans',
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
  String paywallEvery(String unit, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tous les $count jours',
      one: 'chaque jour',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'toutes les $count semaines',
      one: 'chaque semaine',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tous les $count mois',
      one: 'chaque mois',
    );
    String _temp3 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tous les $count ans',
      one: 'chaque année',
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
    return '$price par $period';
  }

  @override
  String paywallRenews(String every, String price) {
    return 'Se renouvelle automatiquement $every à $price, jusqu’à résiliation.';
  }

  @override
  String get paywallOneTime => 'Achat unique, sans renouvellement.';

  @override
  String get paywallCancelAppStore =>
      'Résiliez à tout moment dans Réglages › votre nom › Abonnements, au moins 24 heures avant le renouvellement.';

  @override
  String get paywallCancelGooglePlay =>
      'Résiliez à tout moment dans Google Play › Paiements et abonnements › Abonnements.';

  @override
  String paywallSubscribe(String price, String period) {
    return 'S’abonner pour $price par $period';
  }

  @override
  String paywallBuyOnce(String price) {
    return 'Acheter pour $price';
  }

  @override
  String get paywallRestore => 'Restaurer les achats';

  @override
  String get paywallTerms => 'Conditions';

  @override
  String get paywallPrivacy => 'Confidentialité';

  @override
  String get paywallLoading => 'Chargement des prix';

  @override
  String get paywallError =>
      'Les prix n’ont pas pu se charger. Vérifiez votre connexion, puis réessayez.';

  @override
  String get paywallRetry => 'Réessayer';

  @override
  String get paywallEntitled => 'Vous avez déjà accès à tout.';

  @override
  String get paywallManage => 'Gérer l’abonnement';

  @override
  String get paywallPurchased => 'Achat confirmé, merci !';

  @override
  String get paywallRestored => 'Achats restaurés.';

  @override
  String get paywallNothingToRestore =>
      'Aucun achat à restaurer sur ce compte.';

  @override
  String get paywallPending => 'Achat en attente de validation.';

  @override
  String get paywallBuyFailed =>
      'L’achat n’a pas abouti. Réessayez dans un instant.';

  @override
  String get paywallRestoreFailed =>
      'Les achats n’ont pas pu être restaurés. Vérifiez votre connexion, puis réessayez.';
}
