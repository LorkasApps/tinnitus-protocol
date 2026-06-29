import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../widgets/scale_slider.dart';

class EntryFormScreen extends ConsumerStatefulWidget {
  const EntryFormScreen({super.key, this.existing});

  final Entry? existing;

  @override
  ConsumerState<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends ConsumerState<EntryFormScreen> {
  late DateTime _timestamp;
  late int _loudness;
  late int _distress;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _timestamp = e?.timestamp ?? DateTime.now();
    _loudness = e?.loudness ?? 5;
    _distress = e?.distress ?? 5;
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _timestamp,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timestamp),
    );
    if (time == null) return;
    setState(() {
      _timestamp = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final db = ref.read(dbProvider);
    final t = AppLocalizations.of(context)!;
    final notes = _notesCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (widget.existing == null) {
        await db.insertEntry(
          EntriesCompanion(
            timestamp: Value(_timestamp),
            loudness: Value(_loudness),
            distress: Value(_distress),
            notes: Value(notes.isEmpty ? null : notes),
          ),
        );
      } else {
        await db.updateEntry(
          widget.existing!.copyWith(
            timestamp: _timestamp,
            loudness: _loudness,
            distress: _distress,
            notes: Value(notes.isEmpty ? null : notes),
          ),
        );
      }
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
    final dateFmt = DateFormat.yMMMMEEEEd(loc).add_Hm();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? t.editEntry : t.newEntry),
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
              leading: const Icon(Icons.access_time),
              title: Text(t.timestamp),
              subtitle: Text(dateFmt.format(_timestamp)),
              onTap: _pickDateTime,
            ),
          ),
          const SizedBox(height: 16),
          ScaleSlider(
            label: t.loudness,
            value: _loudness,
            onChanged: (v) => setState(() => _loudness = v),
            minLabel: t.loudnessMin,
            maxLabel: t.loudnessMax,
          ),
          const SizedBox(height: 8),
          ScaleSlider(
            label: t.distress,
            value: _distress,
            onChanged: (v) => setState(() => _distress = v),
            minLabel: t.distressMin,
            maxLabel: t.distressMax,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: t.notesTrigger,
              hintText: t.notesTriggerHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(isEdit ? t.update : t.save),
          ),
        ],
      ),
    );
  }
}
