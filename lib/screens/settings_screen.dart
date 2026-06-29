import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../services/export_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref, bool asCsv) async {
    final t = AppLocalizations.of(context)!;
    final db = ref.read(dbProvider);
    final svc = ExportService(db);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (asCsv) {
        await svc.exportCsv(subject: t.exportSubjectCsv);
      } else {
        await svc.exportJson(subject: t.exportSubjectJson);
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(t.exportFailed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    return ListView(
      children: [
        ListTile(
          title: Text(t.exportData),
          dense: true,
        ),
        ListTile(
          leading: const Icon(Icons.table_chart),
          title: Text(t.exportCsv),
          subtitle: Text(t.exportCsvSub),
          onTap: () => _export(context, ref, true),
        ),
        ListTile(
          leading: const Icon(Icons.data_object),
          title: Text(t.exportJson),
          subtitle: Text(t.exportJsonSub),
          onTap: () => _export(context, ref, false),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(t.appTitle),
          subtitle: Text(t.aboutSubtitle),
        ),
      ],
    );
  }
}
