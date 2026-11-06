// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'example_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class ExampleLocalizationsFr extends ExampleLocalizations {
  ExampleLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get exampleHomeBody =>
      'Ceci est l’application d’exemple du kit. Ses écrans ne sont jamais publiés.';

  @override
  String get exampleOnboarding1Title => 'Bienvenue';

  @override
  String get exampleOnboarding1Body =>
      'Cette page montre comment une application se présente au premier lancement.';

  @override
  String get exampleOnboarding2Title =>
      'Vos données restent sur votre téléphone';

  @override
  String get exampleOnboarding2Body =>
      'Rien de ce que vous écrivez ne quitte l’appareil. Vous pouvez passer ces pages à tout moment.';

  @override
  String get exampleGoodMoment => 'Quelque chose s’est bien passé';

  @override
  String get exampleSeePlans => 'Voir les offres';

  @override
  String get examplePaywallHeader => 'Notes et exports illimités';

  @override
  String get exampleShotOnboarding => 'Un court accueil, puis vos notes';

  @override
  String get exampleShotPaywall => 'Des prix clairs, sans engagement';

  @override
  String get exampleShotSettings => 'Votre langue, vos choix';
}
