import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../data/trigger_labels.dart';
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
  final Set<int> _selectedTriggerIds = {};

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _timestamp = e?.timestamp ?? DateTime.now();
    _loudness = e?.loudness ?? 5;
    _distress = e?.distress ?? 5;
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    if (e != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadTriggers(e.id));
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTriggers(int entryId) async {
    final db = ref.read(dbProvider);
    final list = await db.getTriggersForEntry(entryId);
    if (!mounted) return;
    setState(() {
      _selectedTriggerIds
        ..clear()
        ..addAll(list.map((t) => t.id));
    });
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

  Future<void> _addCustomTrigger() async {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.addCustomTriggerTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: t.customTriggerHint),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(t.save),
          ),
        ],
      ),
    );
    if (input == null || input.trim().isEmpty) return;
    final db = ref.read(dbProvider);
    final id = await db.insertCustomTrigger(input.trim());
    if (!mounted) return;
    setState(() => _selectedTriggerIds.add(id));
  }

  Future<void> _confirmDeleteCustomTrigger(Trigger trigger) async {
    final t = AppLocalizations.of(context)!;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteCustomTriggerTitle),
        content: Text(t.deleteCustomTriggerConfirm),
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
    if (yes != true) return;
    final db = ref.read(dbProvider);
    await db.deleteCustomTrigger(trigger.id);
    if (!mounted) return;
    setState(() => _selectedTriggerIds.remove(trigger.id));
  }

  Future<void> _save() async {
    final db = ref.read(dbProvider);
    final t = AppLocalizations.of(context)!;
    final notes = _notesCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    try {
      int entryId;
      if (widget.existing == null) {
        entryId = await db.insertEntry(
          EntriesCompanion(
            timestamp: Value(_timestamp),
            loudness: Value(_loudness),
            distress: Value(_distress),
            notes: Value(notes.isEmpty ? null : notes),
          ),
        );
      } else {
        entryId = widget.existing!.id;
        await db.updateEntry(
          widget.existing!.copyWith(
            timestamp: _timestamp,
            loudness: _loudness,
            distress: _distress,
            notes: Value(notes.isEmpty ? null : notes),
          ),
        );
      }
      await db.setTriggersForEntry(entryId, _selectedTriggerIds);
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
    final triggersAsync = ref.watch(triggersStreamProvider);

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
          Text(t.triggers, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          triggersAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(t.errorPrefix(e.toString())),
            data: (triggers) => _TriggerChips(
              triggers: triggers,
              selected: _selectedTriggerIds,
              onToggle: (id, selected) => setState(() {
                if (selected) {
                  _selectedTriggerIds.add(id);
                } else {
                  _selectedTriggerIds.remove(id);
                }
              }),
              onAddCustom: _addCustomTrigger,
              onDeleteCustom: _confirmDeleteCustomTrigger,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: t.notesOptional,
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

class _TriggerChips extends StatelessWidget {
  const _TriggerChips({
    required this.triggers,
    required this.selected,
    required this.onToggle,
    required this.onAddCustom,
    required this.onDeleteCustom,
  });

  final List<Trigger> triggers;
  final Set<int> selected;
  final void Function(int id, bool selected) onToggle;
  final VoidCallback onAddCustom;
  final void Function(Trigger trigger) onDeleteCustom;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final trig in triggers)
          GestureDetector(
            onLongPress:
                trig.customLabel != null ? () => onDeleteCustom(trig) : null,
            child: FilterChip(
              label: Text(triggerLabel(t, trig)),
              selected: selected.contains(trig.id),
              onSelected: (sel) => onToggle(trig.id, sel),
            ),
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: Text(t.addCustomTrigger),
          onPressed: onAddCustom,
        ),
      ],
    );
  }
}
