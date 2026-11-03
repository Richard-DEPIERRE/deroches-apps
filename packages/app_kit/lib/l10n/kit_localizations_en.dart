// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'kit_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class KitLocalizationsEn extends KitLocalizations {
  KitLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get kitErrorTitle => 'Something went wrong';

  @override
  String get kitErrorBody =>
      'This part of the app couldn’t be shown. Close the app and open it again. If it keeps happening, write to us from Settings.';

  @override
  String get backupFailedUnreadable =>
      'This data couldn’t be read: it’s damaged, or it isn’t from this app. Your data hasn’t changed.';

  @override
  String get backupFailedOtherApp =>
      'This backup comes from another app. Your data hasn’t changed.';

  @override
  String get backupFailedNewerSchema =>
      'This backup comes from a newer version of the app. Your data hasn’t changed. Update the app, then try again.';

  @override
  String get backupFailedMigration =>
      'This backup couldn’t be opened. Your data hasn’t changed. Write to us from Settings.';

  @override
  String get backupFailedFile =>
      'The file couldn’t be read or written. Your data hasn’t changed. Try again.';

  @override
  String get backupFailedTooLarge =>
      'This file is too large to be a backup of this app. Your data hasn’t changed.';

  @override
  String get paywallClose => 'Close';

  @override
  String get paywallPlanWeekly => 'Weekly';

  @override
  String get paywallPlanYearly => 'Yearly';

  @override
  String get paywallPlanLifetime => 'Lifetime';

  @override
  String paywallPeriod(String unit, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: 'day',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: 'week',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: 'month',
    );
    String _temp3 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: 'year',
    );
    String _temp4 = intl.Intl.selectLogic(unit, {
      'day': '$_temp0',
      'week': '$_temp1',
      'month': '$_temp2',
      'other': '$_temp3',
    });
    return '$_temp4';
  }

  @override
  String paywallEvery(String unit, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'every $count days',
      one: 'every day',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'every $count weeks',
      one: 'every week',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'every $count months',
      one: 'every month',
    );
    String _temp3 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'every $count years',
      one: 'every year',
    );
    String _temp4 = intl.Intl.selectLogic(unit, {
      'day': '$_temp0',
      'week': '$_temp1',
      'month': '$_temp2',
      'other': '$_temp3',
    });
    return '$_temp4';
  }

  @override
  String paywallPricePerPeriod(String price, String period) {
    return '$price per $period';
  }

  @override
  String paywallRenews(String every, String price) {
    return 'Renews automatically $every at $price until you cancel.';
  }

  @override
  String get paywallOneTime => 'One-time purchase, never renews.';

  @override
  String get paywallCancelAppStore =>
      'Cancel anytime in Settings › your name › Subscriptions, at least 24 hours before renewal.';

  @override
  String get paywallCancelGooglePlay =>
      'Cancel anytime in Google Play › Payments & subscriptions › Subscriptions.';

  @override
  String paywallSubscribe(String price, String period) {
    return 'Subscribe for $price per $period';
  }

  @override
  String paywallBuyOnce(String price) {
    return 'Buy for $price';
  }

  @override
  String get paywallRestore => 'Restore purchases';

  @override
  String get paywallTerms => 'Terms';

  @override
  String get paywallPrivacy => 'Privacy';

  @override
  String get paywallLoading => 'Loading prices';
}
