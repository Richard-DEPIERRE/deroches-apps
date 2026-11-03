import 'dart:typed_data';

import 'package:app_kit/app_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

/// A picked file whose size is [size]; [known] is false when the picker
/// can't tell the size. [readAsBytes] fails the test: the real code reads in
/// chunks so it can stop at the limit.
final class _File extends PlatformFile {
  _File(this.size, {this.known = true});

  final int size;
  final bool known;
  int streamed = 0;

  @override
  String get name => 'backup.json';
  @override
  Uri get uri => Uri.file('/picked/backup.json');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation); // xFile: unused
  @override
  int? lengthSync() => known ? size : null;
  @override
  Future<int?> length() async => lengthSync();
  @override
  Future<Uint8List> readAsBytes() => fail('read the whole file');
  @override
  Stream<Uint8List> readAsByteStream() async* {
    const chunk = 1024;
    for (var sent = 0; sent < size; sent += chunk) {
      final n = size - sent < chunk ? size - sent : chunk;
      streamed += n;
      yield Uint8List(n);
    }
  }
}

final class _Picker extends FilePickerPlatform {
  _Picker(this.file);

  final PlatformFile? file;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => file;
}

void main() {
  const max = 4096;
  final original = FilePickerPlatform.instance;
  tearDown(() => FilePickerPlatform.instance = original);

  Future<Uint8List?> pick(PlatformFile? file) {
    FilePickerPlatform.instance = _Picker(file);
    return const SystemBackupFiles().pick(maxBytes: max);
  }

  test('a file over the limit is refused without reading it', () async {
    final file = _File(max + 1);
    await expectLater(pick(file), throwsA(isA<BackupTooLarge>()));
    expect(file.streamed, 0);
  });

  test('a file at the limit is read', () async {
    expect((await pick(_File(max)))!.length, max);
  });

  test('a file of unknown size stops being read once it is over the limit', () async {
    final file = _File(10 * max, known: false);
    await expectLater(pick(file), throwsA(isA<BackupTooLarge>()));
    expect(file.streamed, lessThan(2 * max));
  });

  test('a file of unknown size at the limit is read', () async {
    expect((await pick(_File(max, known: false)))!.length, max);
  });

  test('a cancelled picker gives null', () async {
    expect(await pick(null), isNull);
  });
}
