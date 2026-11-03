import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('installCrashReporter sends Flutter and async errors to the reporter, then restores the handlers', () {
    final crash = FakeCrashReporter();
    final flutterBefore = FlutterError.onError;
    final platformBefore = PlatformDispatcher.instance.onError;

    final restore = installCrashReporter(crash);
    FlutterError.reportError(FlutterErrorDetails(exception: StateError('in a widget'), stack: StackTrace.current));
    final handled = PlatformDispatcher.instance.onError!(StateError('async'), StackTrace.current);
    restore();

    expect(FlutterError.onError, same(flutterBefore));
    expect(PlatformDispatcher.instance.onError, same(platformBefore));
    expect(handled, isTrue);
    expect(
      [for (final e in crash.errors) ((e.error as StateError).message, e.stack != null, e.fatal)],
      [('in a widget', true, false), ('async', true, true)],
    );
  });

  test('installCrashReporter passes Flutter errors on to the handler it replaced', () {
    final before = FlutterError.onError;
    addTearDown(() => FlutterError.onError = before);
    final seen = <Object>[];
    FlutterError.onError = (details) => seen.add(details.exception);

    final restore = installCrashReporter(FakeCrashReporter());
    FlutterError.reportError(FlutterErrorDetails(exception: StateError('in a widget')));
    restore();

    expect(seen, [isStateError]);
  });
}
