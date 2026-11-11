// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'roulekm_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class RoulekmLocalizationsFr extends RoulekmLocalizations {
  RoulekmLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get vehicleNewTitle => 'Nouveau véhicule';

  @override
  String get vehicleEditTitle => 'Modifier le véhicule';

  @override
  String get vehicleName => 'Nom';

  @override
  String get vehicleNameHelper =>
      'Pour le reconnaître : « Clio », « Utilitaire »…';

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
    return '$cv CV';
  }

  @override
  String vehicleHorsepowerUpTo(int cv) {
    return '$cv CV et moins';
  }

  @override
  String vehicleHorsepowerRange(int min, int max) {
    return '$min à $max CV';
  }

  @override
  String vehicleHorsepowerFrom(int cv) {
    return '$cv CV et plus';
  }

  @override
  String get vehicleHorsepowerNote => 'Sur la carte grise, case P.6.';

  @override
  String get vehicleHorsepowerMissing => 'Choisissez sa puissance fiscale.';

  @override
  String get vehicleElectric => 'Électrique';

  @override
  String get vehicleElectricNote => 'Le barème est majoré de 20 %.';

  @override
  String vehicleUkNote(int first, int after) {
    return 'Voitures et utilitaires : $first pence par mile pour les 10 000 premiers miles professionnels de l’année fiscale, $after pence au-delà. L’année fiscale commence le 6 avril.';
  }

  @override
  String vehicleUkNoteMotorbike(int rate) {
    return 'Motos : $rate pence par mile, quelle que soit la distance. L’année fiscale commence le 6 avril.';
  }

  @override
  String vehicleUkNoteBicycle(int rate) {
    return 'Vélos : $rate pence par mile, quelle que soit la distance. L’année fiscale commence le 6 avril.';
  }

  @override
  String get vehicleUsNote =>
      'Un seul taux IRS pour les voitures, utilitaires, pick-up et fourgons, électriques ou non. Seuls les miles professionnels comptent, pas les trajets domicile – travail.';

  @override
  String get vehicleSave => 'Enregistrer';

  @override
  String get vehicleArchive => 'Archiver ce véhicule';

  @override
  String vehicleArchived(String name) {
    return '« $name » est archivé.';
  }

  @override
  String get vehicleArchiveUndo => 'Annuler';

  @override
  String get vehicleSaveFailed =>
      'Le véhicule n’a pas pu être enregistré. Réessayez.';

  @override
  String get vehiclesTitle => 'Véhicules';

  @override
  String get vehiclesAdd => 'Ajouter un véhicule';

  @override
  String get vehiclesSwapHint =>
      'Vous changez de voiture ? Archivez l’ancienne : ses trajets restent, et la nouvelle est gratuite.';

  @override
  String get vehiclesArchived => 'Archivés';

  @override
  String get vehiclesArchivedNote =>
      'Ses trajets restent dans les relevés des années passées';

  @override
  String get vehiclesUnarchive => 'Remettre en service';

  @override
  String get vehicleEngineFuel => 'thermique';

  @override
  String get vehicleEngineElectric => 'électrique';

  @override
  String get vehicleRatesUkShort => 'barème HMRC';

  @override
  String get vehicleRatesUsShort => 'barème IRS';

  @override
  String distanceKm(String distance) {
    return '$distance km';
  }

  @override
  String distanceMiles(String distance) {
    return '$distance mi';
  }

  @override
  String get proTag => 'Pro';

  @override
  String get proAfterFirstTrip =>
      'Disponible avec Roulekm Pro, après votre premier trajet.';

  @override
  String get settingsAppSection => 'Roulekm';

  @override
  String get onboardingTitle1 => 'Vos kilomètres, en euros';

  @override
  String get onboardingBody1 =>
      'Notez un trajet en deux touches. Roulekm applique le barème kilométrique de votre véhicule (puissance fiscale, +20 % pour l’électrique) et tient le total de l’année.';

  @override
  String get onboardingTitle2 => 'Pas de compte, pas de GPS';

  @override
  String get onboardingBody2 =>
      'Rien à créer, rien qui tourne en arrière-plan : pas de batterie vidée, pas de trajet enregistré depuis le canapé. Vos trajets restent sur votre téléphone.';

  @override
  String get onboardingTitle3 =>
      'Trajets illimités, Pro sans abonnement obligatoire';

  @override
  String get onboardingBody3 =>
      'Aucun quota de trajets, gratuit ou non. Les extras Pro (relevé PDF, CSV, trajets récurrents, plusieurs véhicules) s’achètent une fois pour toutes, ou à l’année ou à la semaine si vous préférez. Pas d’essai qui se transforme en abonnement.';

  @override
  String get onboardingDone => 'Ajouter mon véhicule';

  @override
  String get firstVehicleTitle => 'Votre véhicule';

  @override
  String get firstVehicleLine =>
      'Pour appliquer le bon barème. Vous pourrez en ajouter d’autres ensuite.';

  @override
  String get firstVehicleLater => 'Plus tard';

  @override
  String get firstVehicleDone => 'C’est parti';

  @override
  String homeTotalFrance(String year, String amount) {
    return 'Frais kilométriques $year : $amount';
  }

  @override
  String homeTotalUk(String year, String amount) {
    return 'Année fiscale $year : $amount';
  }

  @override
  String homeTotalUs(String year, String amount) {
    return 'Déduction kilométrique $year : $amount';
  }

  @override
  String homeThisYear(String distance) {
    return '$distance cette année';
  }

  @override
  String homeThisTaxYear(String distance) {
    return '$distance cette année fiscale';
  }

  @override
  String get homeElectric => 'électrique +20 %';

  @override
  String homeRuleFrance(String range, String formula) {
    return 'Tranche $range : $formula';
  }

  @override
  String homeRangeUpTo(String limit) {
    return 'jusqu’à $limit';
  }

  @override
  String homeRangeOver(String limit) {
    return 'au-delà de $limit';
  }

  @override
  String homeRuleUkFirst(int pence) {
    return '10 000 premiers miles professionnels : $pence p par mile';
  }

  @override
  String homeRuleUkAbove(int pence) {
    return 'Au-delà de 10 000 miles professionnels : $pence p par mile';
  }

  @override
  String homeRuleUkFlat(int pence) {
    return 'Taux HMRC : $pence p par mile';
  }

  @override
  String homeRuleUs(String cents) {
    return 'Taux standard IRS : $cents ¢ par mile professionnel';
  }

  @override
  String homeSourceFrance(String year, String latest, String site) {
    String _temp0 = intl.Intl.selectLogic(latest, {
      'yes': ', le dernier publié',
      'other': '',
    });
    return 'Barème kilométrique $year$_temp0 · source : $site';
  }

  @override
  String homeSourceUk(String year, String latest, String site) {
    String _temp0 = intl.Intl.selectLogic(latest, {
      'yes': ', les dernières publiées',
      'other': '',
    });
    return 'Indemnités kilométriques HMRC, $year$_temp0 · source : $site';
  }

  @override
  String homeSourceUs(String year, String latest, String site) {
    String _temp0 = intl.Intl.selectLogic(latest, {
      'yes': ', le dernier publié',
      'other': '',
    });
    return 'Taux kilométrique standard IRS pour $year$_temp0 · source : $site';
  }

  @override
  String get homeAddTrip => 'trajet';

  @override
  String get homeAddTripLabel => 'Ajouter un trajet';

  @override
  String get homeNoVehicle => 'Ajoutez votre véhicule pour voir vos frais';
}
