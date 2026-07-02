import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../widgets/entry_tile.dart';
import 'analyze_screen.dart';
import 'entry_form_screen.dart';
import 'settings_screen.dart';
import 'sleep_form_screen.dart';
import 'sleep_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final titles = [
      t.tabEntries,
      t.tabSleep,
      t.tabStats,
      t.tabAnalyze,
      t.tabSettings,
    ];
    final bodies = <Widget>[
      const _EntriesTab(),
      const SleepScreen(),
      const StatsScreen(),
      const AnalyzeScreen(),
      const SettingsScreen(),
    ];

    Widget? fab;
    if (_tab == 0) {
      fab = FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const EntryFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text(t.newEntry),
      );
    } else if (_tab == 1) {
      fab = FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SleepFormScreen()),
        ),
        icon: const Icon(Icons.bedtime),
        label: Text(t.logSleep),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      body: bodies[_tab],
      floatingActionButton: fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.list_alt),
            label: t.tabEntries,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bedtime),
            label: t.tabSleep,
          ),
          NavigationDestination(
            icon: const Icon(Icons.show_chart),
            label: t.tabStats,
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights),
            label: t.tabAnalyze,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings),
            label: t.tabSettings,
          ),
        ],
      ),
    );
  }
}

const _entriesPageSize = 20;

class _EntriesTab extends ConsumerStatefulWidget {
  const _EntriesTab();

  @override
  ConsumerState<_EntriesTab> createState() => _EntriesTabState();
}

class _EntriesTabState extends ConsumerState<_EntriesTab> {
  int _visibleCount = _entriesPageSize;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Entry entry,
  ) async {
    final t = AppLocalizations.of(context)!;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteEntryTitle),
        content: Text(t.deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (yes == true) {
      await ref.read(dbProvider).deleteEntry(entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final entriesAsync = ref.watch(entriesStreamProvider);
    final triggers = ref.watch(triggersStreamProvider).value ?? const [];
    final entryTriggers =
        ref.watch(entryTriggersStreamProvider).value ?? const [];
    final triggersById = {for (final tr in triggers) tr.id: tr};
    final triggersByEntry = <int, List<Trigger>>{};
    for (final link in entryTriggers) {
      final tr = triggersById[link.triggerId];
      if (tr == null) continue;
      (triggersByEntry[link.entryId] ??= []).add(tr);
    }

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(t.errorPrefix(e.toString()))),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_note,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.noEntries,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(t.noEntriesHint, textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }
        final visible = _visibleCount.clamp(0, entries.length);
        final hasMore = visible < entries.length;
        final remaining = entries.length - visible;
        final nextBatch =
            remaining < _entriesPageSize ? remaining : _entriesPageSize;

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          itemCount: visible + (hasMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == visible) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _visibleCount = (_visibleCount + _entriesPageSize)
                        .clamp(0, entries.length);
                  }),
                  icon: const Icon(Icons.expand_more),
                  label: Text(t.loadNextEntries(nextBatch)),
                ),
              );
            }
            final entry = entries[i];
            return EntryTile(
              entry: entry,
              triggers: triggersByEntry[entry.id] ?? const [],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EntryFormScreen(existing: entry),
                ),
              ),
              onLongPress: () => _confirmDelete(context, ref, entry),
            );
          },
        );
      },
    );
  }
}
