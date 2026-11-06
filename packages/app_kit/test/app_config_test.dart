import 'package:app_kit/app_kit.dart';
import 'package:flutter_test/flutter_test.dart';

LegalLinks _links(String lang) => LegalLinks(
  legalNotice: Uri.parse('https://example.fr/$lang/legal'),
  privacy: Uri.parse('https://example.fr/$lang/privacy'),
  terms: Uri.parse('https://example.fr/$lang/terms'),
);

AppConfig _config({
  String slug = 'carnet-km',
  Map<String, String> names = const {'fr': 'Carnet', 'en': 'Logbook'},
  String supportEmail = 'support@example.fr',
  Map<String, LegalLinks>? legal,
  Set<Plan> plans = const {Plan.yearly, Plan.lifetime},
  String? sentryDsn,
  String? postHogKey,
  String? revenueCatAppleKey,
  String? revenueCatGoogleKey,
  String? appStoreId,
}) => AppConfig(
  slug: slug,
  names: names,
  supportEmail: supportEmail,
  legal: legal ?? {'fr': _links('fr'), 'en': _links('en')},
  plans: plans,
  sentryDsn: sentryDsn,
  postHogKey: postHogKey,
  revenueCatAppleKey: revenueCatAppleKey,
  revenueCatGoogleKey: revenueCatGoogleKey,
  appStoreId: appStoreId,
);

void main() {
  test('a complete config has no problems', () {
    expect(_config().problems, isEmpty);
    expect(_config().check, returnsNormally);
  });

  test('the paywall preselects the yearly plan unless the app says otherwise', () {
    expect(_config().preselectedPlan, Plan.yearly);
  });

  test('the App Store id is digits, when there is one', () {
    expect(_config(appStoreId: '6478123456').problems, isEmpty);
    for (final bad in ['', 'id6478123456', '6478 123', 'fr.example.carnet']) {
      expect(_config(appStoreId: bad).problems, [contains('App Store id')], reason: bad);
    }
  });

  test('the slug must be the store wrapper form', () {
    for (final bad in ['Carnet', 'carnet_km', '-carnet', 'carnet-', '']) {
      expect(_config(slug: bad).problems, [contains('slug')], reason: bad);
    }
  });

  test('both languages need a name and legal links', () {
    final config = _config(
      names: const {'fr': 'Carnet'},
      legal: {'fr': _links('fr')},
    );
    expect(config.problems, [
      'no app name in "en"',
      'no legal links in "en"',
    ]);
  });

  test('legal links must be https', () {
    final config = _config(
      legal: {
        'fr': _links('fr'),
        'en': LegalLinks(
          legalNotice: Uri.parse('http://example.fr/en/legal'),
          privacy: Uri.parse('https://example.fr/en/privacy'),
          terms: Uri.parse('https://example.fr/en/terms'),
        ),
      },
    );
    expect(config.problems, [contains('not https')]);
  });

  test('an app sells at least one plan and has a support address', () {
    final config = _config(plans: const {}, supportEmail: 'support');
    expect(config.problems, hasLength(2));
    expect(config.check, throwsStateError);
  });

  test('a crash-reporting DSN, when given, is an https URL', () {
    expect(_config(sentryDsn: 'https://public@o0.ingest.de.sentry.io/0').problems, isEmpty);
    expect(_config(sentryDsn: 'http://public@o0.ingest.de.sentry.io/0').problems, [contains('DSN')]);
    expect(_config(sentryDsn: '').problems, [contains('DSN')]);
  });

  test('a PostHog key, when given, is a public project key', () {
    expect(_config(postHogKey: 'phc_aBc123').problems, isEmpty);
    expect(_config(postHogKey: 'phx_personalApiKey').problems, [contains('PostHog')], reason: 'a personal API key is a secret');
    expect(_config(postHogKey: '').problems, [contains('PostHog')]);
  });

  test('RevenueCat keys, when given, are its public SDK keys, never a secret one', () {
    expect(_config(revenueCatAppleKey: 'appl_abc', revenueCatGoogleKey: 'goog_abc').problems, isEmpty);
    expect(_config(revenueCatAppleKey: 'sk_abc').problems, [contains('Apple')]);
    expect(_config(revenueCatGoogleKey: 'sk_abc').problems, [contains('Google')]);
    expect(_config(revenueCatGoogleKey: 'appl_abc').problems, [contains('Google')]);
  });
}
