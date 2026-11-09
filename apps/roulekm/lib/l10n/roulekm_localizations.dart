import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'roulekm_localizations_en.dart';
import 'roulekm_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of RoulekmLocalizations
/// returned by `RoulekmLocalizations.of(context)`.
///
/// Applications need to include `RoulekmLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/roulekm_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: RoulekmLocalizations.localizationsDelegates,
///   supportedLocales: RoulekmLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the RoulekmLocalizations.supportedLocales
/// property.
abstract class RoulekmLocalizations {
  RoulekmLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static RoulekmLocalizations of(BuildContext context) {
    return Localizations.of<RoulekmLocalizations>(
      context,
      RoulekmLocalizations,
    )!;
  }

  static const LocalizationsDelegate<RoulekmLocalizations> delegate =
      _RoulekmLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// Placeholder home until the app's own screens land (DAPP-144 to DAPP-147). Never shipped.
  ///
  /// In en, this message translates to:
  /// **'Roulekm’s screens are coming soon. This page never ships.'**
  String get roulekmPlaceholderBody;

  /// No description provided for @vehicleNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New vehicle'**
  String get vehicleNewTitle;

  /// No description provided for @vehicleEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit vehicle'**
  String get vehicleEditTitle;

  /// No description provided for @vehicleName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get vehicleName;

  /// No description provided for @vehicleNameHelper.
  ///
  /// In en, this message translates to:
  /// **'So you can tell it apart: “Clio”, “Van”…'**
  String get vehicleNameHelper;

  /// No description provided for @vehicleNameMissing.
  ///
  /// In en, this message translates to:
  /// **'Give it a name.'**
  String get vehicleNameMissing;

  /// No description provided for @vehicleRates.
  ///
  /// In en, this message translates to:
  /// **'Rate system'**
  String get vehicleRates;

  /// No description provided for @vehicleRatesFrance.
  ///
  /// In en, this message translates to:
  /// **'France'**
  String get vehicleRatesFrance;

  /// No description provided for @vehicleRatesUk.
  ///
  /// In en, this message translates to:
  /// **'UK · HMRC'**
  String get vehicleRatesUk;

  /// No description provided for @vehicleRatesUs.
  ///
  /// In en, this message translates to:
  /// **'US · IRS'**
  String get vehicleRatesUs;

  /// No description provided for @vehicleType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get vehicleType;

  /// No description provided for @vehicleTypeCar.
  ///
  /// In en, this message translates to:
  /// **'Car or van'**
  String get vehicleTypeCar;

  /// No description provided for @vehicleTypeMotorbike.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get vehicleTypeMotorbike;

  /// No description provided for @vehicleTypeMoped.
  ///
  /// In en, this message translates to:
  /// **'Moped'**
  String get vehicleTypeMoped;

  /// No description provided for @vehicleTypeBicycle.
  ///
  /// In en, this message translates to:
  /// **'Bicycle'**
  String get vehicleTypeBicycle;

  /// No description provided for @vehicleHorsepower.
  ///
  /// In en, this message translates to:
  /// **'Fiscal horsepower'**
  String get vehicleHorsepower;

  /// A French barème band of one fiscal horsepower (CV, as on the carte grise).
  ///
  /// In en, this message translates to:
  /// **'{cv} CV'**
  String vehicleHorsepowerOne(int cv);

  /// No description provided for @vehicleHorsepowerUpTo.
  ///
  /// In en, this message translates to:
  /// **'{cv} CV or less'**
  String vehicleHorsepowerUpTo(int cv);

  /// No description provided for @vehicleHorsepowerRange.
  ///
  /// In en, this message translates to:
  /// **'{min} to {max} CV'**
  String vehicleHorsepowerRange(int min, int max);

  /// No description provided for @vehicleHorsepowerFrom.
  ///
  /// In en, this message translates to:
  /// **'{cv} CV or more'**
  String vehicleHorsepowerFrom(int cv);

  /// No description provided for @vehicleHorsepowerNote.
  ///
  /// In en, this message translates to:
  /// **'On the carte grise (registration certificate), box P.6.'**
  String get vehicleHorsepowerNote;

  /// No description provided for @vehicleHorsepowerMissing.
  ///
  /// In en, this message translates to:
  /// **'Pick its fiscal horsepower.'**
  String get vehicleHorsepowerMissing;

  /// No description provided for @vehicleElectric.
  ///
  /// In en, this message translates to:
  /// **'Electric'**
  String get vehicleElectric;

