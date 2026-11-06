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
  String get kitOnboardingSkip => 'Passer';

  @override
  String get kitOnboardingNext => 'Suivant';

  @override
  String get kitOnboardingDone => 'Commencer';

  @override
  String kitOnboardingPage(int current, int total) {
    return 'Page $current sur $total';
  }

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

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageDevice => 'Langue du téléphone';

  @override
  String get settingsStatistics =>
      'Partager des statistiques d’utilisation et des rapports de plantage anonymes';

  @override
  String get settingsStatisticsDetail =>
      'Rien qui vous identifie. Les rapports de plantage suivent ce choix au prochain lancement.';

  @override
  String get settingsPrivacy => 'Confidentialité';

  @override
  String get settingsAbout => 'À propos';

  @override
  String settingsVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsPurchases => 'Achats';

  @override
  String get settingsBackup => 'Sauvegarde';

  @override
  String get settingsBackupExport => 'Exporter une sauvegarde';

  @override
  String get settingsBackupExportDetail =>
      'Enregistrez‑la dans iCloud Drive, Google Drive ou ailleurs.';

  @override
  String get settingsBackupRestore => 'Restaurer une sauvegarde';

  @override
  String get settingsBackupRestoreDetail =>
      'Remplace les données de ce téléphone par celles de la sauvegarde.';

  @override
  String get settingsBackupExported => 'Sauvegarde enregistrée.';

  @override
  String get settingsBackupRestored => 'Sauvegarde restaurée.';

  @override
  String get settingsBusy => 'En cours';

  @override
  String get settingsRate => 'Noter l’application';

  @override
  String get settingsSupport => 'Contacter l’assistance';

  @override
  String settingsSupportBody(String version, String system, String language) {
    return '\n\n—\nApplication : $version\nSystème : $system\nLangue : $language';
  }

  @override
  String settingsSupportNoMailApp(String email) {
    return 'Aucune application de messagerie. Écrivez à $email.';
  }

  @override
  String get settingsLinkFailed =>
      'La page n’a pas pu s’ouvrir. Réessayez plus tard.';

  @override
  String get settingsLegalNotice => 'Mentions légales';

  @override
  String get settingsPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get settingsTerms => 'Conditions d’utilisation';

  @override
  String get settingsSupportCopy => 'Copier';

  @override
  String get settingsSupportCopied => 'Adresse copiée.';
}
