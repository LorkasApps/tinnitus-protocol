import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/export_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref, bool asCsv) async {
    final db = ref.read(dbProvider);
    final svc = ExportService(db);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (asCsv) {
        await svc.exportCsv();
      } else {
        await svc.exportJson();
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export fehlgeschlagen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        const ListTile(
          title: Text('Daten exportieren'),
          dense: true,
        ),
        ListTile(
          leading: const Icon(Icons.table_chart),
          title: const Text('Als CSV exportieren'),
          subtitle: const Text('Tabelle für Excel / Numbers'),
          onTap: () => _export(context, ref, true),
        ),
        ListTile(
          leading: const Icon(Icons.data_object),
          title: const Text('Als JSON exportieren'),
          subtitle: const Text('Maschinenlesbar'),
          onTap: () => _export(context, ref, false),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Tinnitus-Protokoll'),
          subtitle: Text(
            'Version 0.1.0 — Daten werden ausschließlich lokal gespeichert.',
          ),
        ),
      ],
    );
  }
}
