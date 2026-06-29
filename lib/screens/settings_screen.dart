import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../providers/providers.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';

const _supportUrl = 'https://lorkasapps.github.io';

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

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context)!;
    final db = ref.read(dbProvider);
    final svc = ImportService(db);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await svc.pickAndImport();
      if (result == null) return; // user cancelled
      messenger.showSnackBar(
        SnackBar(
          content: Text(t.importSuccess(result.entryCount, result.sleepCount)),
        ),
      );
    } on ImportFormatException {
      messenger.showSnackBar(
        SnackBar(content: Text(t.importUnsupported)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(t.errorPrefix(e.toString()))),
      );
    }
  }

  String _localeLabel(AppLocalizations t, Locale? locale) {
    if (locale == null) return t.languageSystem;
    return switch (locale.languageCode) {
      'en' => t.languageEnglish,
      'de' => t.languageGerman,
      _ => locale.languageCode,
    };
  }

  Future<void> _confirmWipe(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.wipeConfirmTitle),
        content: Text(t.wipeConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.wipeConfirmCta),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await ref.read(dbProvider).wipeAllUserData();
    messenger.showSnackBar(SnackBar(content: Text(t.wipeSuccess)));
  }

  Future<void> _openSupport(BuildContext context) async {
    final t = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(
      Uri.parse(_supportUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(t.linkOpenFailed)));
    }
  }

  Future<void> _selectLanguage(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context)!;
    final current = ref.read(localeProvider);
    final options = <Locale?, String>{
      null: t.languageSystem,
      const Locale('en'): t.languageEnglish,
      const Locale('de'): t.languageGerman,
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t.language),
        children: [
          RadioGroup<Locale?>(
            groupValue: current,
            onChanged: (v) {
              Navigator.pop(ctx);
              ref.read(localeProvider.notifier).state = v;
              persistLocale(v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in options.entries)
                  RadioListTile<Locale?>(
                    title: Text(entry.value),
                    value: entry.key,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);

    return ListView(
      children: [
        ListTile(
          title: Text(t.appearance),
          dense: true,
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(t.language),
          subtitle: Text(_localeLabel(t, locale)),
          onTap: () => _selectLanguage(context, ref),
        ),
        const Divider(),
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
          title: Text(t.importData),
          dense: true,
        ),
        ListTile(
          leading: const Icon(Icons.file_upload),
          title: Text(t.importJson),
          subtitle: Text(t.importJsonSub),
          onTap: () => _import(context, ref),
        ),
        const Divider(),
        ListTile(
          title: Text(t.dangerZone),
          dense: true,
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            t.wipeAllData,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          subtitle: Text(t.wipeAllDataSub),
          onTap: () => _confirmWipe(context, ref),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.favorite_outline),
          title: Text(t.supportAndMoreApps),
          subtitle: Text(t.supportAndMoreAppsSub),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _openSupport(context),
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
