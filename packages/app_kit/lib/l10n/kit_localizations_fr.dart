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
}
