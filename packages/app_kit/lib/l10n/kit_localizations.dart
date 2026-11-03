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
  /// **'This part of the app couldn’t be shown. Close the app and open it again. If it keeps happening, write to us from Settings.'**
  String get kitErrorBody;

  /// Onboarding button that skips the remaining pages and opens the app.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get kitOnboardingSkip;

  /// Onboarding button that goes to the next page.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get kitOnboardingNext;

  /// Onboarding button on the last page; opens the app.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get kitOnboardingDone;

  /// Screen-reader label of the onboarding page dots.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String kitOnboardingPage(int current, int total);

  /// Shown when a backup export or restore fails because the data can't be read: a picked file that isn't this app's backup, or a damaged backup or document. Must not say it is the picked file: an export fails this way too.
  ///
  /// In en, this message translates to:
  /// **'This data couldn’t be read: it’s damaged, or it isn’t from this app. Your data hasn’t changed.'**
  String get backupFailedUnreadable;

  /// Shown when a backup export or restore fails because the file is another app's backup.
  ///
  /// In en, this message translates to:
  /// **'This backup comes from another app. Your data hasn’t changed.'**
  String get backupFailedOtherApp;

  /// Shown when a backup export or restore fails because the backup was made by a newer version of the app.
  ///
  /// In en, this message translates to:
  /// **'This backup comes from a newer version of the app. Your data hasn’t changed. Update the app, then try again.'**
  String get backupFailedNewerSchema;

  /// Shown when a backup export or restore fails because the app's migrations couldn't upgrade the backup's data.
  ///
  /// In en, this message translates to:
  /// **'This backup couldn’t be opened. Your data hasn’t changed. Write to us from Settings.'**
  String get backupFailedMigration;

  /// Shown when a backup export or restore fails because a file couldn't be read or written.
  ///
  /// In en, this message translates to:
  /// **'The file couldn’t be read or written. Your data hasn’t changed. Try again.'**
  String get backupFailedFile;

  /// Shown when a restore fails because the picked file is over the size limit (a few MB).
  ///
  /// In en, this message translates to:
  /// **'This file is too large to be a backup of this app. Your data hasn’t changed.'**
  String get backupFailedTooLarge;

  /// Tooltip of the paywall's close button: neutral, never guilt wording.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get paywallClose;

  /// Name of the weekly plan.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get paywallPlanWeekly;

  /// Name of the yearly plan.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get paywallPlanYearly;

  /// Name of the lifetime plan (a one-time purchase).
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get paywallPlanLifetime;

  /// A subscription's billing period as the store gives it (unit: day, week, month or year).
  ///
  /// In en, this message translates to:
  /// **'{unit, select, day{{count, plural, =1{day} other{{count} days}}} week{{count, plural, =1{week} other{{count} weeks}}} month{{count, plural, =1{month} other{{count} months}}} other{{count, plural, =1{year} other{{count} years}}}}'**
  String paywallPeriod(String unit, int count);

  /// How often a subscription renews (unit: day, week, month or year).
  ///
  /// In en, this message translates to:
  /// **'{unit, select, day{{count, plural, =1{every day} other{every {count} days}}} week{{count, plural, =1{every week} other{every {count} weeks}}} month{{count, plural, =1{every month} other{every {count} months}}} other{{count, plural, =1{every year} other{every {count} years}}}}'**
  String paywallEvery(String unit, int count);

  /// A subscription's price as the store formats it, and its period.
  ///
  /// In en, this message translates to:
  /// **'{price} per {period}'**
  String paywallPricePerPeriod(String price, String period);

  /// When a subscription renews and at what price.
  ///
  /// In en, this message translates to:
  /// **'Renews automatically {every} at {price} until you cancel.'**
  String paywallRenews(String every, String price);

  /// Under the lifetime plan.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase, never renews.'**
  String get paywallOneTime;

  /// How to cancel on iPhone: the path to the App Store subscriptions in Settings.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime in Settings › your name › Subscriptions, at least 24 hours before renewal.'**
  String get paywallCancelAppStore;

  /// How to cancel on Android: the path to the Google Play subscriptions.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime in Google Play › Payments & subscriptions › Subscriptions.'**
  String get paywallCancelGooglePlay;

  /// Buy button for a subscription; the price is the store's.
  ///
  /// In en, this message translates to:
  /// **'Subscribe for {price} per {period}'**
  String paywallSubscribe(String price, String period);

  /// Buy button for the lifetime plan; the price is the store's.
  ///
  /// In en, this message translates to:
  /// **'Buy for {price}'**
  String paywallBuyOnce(String price);

  /// Restores the store account's purchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get paywallRestore;

  /// Link to the app's terms, in the paywall's footer (short: the page has the full title).
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get paywallTerms;

  /// Link to the app's privacy policy, in the paywall's footer (short).
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get paywallPrivacy;

  /// Screen-reader label while the store's prices load.
  ///
  /// In en, this message translates to:
  /// **'Loading prices'**
  String get paywallLoading;

  /// Shown instead of the plans when the store's prices can't be loaded.
  ///
  /// In en, this message translates to:
  /// **'Prices couldn’t load. Check your connection, then try again.'**
  String get paywallError;

  /// Button under paywallError: loads the prices again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get paywallRetry;

  /// Shown instead of the plans while the purchase is active.
  ///
  /// In en, this message translates to:
  /// **'You already have full access.'**
  String get paywallEntitled;

  /// Button that opens the store's page for the active subscription.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get paywallManage;

  /// Snackbar on the app's screen once a purchase went through and the paywall closed.
  ///
  /// In en, this message translates to:
  /// **'Purchase confirmed, thank you!'**
  String get paywallPurchased;

  /// Snackbar: restore found a purchase.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored.'**
  String get paywallRestored;

  /// Snackbar: restore found no purchase on the store account.
  ///
  /// In en, this message translates to:
  /// **'No purchases to restore on this account.'**
  String get paywallNothingToRestore;

  /// Snackbar: the purchase waits for someone else, such as a parent (Ask to Buy).
  ///
  /// In en, this message translates to:
  /// **'Purchase waiting for approval.'**
  String get paywallPending;

  /// Snackbar: the store failed the purchase. Never shown when the user cancels.
  ///
  /// In en, this message translates to:
  /// **'The purchase didn’t go through. Try again in a moment.'**
  String get paywallBuyFailed;

  /// Snackbar: restore couldn't reach the store.
  ///
  /// In en, this message translates to:
  /// **'Purchases couldn’t be restored. Check your connection, then try again.'**
  String get paywallRestoreFailed;

  /// Title of the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Header of the language choice in settings.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Language choice that follows the phone's language (French or English, English otherwise).
  ///
  /// In en, this message translates to:
  /// **'Phone’s language'**
  String get settingsLanguageDevice;

  /// Settings switch (ADR 0005, section 2): it covers analytics and crash reports. Must name crash reports.
  ///
  /// In en, this message translates to:
  /// **'Share anonymous usage statistics and crash reports'**
  String get settingsStatistics;

  /// Under the statistics switch: what is sent, and that crash reports follow the switch only from the next launch, either way.
  ///
  /// In en, this message translates to:
  /// **'Nothing that identifies you. Crash reports follow this choice from the next launch.'**
  String get settingsStatisticsDetail;

  /// Header of the privacy section in settings (the statistics switch).
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// Header of the about section in settings (the app version).
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// The app's version and build number, in settings.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String settingsVersion(String version, String build);

  /// French, written in French in both languages.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get settingsLanguageFrench;

  /// English, written in English in both languages.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// Header of the purchases section in settings (Restore purchases).
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get settingsPurchases;

  /// Header of the backup section in settings.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsBackup;

  /// Saves a backup file through the system save dialog.
  ///
  /// In en, this message translates to:
  /// **'Export a backup'**
  String get settingsBackupExport;

  /// Under Export a backup: where the file can go.
  ///
  /// In en, this message translates to:
  /// **'Save it to iCloud Drive, Google Drive or anywhere you like.'**
  String get settingsBackupExportDetail;

  /// Picks a backup file and replaces the app's data with it.
  ///
  /// In en, this message translates to:
  /// **'Restore a backup'**
  String get settingsBackupRestore;

  /// Under Restore a backup: what it does.
  ///
  /// In en, this message translates to:
  /// **'Replaces the data on this phone with the backup’s.'**
  String get settingsBackupRestoreDetail;

  /// Shown after a backup was exported.
  ///
  /// In en, this message translates to:
  /// **'Backup saved.'**
  String get settingsBackupExported;

  /// Shown after a backup was restored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored.'**
  String get settingsBackupRestored;

  /// Screen-reader label of the spinner on a settings item while its work runs.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get settingsBusy;

  /// Opens the app's page in the App Store or Google Play, to leave a rating.
  ///
  /// In en, this message translates to:
  /// **'Rate the app'**
  String get settingsRate;

  /// Opens an email to the app's support address.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get settingsSupport;

  /// Bottom of the support email, under the space the user writes in. Only these three facts: never an identifier.
  ///
  /// In en, this message translates to:
  /// **'\n\n—\nApp: {version}\nSystem: {system}\nLanguage: {language}'**
  String settingsSupportBody(String version, String system, String language);

  /// Shown when no email app opens for Contact support.
  ///
  /// In en, this message translates to:
  /// **'No email app found. Write to {email}.'**
  String settingsSupportNoMailApp(String email);

  /// Shown when a page from settings (store page, legal page) doesn't open.
  ///
  /// In en, this message translates to:
  /// **'The page couldn’t be opened. Try again later.'**
  String get settingsLinkFailed;

  /// Link to the app's legal notice on its site.
  ///
  /// In en, this message translates to:
  /// **'Legal notice'**
  String get settingsLegalNotice;

  /// Link to the app's privacy policy on its site.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyPolicy;

  /// Link to the app's terms of use on its site.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get settingsTerms;

  /// Action on the no-email-app message: copies the support address.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get settingsSupportCopy;

  /// Shown after the support address was copied.
  ///
  /// In en, this message translates to:
  /// **'Address copied.'**
  String get settingsSupportCopied;
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
