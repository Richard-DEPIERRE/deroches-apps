// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'roulekm_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class RoulekmLocalizationsEn extends RoulekmLocalizations {
  RoulekmLocalizationsEn([String locale = 'en']) : super(locale);

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

  @override
  String homeTotalFrance(String year, String amount) {
    return '$year mileage expenses: $amount';
  }

  @override
  String homeTotalUk(String year, String amount) {
    return '$year tax year: $amount';
  }

  @override
  String homeTotalUs(String year, String amount) {
    return '$year mileage deduction: $amount';
  }

  @override
  String homeThisYear(String distance) {
    return '$distance this year';
  }

  @override
  String homeThisTaxYear(String distance) {
    return '$distance this tax year';
  }

  @override
  String get homeElectric => 'electric +20%';

  @override
  String homeRuleFrance(String range, String formula) {
    return 'Band $range: $formula';
  }

  @override
  String homeRangeUpTo(String limit) {
    return 'up to $limit';
  }

  @override
  String homeRangeOver(String limit) {
    return 'over $limit';
  }

  @override
  String homeRuleUkFirst(int pence) {
    return 'First 10,000 business miles: ${pence}p a mile';
  }

  @override
  String homeRuleUkAbove(int pence) {
    return 'Above 10,000 business miles: ${pence}p a mile';
  }

  @override
  String homeRuleUkFlat(int pence) {
    return 'HMRC rate: ${pence}p a mile';
  }

  @override
  String homeRuleUs(String cents) {
    return 'IRS standard rate: $cents¢ a business mile';
  }

  @override
  String homeSourceFrance(String year, String latest, String site) {
    String _temp0 = intl.Intl.selectLogic(latest, {
      'yes': ', the latest published',
      'other': '',
    });
    return 'Barème kilométrique $year$_temp0 · source: $site';
  }

  @override
  String homeSourceUk(String year, String latest, String site) {
    String _temp0 = intl.Intl.selectLogic(latest, {
      'yes': ', the latest published',
      'other': '',
    });
    return 'HMRC approved mileage rates, $year$_temp0 · source: $site';
  }

  @override
  String homeSourceUs(String year, String latest, String site) {
    String _temp0 = intl.Intl.selectLogic(latest, {
      'yes': ', the latest published',
      'other': '',
    });
    return 'IRS standard mileage rate for $year$_temp0 · source: $site';
  }

  @override
  String get homeAddTrip => 'trip';

  @override
  String get homeAddTripLabel => 'Add a trip';

  @override
  String get homeNoVehicle => 'Add your vehicle to see your mileage costs';

  @override
  String homeFavourites(String uk) {
    String _temp0 = intl.Intl.selectLogic(uk, {
      'yes': 'Favourites',
      'other': 'Favorites',
    });
    return '$_temp0';
  }

  @override
  String get homeFavouritesEdit => 'Edit';

  @override
  String homeRoundTrip(String distance) {
    return '$distance · round trip';
  }

  @override
  String get homeRecent => 'Recent trips';

  @override
  String get homeSeeAll => 'See all';

  @override
  String homeRoute(String from, String to) {
    return '$from to $to';
  }

  @override
  String get sourcesTitle => 'Where the rates come from';

  @override
  String sourcesFrance(String year) {
    return 'French barème kilométrique, $year';
  }

  @override
  String sourcesFranceCovers(String year) {
    return 'For $year income, published by the French tax office. Cars and motorbikes by fiscal horsepower, and mopeds, in brackets of kilometres driven in the year; +20% for electric.';
  }

  @override
  String sourcesUk(String year) {
    return 'HMRC approved mileage allowance payments, $year';
  }

  @override
  String get sourcesUkCovers =>
      'Business miles in the tax year, 6 April to 5 April: cars and vans, at a lower rate after the first 10,000 miles; motorcycles; bicycles.';

  @override
  String sourcesUs(String year) {
    return 'IRS standard mileage rate, $year';
  }

  @override
  String get sourcesUsCovers =>
      'Business use of a car, van, pickup or panel truck, electric or not: one rate per mile, which can change during the year.';

  @override
  String sourcesLink(String title, String site, String date) {
    return '$title · $site, read $date';
  }

  @override
  String sourcesNextYear(String period, String next) {
    return 'The barème for $period trips comes out early in $next. Until then, Roulekm uses the latest one published, then works out your totals again when the new one is out.';
  }

  @override
  String get sourcesFooter =>
      'Roulekm is not affiliated with any tax authority. These amounts help you prepare your return; they are not tax advice.';
}
