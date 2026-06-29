import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final entriesStreamProvider = StreamProvider<List<Entry>>((ref) {
  return ref.watch(dbProvider).watchAllEntries();
});

final sleepLogsStreamProvider = StreamProvider<List<SleepLog>>((ref) {
  return ref.watch(dbProvider).watchAllSleepLogs();
});

final triggersStreamProvider = StreamProvider<List<Trigger>>((ref) {
  return ref.watch(dbProvider).watchAllTriggers();
});

final entryTriggersStreamProvider = StreamProvider<List<EntryTrigger>>((ref) {
  return ref.watch(dbProvider).watchAllEntryTriggers();
});
