/// Fakes and helpers for tests of the kit and of every app (ADR 0001, section 3).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app_kit.dart';

/// One error a [FakeCrashReporter] received.
typedef RecordedError = ({Object error, StackTrace? stack, bool fatal});

/// Keeps what it is given, so a test can check it.
class FakeCrashReporter implements CrashReporter {
  final errors = <RecordedError>[];
  final breadcrumbs = <String>[];

  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) =>
      errors.add((error: error, stack: stack, fatal: fatal));

  @override
  void addBreadcrumb(String message) => breadcrumbs.add(message);
}

/// One event a [FakeAnalyticsBackend] received, envelope included.
typedef SentEvent = ({String name, Map<String, Object> properties});

/// Keeps the events [Analytics] would send, instead of sending them.
class FakeAnalyticsBackend implements AnalyticsBackend {
  final events = <SentEvent>[];
  bool started = false;

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> stop() async => started = false;

  @override
  Future<void> capture(String event, Map<String, Object> properties) async =>
      events.add((name: event, properties: properties));
}

/// Plays the store: the `default` offering's three packages, at made-up prices.
class FakePurchasesBackend implements PurchasesBackend {
  final storePackages = [
    const StorePackage(id: r'$rc_weekly', price: '0,99\u00a0€', period: 'P1W'),
    const StorePackage(id: r'$rc_annual', price: '9,99\u00a0€', period: 'P1Y'),
    const StorePackage(id: r'$rc_lifetime', price: '24,99\u00a0€'),
  ];

  /// What the next [buy] returns; a [Purchased] turns the entitlement on.
  PurchaseResult nextResult = const Purchased();

  /// The store account owns a plan, so [restore] finds it.
  bool ownedOnStore = false;

  /// [restore] can't reach the store.
  bool failRestore = false;

  /// [packages] can't reach the store.
  bool failPackages = false;

  @override
  Uri? manageUrl;

  /// While set and not complete, [packages] waits for it: the prices are loading.
  Completer<void>? holdPackages;

  /// The package ids bought, in order.
  final bought = <String>[];

  @override
  final ValueNotifier<bool> entitled = ValueNotifier(false);

  @override
  Future<List<StorePackage>> packages() async {
    await holdPackages?.future;
    if (failPackages) throw StateError('store unreachable');
    return List.of(storePackages);
  }

  @override
  Future<PurchaseResult> buy(String id) async {
    bought.add(id);
    if (nextResult is Purchased) entitled.value = ownedOnStore = true;
    return nextResult;
  }

  @override
  Future<void> restore() async {
    if (failRestore) throw StateError('store unreachable');
    entitled.value = ownedOnStore;
  }
}

/// Counts the rating prompts the kit asked the platform for.
class FakeStoreReview implements StoreReview {
  /// False plays a platform without the store's prompt.
  bool available = true;
  int requests = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => requests++;
}

/// Plays the system save dialog and file picker: keeps what was saved, and
/// hands back [picked] (null: the user cancels the picker).
class FakeBackupFiles implements BackupFiles {
  List<int>? picked;

  /// The user cancels the save dialog.
  bool cancelSave = false;

  /// File name → bytes.
  final saved = <String, Uint8List>{};

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    if (!cancelSave) saved[fileName] = bytes;
    return !cancelSave;
  }

  @override
  Future<Uint8List?> pick({required int maxBytes}) async => switch (picked) {
    final bytes? when bytes.length > maxBytes => throw BackupTooLarge(bytes.length),
    final bytes? => Uint8List.fromList(bytes),
    null => null,
  };
}

/// Keeps what Sentry would send, instead of sending it.
class FakeSentryTransport implements Transport {
  final envelopes = <SentryEnvelope>[];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return SentryId.newId();
  }

  /// The events sent, as the JSON Sentry would receive.
  Future<List<Map<String, dynamic>>> events() async => [
    for (final envelope in envelopes)
      for (final item in envelope.items)
        if (item.header.type == 'event') jsonDecode(utf8.decode(await item.dataFactory())) as Map<String, dynamic>,
  ];
}

