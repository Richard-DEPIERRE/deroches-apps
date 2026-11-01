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
      'This part of the app couldn\'t be shown. Close the app and open it again. If it keeps happening, write to us from Settings.';
}
