import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';

import '../data/database.dart';

/// Thrown when the JSON does not match the export format.
class ImportFormatException implements Exception {
  const ImportFormatException();
}

class ImportResult {
  ImportResult({required this.entryCount, required this.sleepCount});
  final int entryCount;
  final int sleepCount;
}

class ImportService {
  ImportService(this._db);
  final AppDatabase _db;

  /// Picks a JSON file, validates it strictly against the export format,
  /// and imports its contents. Returns null if the user cancelled the picker.
  ///
  /// Throws [ImportFormatException] when the file is not a JSON object with
  /// the exact shape produced by [ExportService.exportJson].
  Future<ImportResult?> pickAndImport() async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (pick == null || pick.files.isEmpty) return null;
    final file = pick.files.single;
    final String content;
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    } else {
      throw const ImportFormatException();
    }
    return _import(content);
  }

  Future<ImportResult> _import(String jsonString) async {
    final root = _decodeRoot(jsonString);
    final entries = _parseEntries(root['entries']);
    final sleep = _parseSleep(root['sleep']);

    await _db.transaction(() async {
      for (final c in entries) {
        await _db.insertEntry(c);
      }
      for (final s in sleep) {
        await _db.upsertSleepLog(
          date: s.date,
          quality: s.quality,
          notes: s.notes ?? '',
        );
      }
    });

    return ImportResult(entryCount: entries.length, sleepCount: sleep.length);
  }

  Map<String, dynamic> _decodeRoot(String s) {
    final dynamic raw;
    try {
      raw = jsonDecode(s);
    } catch (_) {
      throw const ImportFormatException();
    }
    if (raw is! Map) throw const ImportFormatException();
    if (raw['entries'] is! List) throw const ImportFormatException();
    if (raw['sleep'] is! List) throw const ImportFormatException();
    return raw.cast<String, dynamic>();
  }

  List<EntriesCompanion> _parseEntries(List raw) {
    final result = <EntriesCompanion>[];
    for (final e in raw) {
      if (e is! Map) throw const ImportFormatException();
      final ts = e['timestamp'];
      final loudness = e['loudness'];
      final distress = e['distress'];
      final notes = e['notes'];
      if (ts is! String) throw const ImportFormatException();
      if (loudness is! int) throw const ImportFormatException();
      if (distress is! int) throw const ImportFormatException();
      if (notes != null && notes is! String) throw const ImportFormatException();
      final dt = DateTime.tryParse(ts);
      if (dt == null) throw const ImportFormatException();
      result.add(EntriesCompanion(
        timestamp: Value(dt),
        loudness: Value(loudness),
        distress: Value(distress),
        notes: Value(notes as String?),
      ));
    }
    return result;
  }

  List<_ParsedSleep> _parseSleep(List raw) {
    final result = <_ParsedSleep>[];
    for (final s in raw) {
      if (s is! Map) throw const ImportFormatException();
      final date = s['date'];
      final quality = s['quality'];
      final notes = s['notes'];
      if (date is! String) throw const ImportFormatException();
      if (quality is! int) throw const ImportFormatException();
      if (notes != null && notes is! String) throw const ImportFormatException();
      final d = DateTime.tryParse(date);
      if (d == null) throw const ImportFormatException();
      result.add(_ParsedSleep(
        date: d,
        quality: quality,
        notes: notes as String?,
      ));
    }
    return result;
  }
}

class _ParsedSleep {
  _ParsedSleep({required this.date, required this.quality, this.notes});
  final DateTime date;
  final int quality;
  final String? notes;
}
