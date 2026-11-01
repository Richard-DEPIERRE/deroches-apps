import 'package:app_kit/app_kit.dart';
import 'package:app_kit/src/crash/sentry_crash_reporter.dart' show configureSentry;
import 'package:app_kit/testing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _dsn = 'https://public@o0.ingest.de.sentry.io/0';

AppConfig _config({String? sentryDsn = _dsn}) => AppConfig(
  slug: 'carnet-km',
  names: const {'fr': 'Carnet', 'en': 'Logbook'},
  supportEmail: 'support@example.fr',
  legal: {
    for (final lang in kitLanguages)
      lang: LegalLinks(
        legalNotice: Uri.parse('https://example.fr/$lang/legal'),
        privacy: Uri.parse('https://example.fr/$lang/privacy'),
        terms: Uri.parse('https://example.fr/$lang/terms'),
      ),
  },
  plans: const {Plan.yearly},
  sentryDsn: sentryDsn,
);

/// A hub set up as the kit sets Sentry up in a release build, sending to [transport].
Hub _hub(FakeSentryTransport transport) {
  final options = SentryFlutterOptions();
  configureSentry(options, dsn: _dsn, slug: 'carnet-km', version: '1.2.0', build: '14');
  options.transport = transport;
  return Hub(options);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a widget error and an async error both reach the transport', () async {
    final transport = FakeSentryTransport();
    final restore = installCrashReporter(SentryCrashReporter(_hub(transport)));
    FlutterError.reportError(FlutterErrorDetails(exception: StateError('in a widget'), stack: StackTrace.current));
    PlatformDispatcher.instance.onError!(StateError('async'), StackTrace.current);
    restore();
    await pumpEventQueue();

    final events = await transport.events();
    expect(
      [for (final e in events) e['exception']['values'][0]['value']],
      ['Bad state: in a widget', 'Bad state: async'],
    );
    // Only an error nothing caught counts as a crash in crash-free users.
    expect([for (final e in events) e['exception']['values'][0]['mechanism']['handled']], [true, false]);
    expect([for (final e in events) e['level']], ['error', 'fatal']);
  });

  test('releases are tagged with the slug, version and build', () async {
    final transport = FakeSentryTransport();
    SentryCrashReporter(_hub(transport)).recordError(StateError('x'), StackTrace.current);
    await pumpEventQueue();

    final event = (await transport.events()).single;
    expect(event['release'], 'carnet-km@1.2.0+14');
    expect(event['dist'], '14');
    expect(event['environment'], 'production');
  });

  test('a report carries no personal data, and only the kit breadcrumbs', () async {
    final transport = FakeSentryTransport();
    final hub = _hub(transport);
    final reporter = SentryCrashReporter(hub);
    await hub.configureScope((scope) => scope.setUser(SentryUser(id: 'u1', ipAddress: '1.2.3.4', email: 'a@b.fr')));
    await hub.addBreadcrumb(Breadcrumb(message: 'GET https://example.fr/?q=secret', category: 'http'));
    await hub.addBreadcrumb(Breadcrumb(message: 'user typed text', category: 'console'));
    await hub.addBreadcrumb(Breadcrumb(message: '/note/42', category: 'navigation'));
    reporter.addBreadcrumb('paywall.view.settings');
    await hub.captureEvent(
      SentryEvent(
        serverName: 'Richard’s iPhone',
        request: SentryRequest(url: 'https://example.fr/'),
        user: SentryUser(id: 'u2'),
        contexts: Contexts(
          device: SentryDevice(name: 'Richard’s iPhone'),
          app: SentryApp(deviceAppHash: 'abc'),
        )..['flutter_error_details'] = {'information': 'Text("what the user typed")'},
      ),
    );
    await pumpEventQueue();

    final event = (await transport.events()).single;
    expect(event, isNot(contains('user')));
    expect(event, isNot(contains('server_name')));
    expect(event, isNot(contains('request')));
    expect(event['contexts'], isNot(contains('flutter_error_details')));
    expect(event['contexts']['device'] ?? <String, dynamic>{}, isNot(contains('name')));
    expect(event['contexts']['app'] ?? <String, dynamic>{}, isNot(contains('device_app_hash')));
    expect([for (final b in event['breadcrumbs'] as List) b['message']], ['paywall.view.settings']);
  });

  test('the SDK is set to collect nothing more', () {
    final options = SentryFlutterOptions();
    configureSentry(options, dsn: _dsn, slug: 'carnet-km', version: '1.2.0', build: '14');
    expect(options.sendDefaultPii, isFalse);
    expect(options.enableAutoSessionTracking, isTrue);
    expect(options.sampleRate, anyOf(isNull, 1.0));
    expect(options.tracesSampleRate, isNull);
    expect(options.attachScreenshot || options.attachViewHierarchy, isFalse);
    expect(options.enableAutoNativeBreadcrumbs, isFalse);
    expect(options.enablePrintBreadcrumbs, isFalse);
    expect(options.enableUserInteractionBreadcrumbs, isFalse);
  });

  test('debug builds, and apps without a DSN, send nothing', () async {
    for (final (config, release) in [(_config(), false), (_config(sentryDsn: null), true)]) {
      final reporter = await startCrashReporting(config, releaseBuild: release);
      expect(reporter, isA<NoopCrashReporter>());
      expect(Sentry.isEnabled, isFalse);
    }
  });
}
