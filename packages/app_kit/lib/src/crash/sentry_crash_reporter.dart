import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
// ignore: implementation_imports
import 'package:sentry_flutter/src/exception/flutter_error_integration.dart';

import '../config/app_config.dart';
import '../data/kit_state.dart';
import 'crash_reporter.dart';

/// The breadcrumb category of the kit's own notes; Sentry drops every other.
const kitBreadcrumbCategory = 'kit';

/// Starts Sentry (ADR 0005) and returns the reporter to give [KitApp].
///
/// Only in release builds of an app whose config has a [AppConfig.sentryDsn];
/// otherwise nothing starts and nothing is sent. Nothing starts either while
/// the settings switch "Share anonymous usage statistics and crash reports"
/// is off, or while [kitState] isn't loaded (ADR 0005, section 2): load it
/// first. Turning the switch off takes effect at the next launch.
Future<CrashReporter> startCrashReporting(
  AppConfig config, {
  required KitStateController kitState,
  @visibleForTesting bool releaseBuild = kReleaseMode,
}) async {
  final dsn = config.sentryDsn;
  final allowed = kitState.state?.analyticsEnabled ?? false;
  if (!releaseBuild || dsn == null || !allowed) return const NoopCrashReporter();
  WidgetsFlutterBinding.ensureInitialized();
  final info = await PackageInfo.fromPlatform();
  await SentryFlutter.init(
    (options) => configureSentry(options, dsn: dsn, slug: config.slug, version: info.version, build: info.buildNumber),
  );
  return SentryCrashReporter();
}

/// Sets Sentry up as ADR 0005 section 2 says: anonymous, kit breadcrumbs only.
@visibleForTesting
void configureSentry(
  SentryFlutterOptions options, {
  required String dsn,
  required String slug,
  required String version,
  required String build,
}) {
  options
    ..dsn = dsn
    ..release = '$slug@$version+$build'
    ..dist = build
    ..environment = 'production'
    ..sendDefaultPii = false
    ..enableAutoNativeBreadcrumbs = false
    ..enablePrintBreadcrumbs = false
    ..enableUserInteractionBreadcrumbs = false
    ..beforeBreadcrumb = _kitBreadcrumbOnly
    ..beforeSend = _anonymous;
  // The kit's hook (installCrashReporter) reports Flutter errors and then calls
  // the handler it replaced. Left in, Sentry's handler would send a second,
  // fatal copy of each error and lower crash-free users.
  options.integrations.whereType<FlutterErrorIntegration>().toList().forEach(options.removeIntegration);
}

Breadcrumb? _kitBreadcrumbOnly(Breadcrumb? crumb, Hint _) => crumb?.category == kitBreadcrumbCategory ? crumb : null;

SentryEvent _anonymous(SentryEvent event, Hint _) => event
  ..user = null
  ..serverName = null
  ..request = null
  ..breadcrumbs = event.breadcrumbs?.where((b) => b.category == kitBreadcrumbCategory).toList()
  ..contexts.device?.name = null
  ..contexts.app?.deviceAppHash = null
  // Its widget descriptions can quote what the user typed.
  ..contexts.remove('flutter_error_details');

/// Sends the kit's errors and breadcrumbs to Sentry.
class SentryCrashReporter implements CrashReporter {
  SentryCrashReporter([Hub? hub]) : _hub = hub ?? HubAdapter();

  final Hub _hub;

  /// Only an error nothing caught ([fatal]) counts as a crash in crash-free users.
  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) => unawaited(
    _hub.captureEvent(
      SentryEvent(
        throwable: ThrowableMechanism(
          Mechanism(type: fatal ? 'PlatformDispatcher.onError' : 'FlutterError', handled: !fatal),
          error,
        ),
        level: fatal ? SentryLevel.fatal : SentryLevel.error,
      ),
      stackTrace: stack,
    ),
  );

  @override
  void addBreadcrumb(String message) =>
      unawaited(_hub.addBreadcrumb(Breadcrumb(message: message, category: kitBreadcrumbCategory)));
}
