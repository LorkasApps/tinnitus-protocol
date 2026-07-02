import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';

class ExportService {
  ExportService(this._db);
  final AppDatabase _db;

  Future<void> exportCsv({required String subject, DateTimeRange? range}) async {
    final entries = _filterEntries(await _db.getAllEntries(), range);
    final sleep = _filterSleep(await _db.getAllSleepLogs(), range);

    final entryRows = <List<dynamic>>[
      ['id', 'timestamp', 'loudness', 'distress', 'notes'],
      for (final e in entries)
        [
          e.id,
          e.timestamp.toIso8601String(),
          e.loudness,
          e.distress,
          e.notes ?? '',
        ],
    ];
    final sleepRows = <List<dynamic>>[
      ['id', 'date', 'quality', 'notes'],
      for (final s in sleep)
        [
          s.id,
          s.date.toIso8601String().split('T').first,
          s.quality,
          s.notes ?? '',
        ],
    ];

    final entryCsv = const ListToCsvConverter().convert(entryRows);
    final sleepCsv = const ListToCsvConverter().convert(sleepRows);
    final suffix = _filenameSuffix(range);
    final entriesName = 'tinnitus_entries_$suffix.csv';
    final sleepName = 'tinnitus_sleep_$suffix.csv';
    final entriesFile = await _writeTemp(entriesName, entryCsv);
    final sleepFile = await _writeTemp(sleepName, sleepCsv);

    await Share.shareXFiles(
      [
        XFile(entriesFile.path, mimeType: 'text/csv', name: entriesName),
        XFile(sleepFile.path, mimeType: 'text/csv', name: sleepName),
      ],
      subject: subject,
    );
  }

  Future<void> exportJson({required String subject, DateTimeRange? range}) async {
    final entries = _filterEntries(await _db.getAllEntries(), range);
    final sleep = _filterSleep(await _db.getAllSleepLogs(), range);

    final triggersByEntry = <int, List<String>>{};
    for (final e in entries) {
      final tags = await _db.getTriggersForEntry(e.id);
      if (tags.isEmpty) continue;
      triggersByEntry[e.id] = [for (final t in tags) t.key];
    }

    final payload = {
      'entries': [
        for (final e in entries)
          {
            'id': e.id,
            'timestamp': e.timestamp.toIso8601String(),
            'loudness': e.loudness,
            'distress': e.distress,
            'notes': e.notes,
            'triggerKeys': triggersByEntry[e.id] ?? const <String>[],
          }
      ],
      'sleep': [
        for (final s in sleep)
          {
            'id': s.id,
            'date': s.date.toIso8601String().split('T').first,
            'quality': s.quality,
            'notes': s.notes,
          }
      ],
    };

    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final filename = 'tinnitus_export_${_filenameSuffix(range)}.json';
    final file = await _writeTemp(filename, json);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json', name: filename)],
      subject: subject,
    );
  }

  List<Entry> _filterEntries(List<Entry> all, DateTimeRange? range) {
    if (range == null) return all;
    final start = _startOfDay(range.start);
    final end = _endOfDay(range.end);
    return all
        .where((e) => !e.timestamp.isBefore(start) && !e.timestamp.isAfter(end))
        .toList();
  }

  List<SleepLog> _filterSleep(List<SleepLog> all, DateTimeRange? range) {
    if (range == null) return all;
    final start = _startOfDay(range.start);
    final end = _endOfDay(range.end);
    return all
        .where((s) => !s.date.isBefore(start) && !s.date.isAfter(end))
        .toList();
  }

  String _filenameSuffix(DateTimeRange? range) {
    if (range == null) return '${_stamp(DateTime.now())}_complete';
    return '${_stamp(range.start)}_${_stamp(range.end)}';
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  String _stamp(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<File> _writeTemp(String name, String contents) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    return file.writeAsString(contents);
  }
}
