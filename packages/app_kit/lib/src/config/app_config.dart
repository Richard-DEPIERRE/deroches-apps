/// The plans an app can sell (ADR 0001, section 4).
enum Plan { weekly, yearly, lifetime }

/// The languages every app ships in, French first.
const kitLanguages = ['fr', 'en'];

/// The app's legal pages on its own site, in one language.
class LegalLinks {
  const LegalLinks({
    required this.legalNotice,
    required this.privacy,
    required this.terms,
  });

  final Uri legalNotice;
  final Uri privacy;
  final Uri terms;

  Iterable<Uri> get all => [legalNotice, privacy, terms];
}

/// What makes an app itself, as its `app-setup` document gives it.
///
/// Later kit modules add their fields (store ids, public SDK keys). An app
/// builds one `const AppConfig` and the kit refuses to start on [problems].
class AppConfig {
  const AppConfig({
    required this.slug,
    required this.names,
    required this.supportEmail,
    required this.legal,
    required this.plans,
    this.entitlementId = 'pro',
    this.sentryDsn,
    this.postHogKey,
    this.revenueCatAppleKey,
    this.revenueCatGoogleKey,
    this.appStoreId,
  });

  /// The store wrapper's slug: lowercase letters, digits and hyphens.
  final String slug;

  /// The app's name per language (`fr`, `en`).
  final Map<String, String> names;

  /// The app's own support address.
  final String supportEmail;

  /// The legal pages per language (`fr`, `en`).
  final Map<String, LegalLinks> legal;

  /// The plans this app sells; at least one.
  final Set<Plan> plans;

  /// The RevenueCat entitlement the plans unlock.
  final String entitlementId;

  /// The app's Sentry DSN, a public client key (ADR 0005); `null` sends no crash reports.
  final String? sentryDsn;

  /// The studio's PostHog project key, public by design (ADR 0001, section 5); `null` sends no analytics.
  final String? postHogKey;
  /// RevenueCat's public SDK keys for the App Store (`appl_…`) and Google
  /// Play (`goog_…`); `null` sells nothing on that platform. Never the secret
  /// API key (ADR 0001, section 13).
  final String? revenueCatAppleKey;
  final String? revenueCatGoogleKey;

  /// The app's Apple ID in App Store Connect (digits), for "Rate the app" on
  /// iOS; `null` hides that item there until the app has one.
  final String? appStoreId;

  static final _slug = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
  static final _digits = RegExp(r'^[0-9]+$');
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[a-z]{2,}$');

  /// Everything wrong with this config, in plain words; empty when valid.
  List<String> get problems => [
    if (!_slug.hasMatch(slug)) 'slug "$slug" is not lowercase letters, digits and hyphens',
    if (!_email.hasMatch(supportEmail)) 'support email "$supportEmail" is not an address',
    if (plans.isEmpty) 'no plan to sell',
    if (entitlementId.isEmpty) 'no entitlement id',
    if (sentryDsn != null && Uri.tryParse(sentryDsn!)?.scheme != 'https') 'Sentry DSN "$sentryDsn" is not an https URL',
    if (postHogKey != null && !postHogKey!.startsWith('phc_')) 'PostHog key is not a public project key (phc_…)',
    if (revenueCatAppleKey?.startsWith('appl_') == false) 'RevenueCat Apple key is not a public SDK key (appl_…)',
    if (revenueCatGoogleKey?.startsWith('goog_') == false) 'RevenueCat Google key is not a public SDK key (goog_…)',
    if (appStoreId != null && !_digits.hasMatch(appStoreId!)) 'App Store id "$appStoreId" is not digits',
    for (final lang in kitLanguages) ...[
      if ((names[lang] ?? '').trim().isEmpty) 'no app name in "$lang"',
      if (legal[lang] == null)
        'no legal links in "$lang"'
      else
        for (final uri in legal[lang]!.all)
          if (uri.scheme != 'https') 'legal link $uri in "$lang" is not https',
    ],
  ];

  /// Throws a [StateError] listing every problem, so a bad config fails at start-up.
  void check() {
    final found = problems;
    if (found.isNotEmpty) {
      throw StateError('AppConfig "$slug" is invalid:\n- ${found.join('\n- ')}');
    }
  }
}
