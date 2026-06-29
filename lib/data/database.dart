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

/// Predefined triggers seeded on first run share a stable [key] (e.g. 'stress').
/// User-created triggers get key `custom:<lowercased_label>` for uniqueness,
/// [customLabel] holds the user's original casing for display.
class Triggers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().unique()();
  TextColumn get customLabel => text().nullable()();
}

/// Many-to-many join between [Entries] and [Triggers].
///
/// FK uses customConstraint so drift_dev's same-file parser doesn't warn.
class EntryTriggers extends Table {
  IntColumn get entryId => integer().customConstraint(
      'NOT NULL REFERENCES entries(id) ON DELETE CASCADE')();
  IntColumn get triggerId => integer().customConstraint(
      'NOT NULL REFERENCES triggers(id) ON DELETE CASCADE')();

  @override
  Set<Column> get primaryKey => {entryId, triggerId};
}

const List<String> predefinedTriggerKeys = [
  'stress',
  'loudSound',
  'caffeine',
  'alcohol',
  'lackOfSleep',
  'weather',
  'screenTime',
  'exercise',
  'medication',
  'headache',
];

@DriftDatabase(tables: [Entries, SleepLogs, Triggers, EntryTriggers])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedPredefinedTriggers();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(sleepLogs);
          }
          if (from < 3) {
            try {
              await customStatement(
                'ALTER TABLE entries DROP COLUMN sleep_quality',
              );
            } catch (_) {
              // Column didn't exist (fresh install) — ignore.
            }
          }
          if (from < 4) {
            await m.createTable(triggers);
            await m.createTable(entryTriggers);
            await _seedPredefinedTriggers();
          }
        },
        beforeOpen: (details) async {
          // Required for ON DELETE CASCADE on entry_triggers to fire.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _seedPredefinedTriggers() async {
    for (final key in predefinedTriggerKeys) {
      final exists = await (select(triggers)..where((t) => t.key.equals(key)))
          .getSingleOrNull();
      if (exists == null) {
        await into(triggers).insert(TriggersCompanion.insert(key: key));
      }
    }
  }

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

  /// Insert or replace sleep log for the given day (date normalized to midnight).
  Future<int> upsertSleepLog({
    required DateTime date,
    required int quality,
    String? notes,
  }) async {
    final d = DateTime(date.year, date.month, date.day);
    final existing = await (select(sleepLogs)..where((t) => t.date.equals(d)))
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

  // --- Triggers ---

  Stream<List<Trigger>> watchAllTriggers() {
    return (select(triggers)..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();
  }

  Stream<List<EntryTrigger>> watchAllEntryTriggers() {
    return select(entryTriggers).watch();
  }

  Future<List<Trigger>> getAllTriggers() {
    return (select(triggers)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
  }

  Future<List<Trigger>> getTriggersForEntry(int entryId) async {
    final query = select(triggers).join([
      innerJoin(entryTriggers, entryTriggers.triggerId.equalsExp(triggers.id)),
    ])
      ..where(entryTriggers.entryId.equals(entryId));
    final rows = await query.get();
    return rows.map((row) => row.readTable(triggers)).toList();
  }

  Future<void> setTriggersForEntry(int entryId, Set<int> triggerIds) async {
    await transaction(() async {
      await (delete(entryTriggers)..where((t) => t.entryId.equals(entryId)))
          .go();
      for (final tid in triggerIds) {
        await into(entryTriggers).insert(
          EntryTriggersCompanion.insert(entryId: entryId, triggerId: tid),
        );
      }
    });
  }

  /// Adds a custom trigger or returns the id of an existing one with same key.
  Future<int> insertCustomTrigger(String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Custom trigger label must not be empty');
    }
    final key = 'custom:${trimmed.toLowerCase()}';
    final existing = await (select(triggers)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    return into(triggers).insert(
      TriggersCompanion.insert(key: key, customLabel: Value(trimmed)),
    );
  }

  /// Deletes a custom trigger. Predefined triggers (customLabel == null) protected.
  Future<int> deleteCustomTrigger(int id) {
    return (delete(triggers)
          ..where((t) => t.id.equals(id) & t.customLabel.isNotNull()))
        .go();
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'tinnitus_protocol');
}
