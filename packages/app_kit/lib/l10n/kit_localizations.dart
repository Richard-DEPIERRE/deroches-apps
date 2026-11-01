import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'kit_localizations_en.dart';
import 'kit_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of KitLocalizations
/// returned by `KitLocalizations.of(context)`.
///
/// Applications need to include `KitLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/kit_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: KitLocalizations.localizationsDelegates,
///   supportedLocales: KitLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the KitLocalizations.supportedLocales
/// property.
abstract class KitLocalizations {
  KitLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static KitLocalizations of(BuildContext context) {
    return Localizations.of<KitLocalizations>(context, KitLocalizations)!;
  }

  static const LocalizationsDelegate<KitLocalizations> delegate =
      _KitLocalizationsDelegate();

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

  /// Title of the screen shown in place of a part of the app that failed to draw (release builds only).
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get kitErrorTitle;

  /// Body of the error screen: what happened and what the user can do.
  ///
  /// In en, this message translates to:
  /// **'This part of the app couldn\'t be shown. Close the app and open it again. If it keeps happening, write to us from Settings.'**
  String get kitErrorBody;
}

class _KitLocalizationsDelegate
    extends LocalizationsDelegate<KitLocalizations> {
  const _KitLocalizationsDelegate();

  @override
  Future<KitLocalizations> load(Locale locale) {
    return SynchronousFuture<KitLocalizations>(lookupKitLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_KitLocalizationsDelegate old) => false;
}

KitLocalizations lookupKitLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return KitLocalizationsEn();
    case 'fr':
      return KitLocalizationsFr();
  }

  throw FlutterError(
    'KitLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