/// Every message of the [templatePath] ARB file that is missing or empty in [translationPath].
List<String> arbProblems(String templatePath, String translationPath) {
  Map<String, dynamic> read(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  final translation = read(translationPath);
  return [
    for (final key in read(templatePath).keys.where((k) => !k.startsWith('@')))
      if (!translation.containsKey(key))
        'missing "$key"'
      else if ((translation[key] as String).trim().isEmpty)
        'empty "$key"',
  ];
}

/// Pumps [child] in [locale] on a small phone (320 x 568 points) at twice the
/// normal text size, with the kit's localizations.
Future<void> pumpOnSmallPhone(
  WidgetTester tester,
  Locale locale,
  Widget child, {
  List<LocalizationsDelegate<Object?>> localizationsDelegates = const [],
}) async {
  tester.view
    ..physicalSize = const Size(640, 1136)
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: kitLocales,
      localizationsDelegates: [...localizationsDelegates, ...KitLocalizations.localizationsDelegates],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

/// The data-upgrade test (ADR 0001, section 8). Call it from the app's
/// `test/data_upgrade/` test's `main`.
///
/// Every `*.json` file in [fixtures] is a document written by a released
/// version's own code, with made-up content. Each one is opened through
/// [DataStore] as document [name], upgraded with [migrations], decoded with
/// [decode] into a list of items, and must equal `expected[<file name>]`
/// item for item, with the same count: nothing silently dropped. It is then
/// opened a second time, from the upgraded file, and must read back the same.
///
/// Likewise every `*.json` file in [backups] is a backup file a released
/// version exported: it is restored through [BackupService] and document
/// [name] must hold `expectedBackups[<file name>]`.
void dataUpgradeTests<T>({
  required String fixtures,
  required String appId,
  required String name,
  required List<Migration> migrations,
  required List<T> Function(Map<String, Object?> data) decode,
  required Map<String, List<T>> expected,
  String? backups,
  Map<String, List<T>> expectedBackups = const {},
}) {
  List<File> jsonFiles(String dir) =>
      Directory(dir).listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
  final files = jsonFiles(fixtures);
  String fileName(File f) => f.uri.pathSegments.last;

  test('every fixture has its expected items, and every expectation a fixture', () {
    expect(files, isNotEmpty, reason: 'no fixture in $fixtures');
    expect(files.map(fileName).toSet(), expected.keys.toSet());
  });

  for (final fixture in files) {
    test('${fileName(fixture)} upgrades to schema ${migrations.length + 1} with nothing lost', () async {
      final want = expected[fileName(fixture)];
      if (want == null) fail('no expected items for ${fileName(fixture)}');
      final dir = Directory.systemTemp.createTempSync('data_upgrade_');
      addTearDown(() => dir.deleteSync(recursive: true));
      fixture.copySync('${dir.path}/$name.json');

      DataStore store() => DataStore(
        directory: dir,
        appId: appId,
        name: name,
        migrations: migrations,
        initial: () => fail('${fileName(fixture)} opened as an empty state'),
      );

      for (final pass in ['upgraded', 'read back']) {
        final items = decode(await store().open());
        expect(items.length, want.length, reason: '${fileName(fixture)}, $pass: item count');
        expect(items, want, reason: '${fileName(fixture)}, $pass');
      }
    });
  }

  if (backups == null) return;
  final backupFiles = jsonFiles(backups);
  test('every backup fixture has its expected items, and every expectation a fixture', () {
    expect(backupFiles, isNotEmpty, reason: 'no backup fixture in $backups');
    expect(backupFiles.map(fileName).toSet(), expectedBackups.keys.toSet());
  });
  for (final backup in backupFiles) {
    test('${fileName(backup)} restores to schema ${migrations.length + 1} with nothing lost', () async {
      final dir = Directory.systemTemp.createTempSync('backup_upgrade_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = DataStore(directory: dir, appId: appId, name: name, migrations: migrations, initial: () => {});
      final files = FakeBackupFiles()..picked = backup.readAsBytesSync();
      final result = await BackupService(appId: appId, stores: [store], files: files).restore();
      expect(result, isA<BackupDone>(), reason: '$result');
      final items = decode(await store.open());
      expect(items.length, expectedBackups[fileName(backup)]?.length, reason: '${fileName(backup)}: item count');
      expect(items, expectedBackups[fileName(backup)], reason: fileName(backup));
    });
  }
}

/// A store screenshot size (ADR 0001, section 11). Checked 2026-11-03:
/// - App Store Connect, "Screenshot specifications"
///   (developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications):
///   an iPhone app needs "iPhone with Dynamic Island (large display)" shots, 1320 × 2868 among its sizes
///   (else the Face ID large ones); no alpha. iPhone Duo shots become required in April 2027 for apps built
///   with the iOS 27.1 SDK.
/// - Google Play, "Add preview assets" (support.google.com/googleplay/android-developer/answer/9866151):
///   24-bit PNG with no alpha, 320 to 3840 px, the long side at most twice the short one; 9:16 at
///   1080 × 1920 or more for the large-format promotions.
class ScreenshotDevice {
  const ScreenshotDevice._(this.platform, this.size, this.pixelRatio, this.padding);

  /// iPhone 17 Pro Max: 440 × 956 points at 3×, 1320 × 2868 pixels.
  static const iPhone = ScreenshotDevice._(TargetPlatform.iOS, Size(440, 956), 3, EdgeInsets.only(top: 62, bottom: 34));

  /// A 9:16 Play phone: 432 × 768 points at 2.5×, 1080 × 1920 pixels.
  static const androidPhone = ScreenshotDevice._(
    TargetPlatform.android,
    Size(432, 768),
    2.5,
    EdgeInsets.only(top: 24, bottom: 24),
  );

  final TargetPlatform platform;
  final Size size;
  final double pixelRatio;

  /// The phone's safe area (Dynamic Island and home indicator; status and
  /// navigation bars), left empty: no status bar is drawn.
  final EdgeInsets padding;

  /// Where the store wrapper's `listing --metadata <dir>` takes this device's shots in [locale] (fastlane
  /// deliver's and supply's layouts): `ios/screenshots/fr-FR`, `android/fr-FR/images/phoneScreenshots`.
  String folder(Locale locale) => platform == TargetPlatform.iOS
      ? 'ios/screenshots/${locale.toLanguageTag()}'
      : 'android/${locale.toLanguageTag()}/images/phoneScreenshots';
}

/// A store image's caption: [text] from the app's ARB, on the app's own
/// [background] colour, in the app's own heading [style] (family, weight,
/// size, height), so no two apps share a store look. Without a colour in
/// [style], the text is white or black, whichever contrasts more.
class StoreCaption {
  const StoreCaption(this.text, {required this.background, required this.style});

  final String text;
  final Color background;
  final TextStyle style;
}

/// Renders [app] (a whole app, such as the app's `KitApp`) on [device], with
/// the phone set to [locale] (with its country, as the stores name it:
/// `fr-FR`) and [brightness], its safe area, and the app's bundled fonts,
/// Roboto and the Material icons loaded; then writes it as a store PNG (RGB,
/// no alpha) to `<dir>/<device.folder(locale)>/<name>.png`. Feed it made-up
/// data only.
///
/// With [caption], the store image: the caption in a band of fixed height (two
/// lines, balanced), and the screen below it, smaller, at the same place in
/// every shot. The test fails when a caption needs more than two lines or has
/// less than 4.5:1 contrast. Tag the test `screenshots`;
/// `tool/screenshots.sh <app-dir>` runs them.
Future<File> takeScreenshot(
  WidgetTester tester,
  Widget app, {
  required ScreenshotDevice device,
  required Locale locale,
  required String name,
  Brightness brightness = Brightness.light,
  StoreCaption? caption,
  String dir = 'store',
}) async {
  await tester.runAsync(_loadFonts);
  final ratio = device.pixelRatio;
  tester.view
    ..physicalSize = device.size * ratio
    ..devicePixelRatio = ratio
    ..padding = FakeViewPadding(top: device.padding.top * ratio, bottom: device.padding.bottom * ratio)
    ..viewPadding = FakeViewPadding(top: device.padding.top * ratio, bottom: device.padding.bottom * ratio);
  tester.platformDispatcher
    ..localesTestValue = [locale]
    ..platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final key = GlobalKey();
  final screenKey = GlobalKey();
  final screen = SizedBox.fromSize(key: screenKey, size: device.size, child: app);
  Widget Function(Color? outline) frame = (_) => screen;
  if (caption != null) {
    final band = caption.background;
    final style = caption.style.copyWith(
      color:
          caption.style.color ??
          (_contrast(Colors.white, band) >= _contrast(Colors.black, band) ? Colors.white : Colors.black),
    );
    expect(_contrast(style.color!, band), greaterThanOrEqualTo(4.5), reason: 'caption contrast');
    int linesAt(double width) {
      final painter = TextPainter(
        text: TextSpan(text: caption.text, style: style),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      final lines = painter.computeLineMetrics().length;
      painter.dispose();
      return lines;
    }

    // The narrowest width that keeps the line count balances the lines.
    var width = device.size.width - 64;
    final lines = linesAt(width);
    expect(lines, lessThanOrEqualTo(2), reason: '"${caption.text}" takes $lines lines');
    while (width > 40 && linesAt(width - 2) == lines) {
      width -= 2;
    }
    frame = (outline) => ColoredBox(
      color: band,
      child: Column(
        children: [
          SizedBox(
            height: 88 + 2 * (style.fontSize ?? 14) * (style.height ?? 1.2),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 56, 32, 32),
              child: Center(
                child: SizedBox(
                  width: width,
                  child: Text(
                    caption.text,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: style,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
              child: FittedBox(
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: outline == null ? null : Border.all(color: outline),
                    borderRadius: BorderRadius.circular(48),
                  ),
                  child: ClipRRect(borderRadius: BorderRadius.circular(48), child: screen),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // Widget tests draw shadows as outlines and every platform as Android, unless told otherwise;
  // debug builds draw the DEBUG banner, which no store image may show.
  debugDisableShadows = false;
  WidgetsApp.debugAllowBannerOverride = false;
  debugDefaultTargetPlatformOverride = device.platform;
  try {
    await tester.pumpWidget(RepaintBoundary(key: key, child: frame(null)));
    await tester.pumpAndSettle();
    // A screen too close in colour to the band gets a hairline edge.
    final scaffold = find.descendant(of: find.byKey(screenKey), matching: find.byType(Scaffold));
    if (caption != null && scaffold.evaluate().isNotEmpty) {
      final theme = Theme.of(tester.element(scaffold.first));
      if (_contrast(theme.scaffoldBackgroundColor, caption.background) < 1.5) {
        await tester.pumpWidget(
          RepaintBoundary(key: key, child: frame(theme.colorScheme.onSurface.withValues(alpha: 0.12))),
        );
        await tester.pumpAndSettle();
      }
    }
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final png = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: ratio);
      final rgba = await image.toByteData();
      final png = _rgbPng(image.width, image.height, rgba!.buffer.asUint8List());
      image.dispose();
      return png;
    });
    final file = File('$dir/${device.folder(locale)}/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(png!);
    return file;
  } finally {
    debugDisableShadows = true;
    WidgetsApp.debugAllowBannerOverride = true;
    debugDefaultTargetPlatformOverride = null;
  }
}

/// The WCAG contrast ratio of two colours, from 1 to 21.
double _contrast(Color a, Color b) {
  final (x, y) = (a.computeLuminance() + 0.05, b.computeLuminance() + 0.05);
  return x > y ? x / y : y / x;
}

/// The pixel size of a PNG file, and whether it has an alpha channel.
({int width, int height, bool alpha}) pngInfo(File file) {
  final header = ByteData.sublistView(file.readAsBytesSync(), 16, 26);
  return (width: header.getUint32(0), height: header.getUint32(4), alpha: header.getUint8(9) & 4 != 0);
}

bool _fontsLoaded = false;

/// The app's bundled fonts (its `FontManifest.json`, Material icons included)
/// and the SDK's Roboto, also standing in for the iPhone's system font,
/// which can't be bundled.
Future<void> _loadFonts() async {
  if (_fontsLoaded) return;
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  final sdkFonts = Directory('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts');
  final roboto = sdkFonts.listSync().whereType<File>().where((f) => RegExp(r'/Roboto-\w+\.ttf$').hasMatch(f.path));
  for (final family in ['Roboto', 'CupertinoSystemText', 'CupertinoSystemDisplay']) {
    final loader = FontLoader(family);
    for (final file in roboto) {
      loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }
  _fontsLoaded = true;
}

/// [rgba] (from [ui.Image.toByteData]) as an RGB PNG: the stores refuse alpha.
Uint8List _rgbPng(int width, int height, Uint8List rgba) {
  final rows = Uint8List(height * (1 + width * 3));
  for (var y = 0, i = 0, o = 0; y < height; y++) {
    rows[o++] = 0; // filter: none
    for (var x = 0; x < width; x++, i += 4) {
      rows[o++] = rgba[i];
      rows[o++] = rgba[i + 1];
      rows[o++] = rgba[i + 2];
    }
  }
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bits per channel
    ..setUint8(9, 2); // RGB
  return (BytesBuilder(copy: false)
        ..add(const [137, 80, 78, 71, 13, 10, 26, 10])
        ..add(_pngChunk('IHDR', header.buffer.asUint8List()))
        ..add(_pngChunk('IDAT', zlib.encode(rows)))
        ..add(_pngChunk('IEND', const [])))
      .takeBytes();
}

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = c & 1 != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
  }
  return c;
});

Uint8List _pngChunk(String type, List<int> data) {
  final body = Uint8List.fromList([...ascii.encode(type), ...data]);
  var crc = 0xFFFFFFFF;
  for (final byte in body) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >>> 8);
  }
  return (BytesBuilder(copy: false)
        ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
        ..add(body)
        ..add((ByteData(4)..setUint32(0, crc ^ 0xFFFFFFFF)).buffer.asUint8List()))
      .takeBytes();
}
