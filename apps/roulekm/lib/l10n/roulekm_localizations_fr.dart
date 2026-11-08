// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'roulekm_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class RoulekmLocalizationsFr extends RoulekmLocalizations {
  RoulekmLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get roulekmPlaceholderBody =>
      'Les écrans de Roulekm arrivent bientôt. Cette page n’est jamais publiée.';

  @override
  String get vehicleNewTitle => 'Nouveau véhicule';

  @override
  String get vehicleEditTitle => 'Modifier le véhicule';

  @override
  String get vehicleName => 'Nom';

  @override
  String get vehicleNameHelper =>
      'Pour le reconnaître : « Clio », « Utilitaire »…';

  @override
  String get vehicleNameMissing => 'Donnez-lui un nom.';

  @override
  String get vehicleRates => 'Barème';

  @override
  String get vehicleRatesFrance => 'France';

  @override
  String get vehicleRatesUk => 'Royaume-Uni (HMRC)';

  @override
  String get vehicleRatesUs => 'États-Unis (IRS)';

  @override
  String get vehicleType => 'Type';

  @override
  String get vehicleTypeCar => 'Voiture';

  @override
  String get vehicleTypeMotorbike => 'Moto';

  @override
  String get vehicleTypeMoped => 'Cyclomoteur';

  @override
  String get vehicleTypeBicycle => 'Vélo';

  @override
  String get vehicleHorsepower => 'Puissance fiscale';

  @override
  String vehicleHorsepowerOne(int cv) {
    return '$cv CV';
  }

  @override
  String vehicleHorsepowerUpTo(int cv) {
    return '$cv CV et moins';
  }

  @override
  String vehicleHorsepowerRange(int min, int max) {
    return '$min à $max CV';
  }

  @override
  String vehicleHorsepowerFrom(int cv) {
    return '$cv CV et plus';
  }

  @override
  String get vehicleHorsepowerNote => 'Sur la carte grise, case P.6.';

  @override
  String get vehicleHorsepowerMissing => 'Choisissez sa puissance fiscale.';

  @override
  String get vehicleElectric => 'Électrique';

  @override
  String get vehicleElectricNote => 'Le barème est majoré de 20 %.';

  @override
  String vehicleUkNote(int first, int after) {
    return 'Voitures et utilitaires : $first pence par mile pour les 10 000 premiers miles professionnels de l’année fiscale, $after pence au-delà. L’année fiscale commence le 6 avril.';
  }

  @override
  String get vehicleUsNote =>
      'Un seul taux IRS pour les voitures, utilitaires, pick-up et fourgons, électriques ou non. Seuls les miles professionnels comptent, pas les trajets domicile – travail.';

  @override
  String get vehicleSave => 'Enregistrer';

  @override
  String get vehicleArchive => 'Archiver ce véhicule';

  @override
  String get vehicleSaveFailed =>
      'Le véhicule n’a pas pu être enregistré. Réessayez.';
}
