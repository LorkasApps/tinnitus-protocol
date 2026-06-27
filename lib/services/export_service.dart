import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';

class ExportService {
  ExportService(this._db);
  final AppDatabase _db;

  Future<void> exportCsv() async {
    final entries = await _db.getAllEntries();
    final sleep = await _db.getAllSleepLogs();

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
    final entriesFile = await _writeTemp('tinnitus_entries.csv', entryCsv);
    final sleepFile = await _writeTemp('tinnitus_sleep.csv', sleepCsv);

    await Share.shareXFiles(
      [
        XFile(entriesFile.path, mimeType: 'text/csv'),
        XFile(sleepFile.path, mimeType: 'text/csv'),
      ],
      subject: 'Tinnitus-Protokoll Export (CSV)',
    );
  }

  Future<void> exportJson() async {
    final entries = await _db.getAllEntries();
    final sleep = await _db.getAllSleepLogs();

    final payload = {
      'entries': [
        for (final e in entries)
          {
            'id': e.id,
            'timestamp': e.timestamp.toIso8601String(),
            'loudness': e.loudness,
            'distress': e.distress,
            'notes': e.notes,
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
    final file = await _writeTemp('tinnitus_export.json', json);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Tinnitus-Protokoll Export (JSON)',
    );
  }

  Future<File> _writeTemp(String name, String contents) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    return file.writeAsString(contents);
  }
}
