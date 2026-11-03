// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'example_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class ExampleLocalizationsEn extends ExampleLocalizations {
  ExampleLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get exampleHomeBody =>
      'This is the kit\'s sample app. Its screens never ship.';

  @override
  String get exampleOnboarding1Title => 'Welcome';

  @override
  String get exampleOnboarding1Body =>
      'This page shows how an app introduces itself on first launch.';

  @override
  String get exampleOnboarding2Title => 'Your data stays on your phone';

  @override
  String get exampleOnboarding2Body =>
      'Nothing you write leaves the device. You can skip these pages at any time.';

  @override
  String get exampleGoodMoment => 'Something went well';
}
