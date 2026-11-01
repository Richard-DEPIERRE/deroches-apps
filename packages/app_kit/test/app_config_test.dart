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
}) => AppConfig(
  slug: slug,
  names: names,
  supportEmail: supportEmail,
  legal: legal ?? {'fr': _links('fr'), 'en': _links('en')},
  plans: plans,
);

void main() {
  test('a complete config has no problems', () {
    expect(_config().problems, isEmpty);
    expect(_config().check, returnsNormally);
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
}
