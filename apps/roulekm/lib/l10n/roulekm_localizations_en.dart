// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'roulekm_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class RoulekmLocalizationsEn extends RoulekmLocalizations {
  RoulekmLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get roulekmPlaceholderBody =>
      'Roulekm’s screens are coming soon. This page never ships.';

  @override
  String get vehicleNewTitle => 'New vehicle';

  @override
  String get vehicleEditTitle => 'Edit vehicle';

  @override
  String get vehicleName => 'Name';

  @override
  String get vehicleNameHelper => 'So you can tell it apart: “Clio”, “Van”…';

  @override
  String get vehicleNameMissing => 'Give it a name.';

  @override
  String get vehicleRates => 'Rate system';

  @override
  String get vehicleRatesFrance => 'France';

  @override
  String get vehicleRatesUk => 'UK · HMRC';

  @override
  String get vehicleRatesUs => 'US · IRS';

  @override
  String get vehicleType => 'Type';

  @override
  String get vehicleTypeCar => 'Car or van';

  @override
  String get vehicleTypeMotorbike => 'Motorcycle';

  @override
  String get vehicleTypeMoped => 'Moped';

  @override
  String get vehicleTypeBicycle => 'Bicycle';

  @override
  String get vehicleHorsepower => 'Fiscal horsepower';

  @override
  String vehicleHorsepowerOne(int cv) {
    return '$cv CV';
  }

  @override
  String vehicleHorsepowerUpTo(int cv) {
    return '$cv CV or less';
  }

  @override
  String vehicleHorsepowerRange(int min, int max) {
    return '$min to $max CV';
  }

  @override
  String vehicleHorsepowerFrom(int cv) {
    return '$cv CV or more';
  }

  @override
  String get vehicleHorsepowerNote =>
      'On the carte grise (registration certificate), box P.6.';

  @override
  String get vehicleHorsepowerMissing => 'Pick its fiscal horsepower.';

  @override
  String get vehicleElectric => 'Electric';

  @override
  String get vehicleElectricNote => 'The barème is 20% higher.';

  @override
  String vehicleUkNote(int first, int after) {
    return 'Cars and vans: ${first}p a mile for the first 10,000 business miles in the tax year, ${after}p after. The tax year starts on 6 April.';
  }

  @override
  String vehicleUkNoteMotorbike(int rate) {
    return 'Motorcycles: ${rate}p a mile, whatever the distance. The tax year starts on 6 April.';
  }

  @override
  String vehicleUkNoteBicycle(int rate) {
    return 'Bicycles: ${rate}p a mile, whatever the distance. The tax year starts on 6 April.';
  }

  @override
  String get vehicleUsNote =>
      'One IRS rate for cars, vans, pickups and panel trucks, electric or not. Business miles only: commuting doesn’t count.';

  @override
  String get vehicleSave => 'Save';

  @override
  String get vehicleArchive => 'Archive this vehicle';

  @override
  String vehicleArchived(String name) {
    return '“$name” archived.';
  }

  @override
  String get vehicleArchiveUndo => 'Undo';

  @override
  String get vehicleSaveFailed => 'The vehicle couldn’t be saved. Try again.';

  @override
  String get vehiclesTitle => 'Vehicles';

  @override
  String get vehiclesAdd => 'Add a vehicle';

  @override
  String get vehiclesSwapHint =>
      'Changing cars? Archive the old one: its trips stay, and the new one is free.';

  @override
  String get vehiclesArchived => 'Archived';

  @override
  String get vehiclesArchivedNote => 'Its trips stay in past years’ logs';

  @override
  String get vehiclesUnarchive => 'Back in use';

  @override
  String get vehicleEngineFuel => 'combustion';

  @override
  String get vehicleEngineElectric => 'electric';

  @override
  String get vehicleRatesUkShort => 'HMRC rates';

  @override
  String get vehicleRatesUsShort => 'IRS standard rate';

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
      'Part of Roulekm Pro, once you’ve saved your first trip.';

  @override
  String get settingsAppSection => 'Roulekm';

  @override
  String get onboardingTitle1 => 'Your miles, in money';

  @override
  String get onboardingBody1 =>
      'Log a trip in two taps. Roulekm applies the right rate to each vehicle (IRS or HMRC) and keeps the year’s total.';

  @override
  String get onboardingTitle2 => 'No account, no GPS';

  @override
  String get onboardingBody2 =>
      'Nothing to sign up for, nothing running in the background: no drained battery, no trips recorded from your couch. Your trips stay on your phone.';

  @override
  String get onboardingTitle3 =>
      'Unlimited trips. Pro, no subscription required';

  @override
  String get onboardingBody3 =>
      'No trip limit, free or paid. Pro extras (PDF log, CSV, recurring trips, several vehicles) can be bought once and kept, or by the year or week if you prefer. No trial that turns into a subscription.';

  @override
  String get onboardingDone => 'Add my vehicle';

  @override
  String get firstVehicleTitle => 'Your vehicle';

  @override
  String get firstVehicleLine =>
      'So the right rate applies. You can add more later.';

  @override
  String get firstVehicleLater => 'Later';

  @override
  String get firstVehicleDone => 'Done';
}