  /// No description provided for @vehicleElectricNote.
  ///
  /// In en, this message translates to:
  /// **'The barème is 20% higher.'**
  String get vehicleElectricNote;

  /// The pence come from the HMRC rates in force in the engine.
  ///
  /// In en, this message translates to:
  /// **'Cars and vans: {first}p a mile for the first 10,000 business miles in the tax year, {after}p after. The tax year starts on 6 April.'**
  String vehicleUkNote(int first, int after);

  /// No description provided for @vehicleUkNoteMotorbike.
  ///
  /// In en, this message translates to:
  /// **'Motorcycles: {rate}p a mile, whatever the distance. The tax year starts on 6 April.'**
  String vehicleUkNoteMotorbike(int rate);

  /// No description provided for @vehicleUkNoteBicycle.
  ///
  /// In en, this message translates to:
  /// **'Bicycles: {rate}p a mile, whatever the distance. The tax year starts on 6 April.'**
  String vehicleUkNoteBicycle(int rate);

  /// No description provided for @vehicleUsNote.
  ///
  /// In en, this message translates to:
  /// **'One IRS rate for cars, vans, pickups and panel trucks, electric or not. Business miles only: commuting doesn’t count.'**
  String get vehicleUsNote;

  /// No description provided for @vehicleSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get vehicleSave;

  /// No description provided for @vehicleArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive this vehicle'**
  String get vehicleArchive;

  /// Snackbar after archiving, with Undo.
  ///
  /// In en, this message translates to:
  /// **'“{name}” archived.'**
  String vehicleArchived(String name);

  /// No description provided for @vehicleArchiveUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get vehicleArchiveUndo;

  /// No description provided for @vehicleSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The vehicle couldn’t be saved. Try again.'**
  String get vehicleSaveFailed;

  /// No description provided for @vehiclesTitle.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get vehiclesTitle;

  /// No description provided for @vehiclesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a vehicle'**
  String get vehiclesAdd;

  /// Under the Add button while a vehicle is in use (DAPP-140 §1).
  ///
  /// In en, this message translates to:
  /// **'Changing cars? Archive the old one: its trips stay, and the new one is free.'**
  String get vehiclesSwapHint;

  /// No description provided for @vehiclesArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get vehiclesArchived;

  /// Subtitle of an archived vehicle in the list.
  ///
  /// In en, this message translates to:
  /// **'Its trips stay in past years’ logs'**
  String get vehiclesArchivedNote;

  /// Tooltip of the button that puts an archived vehicle back in use.
  ///
  /// In en, this message translates to:
  /// **'Back in use'**
  String get vehiclesUnarchive;

  /// Vehicle summary: not electric (French: thermique).
  ///
  /// In en, this message translates to:
  /// **'combustion'**
  String get vehicleEngineFuel;

  /// No description provided for @vehicleEngineElectric.
  ///
  /// In en, this message translates to:
  /// **'electric'**
  String get vehicleEngineElectric;

  /// No description provided for @vehicleRatesUkShort.
  ///
  /// In en, this message translates to:
  /// **'HMRC rates'**
  String get vehicleRatesUkShort;

  /// No description provided for @vehicleRatesUsShort.
  ///
  /// In en, this message translates to:
  /// **'IRS standard rate'**
  String get vehicleRatesUsShort;

  /// A distance, already formatted.
  ///
  /// In en, this message translates to:
  /// **'{distance} km'**
  String distanceKm(String distance);

  /// A distance, already formatted.
  ///
  /// In en, this message translates to:
  /// **'{distance} mi'**
  String distanceMiles(String distance);

  /// Small tag on a Pro action.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get proTag;

  /// Snackbar on a Pro action before the first trip (DAPP-140 §1).
  ///
  /// In en, this message translates to:
  /// **'Part of Roulekm Pro, once you’ve saved your first trip.'**
  String get proAfterFirstTrip;

  /// Header of the app's own section, first in Settings.
  ///
  /// In en, this message translates to:
  /// **'Roulekm'**
  String get settingsAppSection;
}

class _RoulekmLocalizationsDelegate
    extends LocalizationsDelegate<RoulekmLocalizations> {
  const _RoulekmLocalizationsDelegate();

  @override
  Future<RoulekmLocalizations> load(Locale locale) {
    return SynchronousFuture<RoulekmLocalizations>(
      lookupRoulekmLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_RoulekmLocalizationsDelegate old) => false;
}

RoulekmLocalizations lookupRoulekmLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return RoulekmLocalizationsEn();
    case 'fr':
      return RoulekmLocalizationsFr();
  }

  throw FlutterError(
    'RoulekmLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
