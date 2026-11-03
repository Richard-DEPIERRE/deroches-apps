import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'data_store.dart';

/// The system save dialog and file picker, where the user picks iCloud Drive,
/// Google Drive or anywhere else (ADR 0001, section 9).
abstract interface class BackupFiles {
  /// Offers [bytes] as [fileName] in the save dialog; false if the user cancelled.
  Future<bool> save(String fileName, Uint8List bytes);

  /// The picked file's bytes, or null if the user cancelled.
  Future<Uint8List?> pick();
}

class SystemBackupFiles implements BackupFiles {
  const SystemBackupFiles();

  @override
  Future<bool> save(String fileName, Uint8List bytes) async =>
      await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: 'application/json') != null;

  @override
  Future<Uint8List?> pick() async => (await FilePicker.pickFile())?.readAsBytes();
}

/// Why a backup was not made or not restored. The name is the analytics
/// detail: `backup.fail.<name in snake_case>`.
enum BackupFailure {
  /// Not a backup file, or a damaged one (cut short, edited).
  unreadable,

  /// Another app's backup.
  otherApp,

  /// Made by a newer version of the app: update the app first.
  newerSchema,

  /// The app's migrations couldn't upgrade it.
  migrationFailed,

  /// A file couldn't be read or written.
  fileError,
}

/// What the settings screen tells the user.
sealed class BackupResult {
  const BackupResult();
}

final class BackupDone extends BackupResult {
  const BackupDone();
}

final class BackupCancelled extends BackupResult {
  const BackupCancelled();
}

final class BackupFailed extends BackupResult {
  const BackupFailed(this.reason, this.detail);

  final BackupFailure reason;

  /// For logs and crash breadcrumbs, never shown to the user.
  final String detail;

  @override
  String toString() => 'BackupFailed(${reason.name}): $detail';
}

/// Exports every data document of the app as one backup file, and restores
/// one (ADR 0001, section 9). After a [BackupDone] restore, the app opens its
/// stores again.
class BackupService {
  BackupService({
    required this.appId,
    required this.stores,
    this.files = const SystemBackupFiles(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final String appId;
  final List<DataStore> stores;
  final BackupFiles files;
  final DateTime Function() _now;

  Future<BackupResult> export() => _guard(() async {
    final now = _now().toUtc();
    final backup = {
      'format': DataStore.format,
      'kind': 'backup',
      'app_id': appId,
      'written_at': now.toIso8601String(),
      'documents': {
        for (final store in stores) store.name: {'schema': store.schema, 'data': await store.read()},
      },
    };
    final name = '$appId-backup-${now.toIso8601String().substring(0, 10)}.json';
    final saved = await files.save(name, utf8.encode(jsonEncode(backup)));
    return saved ? const BackupDone() : const BackupCancelled();
  });

  /// Reads, checks and upgrades the whole file before touching anything; then
  /// keeps a copy of each document as `<name>.json.before-restore` and
  /// replaces it. If a write fails, every document is put back as it was.
  Future<BackupResult> restore() => _guard(() async {
    final bytes = await files.pick();
    if (bytes == null) return const BackupCancelled();
    final restored = _decode(bytes);

    final current = <DataStore, List<int>?>{};
    for (final store in restored.keys) {
      await store.flush(); // keep a save still being written
      current[store] = store.file.existsSync() ? await store.file.readAsBytes() : null;
    }
    try {
      for (final MapEntry(key: store, value: data) in restored.entries) {
        if (current[store] case final bytes?) {
          await File('${store.file.path}.before-restore').writeAsBytes(bytes, flush: true);
        }
        await store.replace(data);
      }
    } catch (_) {
      for (final MapEntry(key: store, value: bytes) in current.entries) {
        if (bytes != null) {
          final temp = await File('${store.file.path}.tmp').writeAsBytes(bytes, flush: true);
          await temp.rename(store.file.path);
        } else if (store.file.existsSync()) {
          await store.file.delete();
        }
        // The app's data matches the file again: let it save, as before the restore.
        await store.open().then((_) {}, onError: (Object _) {});
      }
      rethrow;
    }
    return const BackupDone();
  });

  Map<DataStore, Map<String, Object?>> _decode(Uint8List bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException catch (e) {
      throw _Refused(BackupFailure.unreadable, 'not JSON: ${e.message}');
    }
    if (json case {
      'format': DataStore.format,
      'kind': 'backup',
      'app_id': final String id,
      'documents': final Map<String, Object?> documents,
    }) {
      if (id != appId) throw _Refused(BackupFailure.otherApp, 'a backup of $id');
      final restored = <DataStore, Map<String, Object?>>{};
      for (final store in stores) {
        switch (documents[store.name]) {
          case null:
            continue; // not in this backup: left as it is
          case {'schema': final int schema, 'data': final Map<String, Object?> data} when schema >= 1:
            restored[store] = upgrade(data, from: schema, migrations: store.migrations);
          default:
            throw _Refused(BackupFailure.unreadable, '${store.name} is not a document');
        }
      }
      if (restored.isNotEmpty) return restored;
    }
    throw const _Refused(BackupFailure.unreadable, 'not a backup of this app');
  }
}

Future<BackupResult> _guard(Future<BackupResult> Function() run) async {
  try {
    return await run();
  } on _Refused catch (e) {
    return BackupFailed(e.reason, e.detail);
  } on DataException catch (e) {
    return BackupFailed(switch (e.problem) {
      DataProblem.unreadable => BackupFailure.unreadable,
      DataProblem.newerSchema => BackupFailure.newerSchema,
      DataProblem.migrationFailed => BackupFailure.migrationFailed,
    }, e.message);
  } on Exception catch (e) {
    return BackupFailed(BackupFailure.fileError, '$e');
  }
}

class _Refused implements Exception {
  const _Refused(this.reason, this.detail);

  final BackupFailure reason;
  final String detail;
}
