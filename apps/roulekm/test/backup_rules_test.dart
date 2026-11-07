import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Android Auto Backup takes the data documents to the user's Google account
/// (ADR 0001, section 9).
void main() {
  XmlElement root(String path) => XmlDocument.parse(File('android/app/src/main/$path').readAsStringSync()).rootElement;

  List<String> included(XmlElement section) => [
    for (final rule in section.childElements)
      if (rule.name.local == 'include') '${rule.getAttribute('domain')}:${rule.getAttribute('path')}',
  ];

  test('the manifest turns backup on with both rule files', () {
    final app = root('AndroidManifest.xml').getElement('application')!;
    String? attr(String name) => app.getAttribute(name, namespace: 'http://schemas.android.com/apk/res/android');
    expect(attr('allowBackup'), 'true');
    expect(attr('dataExtractionRules'), '@xml/data_extraction_rules');
    expect(attr('fullBackupContent'), '@xml/full_backup_content');
  });

  test('Android 12 and later back up and transfer the whole files folder, nothing excluded', () {
    final rules = root('res/xml/data_extraction_rules.xml');
    expect(rules.name.local, 'data-extraction-rules');
    for (final section in ['cloud-backup', 'device-transfer']) {
      final element = rules.getElement(section);
      expect(element, isNotNull, reason: section);
      expect(included(element!), ['file:.'], reason: section);
      expect(element.findElements('exclude'), isEmpty, reason: section);
    }
  });

  test('Android 11 and earlier back up the whole files folder, nothing excluded', () {
    final rules = root('res/xml/full_backup_content.xml');
    expect(rules.name.local, 'full-backup-content');
    expect(included(rules), ['file:.']);
    expect(rules.findElements('exclude'), isEmpty);
  });
}
