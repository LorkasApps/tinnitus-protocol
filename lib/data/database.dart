import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get loudness => integer()();
  IntColumn get distress => integer()();
  TextColumn get notes => text().nullable()();
}

class SleepLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime().unique()();
  IntColumn get quality => integer()();
  TextColumn get notes => text().nullable()();
}

@DriftDatabase(tables: [Entries, SleepLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(sleepLogs);
          }
          if (from < 3) {
            // Drop legacy NOT NULL column from v1 if still present.
            // Requires SQLite >= 3.35 (supports ALTER TABLE ... DROP COLUMN).
            try {
              await customStatement(
                'ALTER TABLE entries DROP COLUMN sleep_quality',
              );
            } catch (_) {
              // Column didn't exist (fresh install) — ignore.
            }
          }
        },
      );

  // --- Entries ---

  Stream<List<Entry>> watchAllEntries() {
    return (select(entries)..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .watch();
  }

  Future<List<Entry>> getAllEntries() {
    return (select(entries)..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
  }

  Future<int> insertEntry(EntriesCompanion entry) {
    return into(entries).insert(entry);
  }

  Future<bool> updateEntry(Entry entry) {
    return update(entries).replace(entry);
  }

  Future<int> deleteEntry(int id) {
    return (delete(entries)..where((t) => t.id.equals(id))).go();
  }

  // --- SleepLogs ---

  Stream<List<SleepLog>> watchAllSleepLogs() {
    return (select(sleepLogs)..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Future<List<SleepLog>> getAllSleepLogs() {
    return (select(sleepLogs)..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  Future<SleepLog?> getSleepLogFor(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return (select(sleepLogs)..where((t) => t.date.equals(d)))
        .getSingleOrNull();
  }

  /// Insert or replace sleep log for the given day (date is normalized to midnight).
  ///
  /// Drift's [insertOnConflictUpdate] resolves conflicts on the primary key
  /// only, which never matches here because [id] is auto-incremented. We
  /// dispatch on the UNIQUE(date) constraint manually so that editing an
  /// existing day's log doesn't blow up with a UNIQUE-constraint violation.
  Future<int> upsertSleepLog({
    required DateTime date,
    required int quality,
    String? notes,
  }) async {
    final d = DateTime(date.year, date.month, date.day);
    final existing = await (select(sleepLogs)
          ..where((t) => t.date.equals(d)))
        .getSingleOrNull();
    if (existing == null) {
      return into(sleepLogs).insert(
        SleepLogsCompanion(
          date: Value(d),
          quality: Value(quality),
          notes: Value(notes),
        ),
      );
    }
    return (update(sleepLogs)..where((t) => t.id.equals(existing.id))).write(
      SleepLogsCompanion(
        date: Value(d),
        quality: Value(quality),
        notes: Value(notes),
      ),
    );
  }

  Future<int> deleteSleepLog(int id) {
    return (delete(sleepLogs)..where((t) => t.id.equals(id))).go();
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'tinnitus_protocol');
}
