import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import 'analytics.dart';

/// Sends the kit's checked events to PostHog EU, anonymously (ADR 0001,
/// section 5). Never calls `identify`, and installs no `PosthogObserver`, so
/// no screen is captured on its own.
class PostHogBackend implements AnalyticsBackend {
  PostHogBackend(this.projectKey);

  /// The project's public key (`phc_…`), from `AppConfig.postHogKey`.
  final String projectKey;

  @override
  Future<void> start() => Posthog().setup(postHogConfig(projectKey));

  @override
  Future<void> stop() => Posthog().close();

  @override
  Future<void> capture(String event, Map<String, Object> properties) =>
      Posthog().capture(eventName: event, properties: properties);
}

/// EU host; no person profiles, session replay, lifecycle or tap autocapture,
/// feature flags, surveys, push capture or error tracking.
@visibleForTesting
PostHogConfig postHogConfig(String projectKey) => PostHogConfig(projectKey)
  ..host = 'https://eu.i.posthog.com'
  ..personProfiles = PostHogPersonProfiles.never
  ..sessionReplay = false
  ..captureApplicationLifecycleEvents = false
  ..rageClickConfig.enabled = false
  ..preloadFeatureFlags = false
  ..sendFeatureFlagEvent = false
  ..surveys = false
  ..capturePushNotificationSubscriptions = false
  ..capturePushNotificationOpened = false
  ..errorTrackingConfig.captureNativeExceptions = false;
