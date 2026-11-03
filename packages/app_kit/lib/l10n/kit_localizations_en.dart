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
}
