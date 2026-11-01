import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/kit_localizations.dart';
import '../config/app_config.dart';
import '../crash/crash_reporter.dart';
import '../l10n/language.dart';
import 'kit_error_view.dart';
import 'kit_scope.dart';

/// The frame every app starts in (ADR 0001, sections 3, 6 and 7).
///
/// Refuses an invalid [config] at once, so a bad config fails at start-up.
class KitApp extends StatefulWidget {
  KitApp({
    super.key,
    required this.config,
    required this.seedColor,
    required this.home,
    this.fontFamily,
    this.localizationsDelegates = const [],
    this.crashReporter = const NoopCrashReporter(),
    this.languageOverride,
  }) {
    config.check();
  }

  final AppConfig config;

  /// The app's brand colour; the light and dark colour schemes grow from it.
  final Color seedColor;

  /// The app's bundled font family; `null` keeps the platform's.
  final String? fontFamily;

  final WidgetBuilder home;

  /// The app's own localization delegates; the kit adds its own and Flutter's.
  final List<LocalizationsDelegate<Object?>> localizationsDelegates;

  final CrashReporter crashReporter;

  /// The language the user picked; the kit makes one when none is given.
  final ValueNotifier<Locale?>? languageOverride;

  @override
  State<KitApp> createState() => _KitAppState();
}

class _KitAppState extends State<KitApp> {
  late final ValueNotifier<Locale?> _ownOverride = ValueNotifier(null);
  late final VoidCallback _uninstallCrashReporter;
  final ErrorWidgetBuilder _previousErrorBuilder = ErrorWidget.builder;

  ValueNotifier<Locale?> get _override => widget.languageOverride ?? _ownOverride;

  @override
  void initState() {
    super.initState();
    _uninstallCrashReporter = installCrashReporter(widget.crashReporter);
    if (kReleaseMode) ErrorWidget.builder = (_) => const KitErrorView();
  }

  @override
  void dispose() {
    _uninstallCrashReporter();
    ErrorWidget.builder = _previousErrorBuilder;
    _ownOverride.dispose();
    super.dispose();
  }

  ThemeData _theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: widget.seedColor, brightness: brightness),
    fontFamily: widget.fontFamily,
  );

  @override
  Widget build(BuildContext context) {
    return KitScope(
      config: widget.config,
      crashReporter: widget.crashReporter,
      languageOverride: _override,
      child: ValueListenableBuilder(
        valueListenable: _override,
        builder: (context, override, _) => MaterialApp(
          onGenerateTitle: (context) => widget.config.names[Localizations.localeOf(context).languageCode]!,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          locale: override,
          supportedLocales: kitLocales,
          localeListResolutionCallback: (locales, _) => resolveKitLocale(locales),
          localizationsDelegates: [...widget.localizationsDelegates, ...KitLocalizations.localizationsDelegates],
          home: Builder(builder: widget.home),
        ),
      ),
    );
  }
}
