import 'dart:convert';
import 'dart:io';

/// Takes a document's `data` from schema `n` to `n + 1`. Pure, and harmless
/// when run again on data it already upgraded (ADR 0001, section 8).
typedef Migration = Map<String, Object?> Function(Map<String, Object?> data);

/// Why a document could not be opened.
enum DataProblem {
  /// Not JSON, not our envelope, or another app's document.
  unreadable,

  /// Written by a newer version of the app: refused, never overwritten.
  newerSchema,

  /// A migration threw: the file is left as it was.
  migrationFailed,
}

class DataException implements Exception {
  const DataException(this.problem, this.message);

  final DataProblem problem;
  final String message;

  @override
  String toString() => 'DataException(${problem.name}): $message';
}

/// One versioned JSON document, `<name>.json` in [directory] (ADR 0001,
/// section 8). The schema is `migrations.length + 1`.
class DataStore {
  DataStore({
    required this.directory,
    required this.appId,
    required this.name,
    required this.initial,
    this.migrations = const [],
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const format = 'deroches.data';

  final Directory directory;
  final String appId;
  final String name;

  /// The app's empty state, when the document doesn't exist yet.
  final Map<String, Object?> Function() initial;

  /// `migrations[i]` takes schema `i + 1` to `i + 2`.
  final List<Migration> migrations;
  final DateTime Function() _now;
  bool _opened = false;
  Future<void> _saving = Future.value();

  int get schema => migrations.length + 1;
  File get file => File('${directory.path}/$name.json');

  /// Reads the document, upgrading and saving it first if it is older.
  /// Throws a [DataException]; never returns an empty state for a file that
  /// exists.
  /// Saving is allowed only once [open] has succeeded.
  Future<Map<String, Object?>> open() async {
    _opened = false;
    await _saving.catchError((Object _) {}); // read what earlier saves wrote
    if (!file.existsSync()) {
      _opened = true;
      return initial();
    }
    final (from, data) = _decode(await file.readAsBytes());
    final upgraded = upgrade(data, from: from, migrations: migrations);
    if (from < schema) await _enqueue(upgraded);
    _opened = true;
    return upgraded;
  }

  /// Writes [data] atomically: a temporary file, flushed, then renamed over
  /// the document; the previous document is kept as `.bak`. Saves run one
  /// after the other, in the order they were called.
  Future<void> save(Map<String, Object?> data) async {
    if (!_opened) throw StateError('open "$name" before saving it');
    return _enqueue(data);
  }

  Future<void> _enqueue(Map<String, Object?> data) =>
      _saving = _saving.catchError((Object _) {}).then((_) => _write(data));

  Future<void> _write(Map<String, Object?> data) async {
    final envelope = {
      'format': format,
      'schema': schema,
      'app_id': appId,
      'written_at': _now().toUtc().toIso8601String(),
      'data': data,
    };
    await directory.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(envelope), flush: true);
    if (file.existsSync()) await file.copy('${file.path}.bak');
    await temp.rename(file.path);
  }

  (int, Map<String, Object?>) _decode(List<int> bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json case {
        'format': format,
        'schema': final int version,
        'app_id': final String id,
        'data': final Map<String, Object?> data,
      } when id == appId && version >= 1) {
        return (version, data);
      }
    } on FormatException catch (e) {
      throw DataException(DataProblem.unreadable, '$name: ${e.message}');
    }
    throw DataException(DataProblem.unreadable, '$name is not a $format document of $appId');
  }
}

/// Runs [migrations] on [data], from schema [from] to the latest. Shared by
/// [DataStore.open], backup restore and the data-upgrade tests.
Map<String, Object?> upgrade(
  Map<String, Object?> data, {
  required int from,
  required List<Migration> migrations,
}) {
  final latest = migrations.length + 1;
  if (from > latest) {
    throw DataException(DataProblem.newerSchema, 'schema $from is newer than $latest');
  }
  var current = data;
  for (var n = from; n < latest; n++) {
    try {
      current = migrations[n - 1](current);
    } catch (e) {
      throw DataException(DataProblem.migrationFailed, 'schema $n to ${n + 1}: $e');
    }
  }
  return current;
}
