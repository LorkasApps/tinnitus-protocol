import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../widgets/entry_tile.dart';
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
    final titles = ['Einträge', 'Schlaf', 'Statistik', 'Einstellungen'];
    final bodies = <Widget>[
      const _EntriesTab(),
      const SleepScreen(),
      const StatsScreen(),
      const SettingsScreen(),
    ];

    Widget? fab;
    if (_tab == 0) {
      fab = FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const EntryFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Neuer Eintrag'),
      );
    } else if (_tab == 1) {
      fab = FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SleepFormScreen()),
        ),
        icon: const Icon(Icons.bedtime),
        label: const Text('Schlaf eintragen'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      body: bodies[_tab],
      floatingActionButton: fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: 'Einträge',
          ),
          NavigationDestination(
            icon: Icon(Icons.bedtime),
            label: 'Schlaf',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: 'Statistik',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Einstellungen',
          ),
        ],
      ),
    );
  }
}

class _EntriesTab extends ConsumerWidget {
  const _EntriesTab();

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Entry entry,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen?'),
        content: const Text('Dieser Vorgang lässt sich nicht rückgängig machen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await ref.read(dbProvider).deleteEntry(entry.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(entriesStreamProvider);

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
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
                    'Noch keine Einträge.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tippe auf "Neuer Eintrag", um zu starten.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final entry = entries[i];
            return EntryTile(
              entry: entry,
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
