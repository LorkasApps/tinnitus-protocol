import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../data/trigger_labels.dart';
import '../l10n/app_localizations.dart';
import '../providers/entries_filter.dart';
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

  bool _passesFilter(
    Entry entry,
    EntriesFilter filter,
    Map<int, Set<int>> triggerIdsByEntry,
  ) {
    final range = filter.range;
    if (range != null) {
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(
          range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);
      if (entry.timestamp.isBefore(start) || entry.timestamp.isAfter(end)) {
        return false;
      }
    }
    if (filter.triggerIds.isNotEmpty) {
      final ids = triggerIdsByEntry[entry.id] ?? const <int>{};
      if (!ids.any(filter.triggerIds.contains)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final entriesAsync = ref.watch(entriesStreamProvider);
    final triggers = ref.watch(triggersStreamProvider).value ?? const [];
    final entryTriggers =
        ref.watch(entryTriggersStreamProvider).value ?? const [];
    final filter = ref.watch(entriesFilterProvider);

    ref.listen<EntriesFilter>(entriesFilterProvider, (prev, next) {
      setState(() => _visibleCount = _entriesPageSize);
    });

    final triggersById = {for (final tr in triggers) tr.id: tr};
    final triggersByEntry = <int, List<Trigger>>{};
    final triggerIdsByEntry = <int, Set<int>>{};
    for (final link in entryTriggers) {
      final tr = triggersById[link.triggerId];
      if (tr == null) continue;
      (triggersByEntry[link.entryId] ??= []).add(tr);
      (triggerIdsByEntry[link.entryId] ??= <int>{}).add(link.triggerId);
    }

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(t.errorPrefix(e.toString()))),
      data: (allEntries) {
        if (allEntries.isEmpty) {
          return Column(
            children: [
              _FilterBar(triggersById: triggersById),
              Expanded(child: _EmptyState()),
            ],
          );
        }

        final entries = allEntries
            .where((e) => _passesFilter(e, filter, triggerIdsByEntry))
            .toList();

        final visible = _visibleCount.clamp(0, entries.length);
        final hasMore = visible < entries.length;
        final remaining = entries.length - visible;
        final nextBatch =
            remaining < _entriesPageSize ? remaining : _entriesPageSize;

        return Column(
          children: [
            _FilterBar(triggersById: triggersById),
            Expanded(
              child: entries.isEmpty
                  ? _FilteredEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 96),
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
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
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
            Text(t.noEntries, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(t.noEntriesHint, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _FilteredEmptyState extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_off,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(t.filteredEmptyTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(t.filteredEmptyHint, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => ref
                  .read(entriesFilterProvider.notifier)
                  .state = const EntriesFilter(),
              child: Text(t.filteredEmptyReset),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.triggersById});
  final Map<int, Trigger> triggersById;

  String _rangeLabel(DateTimeRange r, String locale) {
    final fmt = DateFormat.Md(locale);
    return '${fmt.format(r.start)} – ${fmt.format(r.end)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final loc = Localizations.localeOf(context).languageCode;
    final filter = ref.watch(entriesFilterProvider);

    final chips = <Widget>[
      ActionChip(
        avatar: const Icon(Icons.tune, size: 18),
        label: Text(t.addFilter),
        onPressed: () => _showFilterSheet(context, ref, triggersById),
      ),
    ];

    if (filter.range != null) {
      chips.add(
        InputChip(
          avatar: const Icon(Icons.date_range, size: 18),
          label: Text(_rangeLabel(filter.range!, loc)),
          onDeleted: () => ref.read(entriesFilterProvider.notifier).state =
              filter.copyWith(clearRange: true),
        ),
      );
    }

    for (final id in filter.triggerIds) {
      final tr = triggersById[id];
      if (tr == null) continue;
      chips.add(
        InputChip(
          label: Text(triggerLabel(t, tr)),
          onDeleted: () {
            final next = {...filter.triggerIds}..remove(id);
            ref.read(entriesFilterProvider.notifier).state =
                filter.copyWith(triggerIds: next);
          },
        ),
      );
    }

    if (filter.isActive) {
      chips.add(
        TextButton.icon(
          onPressed: () => ref.read(entriesFilterProvider.notifier).state =
              const EntriesFilter(),
          icon: const Icon(Icons.close, size: 16),
          label: Text(t.filterResetAll),
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final c in chips) ...[
            c,
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

Future<void> _showFilterSheet(
  BuildContext context,
  WidgetRef ref,
  Map<int, Trigger> triggersById,
) {
  final t = AppLocalizations.of(context)!;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Consumer(
            builder: (ctx, cRef, _) {
              final filter = cRef.watch(entriesFilterProvider);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.filterSheetTitle,
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Text(t.filterByDateRange,
                      style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            filter.range == null
                                ? t.filterPickDate
                                : _formatRange(
                                    filter.range!,
                                    Localizations.localeOf(ctx).languageCode),
                          ),
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: ctx,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              initialDateRange: filter.range,
                            );
                            if (picked != null) {
                              cRef.read(entriesFilterProvider.notifier).state =
                                  filter.copyWith(range: picked);
                            }
                          },
                        ),
                      ),
                      if (filter.range != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => cRef
                              .read(entriesFilterProvider.notifier)
                              .state = filter.copyWith(clearRange: true),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(t.filterByTags,
                      style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tr in triggersById.values)
                        FilterChip(
                          label: Text(triggerLabel(t, tr)),
                          selected: filter.triggerIds.contains(tr.id),
                          onSelected: (on) {
                            final next = {...filter.triggerIds};
                            if (on) {
                              next.add(tr.id);
                            } else {
                              next.remove(tr.id);
                            }
                            cRef.read(entriesFilterProvider.notifier).state =
                                filter.copyWith(triggerIds: next);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: filter.isActive
                            ? () => cRef
                                .read(entriesFilterProvider.notifier)
                                .state = const EntriesFilter()
                            : null,
                        child: Text(t.filterResetAll),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(t.filterSheetDone),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

String _formatRange(DateTimeRange r, String locale) {
  final fmt = DateFormat.yMd(locale);
  return '${fmt.format(r.start)} – ${fmt.format(r.end)}';
}
