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
}
