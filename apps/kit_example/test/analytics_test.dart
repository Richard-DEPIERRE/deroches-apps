import 'dart:io';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_example/notes.dart';

void main() {
  test('the sample app sends its own events through the kit, with the envelope', () async {
    final dir = Directory.systemTemp.createTempSync('example_analytics_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final kit = KitStateController(directory: dir, appId: notesAppId);
    await kit.load();
    final backend = FakeAnalyticsBackend();
    final analytics = Analytics(
      backend: backend,
      kitState: kit,
      appId: notesAppId,
      appVersion: '0.1.0',
      locale: () => 'en',
      appEvents: notesEvents,
    );

    analytics.track('notes.create.note', {'pinned': const Prop.flag(false)});
    await analytics.idle;

    expect(backend.events.single.name, 'notes.create.note');
    expect(backend.events.single.properties, containsPair('app_id', 'kit-example'));
    expect(() => analytics.track('notes.delete.note'), throwsArgumentError, reason: 'not registered');
  });
}
