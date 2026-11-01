import 'package:flutter/foundation.dart';

/// Where the kit sends errors (ADR 0001, section 6). The real tool is DAPP-12's.
///
/// Never put personal data in an error message or a breadcrumb.
abstract interface class CrashReporter {
  /// Records an error with its stack; [fatal] when nothing caught it.
  void recordError(Object error, StackTrace? stack, {bool fatal = false});

  /// Adds a short note of what the user just did, without personal data.
  void addBreadcrumb(String message);
}

/// Drops everything, until the crash tool is chosen.
class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {}

  @override
  void addBreadcrumb(String message) {}
}

/// Sends framework and uncaught async errors to [reporter].
///
/// Returns a function that puts the previous handlers back.
VoidCallback installCrashReporter(CrashReporter reporter) {
  final previousFlutter = FlutterError.onError;
  final previousPlatform = PlatformDispatcher.instance.onError;
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reporter.recordError(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.recordError(error, stack, fatal: true);
    return true;
  };
  return () {
    FlutterError.onError = previousFlutter;
    PlatformDispatcher.instance.onError = previousPlatform;
  };
}
