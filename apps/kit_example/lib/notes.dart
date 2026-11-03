/// The worked example of versioned data (ADR 0001, section 8): a notes
/// document, made-up content only, never shipped.
library;

import 'package:app_kit/app_kit.dart';
import 'package:flutter/foundation.dart';

const notesAppId = 'kit-example';
const notesDocument = 'notes';

/// Schema 1 → 2: a note's `text` becomes `body`, and notes gain `pinned`.
/// Written so that running it again on upgraded data changes nothing.
Map<String, Object?> notesSchema2(Map<String, Object?> data) => {
  ...data,
  'notes': [
    for (final note in (data['notes']! as List).cast<Map<String, Object?>>())
      {
        'id': note['id'],
        'body': note['body'] ?? note['text'],
        'created': note['created'],
        'pinned': note['pinned'] ?? false,
      },
  ],
};

/// The notes document is at schema `notesMigrations.length + 1` = 2.
const List<Migration> notesMigrations = [notesSchema2];

@immutable
class Note {
  const Note({required this.id, required this.body, required this.created, this.pinned = false});

  final String id;
  final String body;
  final DateTime created;
  final bool pinned;

  factory Note.fromJson(Map<String, Object?> json) => Note(
    id: json['id']! as String,
    body: json['body']! as String,
    created: DateTime.parse(json['created']! as String),
    pinned: json['pinned']! as bool,
  );

  /// Decodes the `data` of a schema 2 document.
  static List<Note> decodeAll(Map<String, Object?> data) => [
    for (final note in (data['notes']! as List).cast<Map<String, Object?>>()) Note.fromJson(note),
  ];

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.id == id &&
      other.body == body &&
      other.created == created &&
      other.pinned == pinned;

  @override
  int get hashCode => Object.hash(id, body, created, pinned);

  @override
  String toString() => 'Note($id, "$body", $created, pinned: $pinned)';
}
