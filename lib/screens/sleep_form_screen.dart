import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../widgets/scale_slider.dart';

class SleepFormScreen extends ConsumerStatefulWidget {
  const SleepFormScreen({super.key, this.existing, this.initialDate});

  final SleepLog? existing;
  final DateTime? initialDate;

  @override
  ConsumerState<SleepFormScreen> createState() => _SleepFormScreenState();
}

class _SleepFormScreenState extends ConsumerState<SleepFormScreen> {
  late DateTime _date;
  late int _quality;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final raw = e?.date ?? widget.initialDate ?? DateTime.now();
    _date = DateTime(raw.year, raw.month, raw.day);
    _quality = e?.quality ?? 5;
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _save() async {
    final db = ref.read(dbProvider);
    final t = AppLocalizations.of(context)!;
    final notes = _notesCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await db.upsertSleepLog(
        date: _date,
        quality: _quality,
        notes: notes,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(t.saveFailed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isEdit = widget.existing != null;
    final loc = Localizations.localeOf(context).languageCode;
    final dateFmt = DateFormat.yMMMMEEEEd(loc);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? t.editSleep : t.logSleep),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: t.save,
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(t.dateNightBefore),
              subtitle: Text(dateFmt.format(_date)),
              onTap: isEdit ? null : _pickDate,
              enabled: !isEdit,
            ),
          ),
          const SizedBox(height: 16),
          ScaleSlider(
            label: t.sleepQuality,
            value: _quality,
            onChanged: (v) => setState(() => _quality = v),
            minLabel: t.sleepMin,
            maxLabel: t.sleepMax,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: t.notesOptional,
              hintText: t.notesSleepHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(isEdit ? t.update : t.save),
          ),
          if (!isEdit) ...[
            const SizedBox(height: 8),
            Text(
              t.sleepOverwriteHint,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
