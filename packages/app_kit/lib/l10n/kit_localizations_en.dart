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
      other: '$count days',
      one: 'day',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: 'week',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: 'month',
    );
    String _temp3 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
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
  String paywallPricePerPeriod(String price, String period) {
    return '$price / $period';
  }

  @override
  String paywallRenews(String price, String period) {
    return 'Renews automatically at $price / $period, at the end of each period, until you cancel.';
  }

  @override
  String get paywallOneTime => 'One-time purchase, never renews.';

  @override
  String get paywallCancelAppStore =>
      'Cancel anytime, at least 24 hours before renewal, in Settings › your name › Subscriptions.';

  @override
  String get paywallCancelGooglePlay =>
      'Cancel anytime in Google Play › Payments & subscriptions › Subscriptions.';

  @override
  String paywallSubscribe(String price, String period) {
    return 'Subscribe for $price / $period';
  }

  @override
  String paywallBuyOnce(String price) {
    return 'Buy for $price';
  }

  @override
  String get paywallRestore => 'Restore purchases';

  @override
  String get paywallTerms => 'Terms of use';

  @override
  String get paywallPrivacy => 'Privacy policy';

  @override
  String get paywallLoading => 'Loading prices';
}
