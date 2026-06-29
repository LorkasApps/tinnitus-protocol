import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/time_period.dart';
import '../data/trigger_labels.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';

class AnalyzeScreen extends ConsumerStatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  ConsumerState<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends ConsumerState<AnalyzeScreen> {
  TimePeriod _period = TimePeriod.d30;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final entriesAsync = ref.watch(entriesStreamProvider);
    final sleepAsync = ref.watch(sleepLogsStreamProvider);
    final triggersAsync = ref.watch(triggersStreamProvider);
    final entryTriggersAsync = ref.watch(entryTriggersStreamProvider);

    if (entriesAsync.isLoading ||
        sleepAsync.isLoading ||
        triggersAsync.isLoading ||
        entryTriggersAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final firstError = [
      entriesAsync,
      sleepAsync,
      triggersAsync,
      entryTriggersAsync,
    ].firstWhere((a) => a.hasError, orElse: () => entriesAsync);
    if (firstError.hasError) {
      return Center(child: Text(t.errorPrefix(firstError.error.toString())));
    }

    final allEntries = entriesAsync.value ?? const <Entry>[];
    final allSleep = sleepAsync.value ?? const <SleepLog>[];
    final allTriggers = triggersAsync.value ?? const <Trigger>[];
    final allEntryTriggers = entryTriggersAsync.value ?? const <EntryTrigger>[];

    if (allEntries.isEmpty) return const _Empty();

    final entries = _filterEntries(allEntries, _period);
    final triggerById = {for (final tr in allTriggers) tr.id: tr};
    final entryToTriggerIds = <int, Set<int>>{};
    for (final et in allEntryTriggers) {
      entryToTriggerIds.putIfAbsent(et.entryId, () => {}).add(et.triggerId);
    }

    final triggerRows =
        _computeTriggerImpact(entries, entryToTriggerIds, allTriggers);
    final sleepRows = _computeSleepImpact(entries, allSleep);
    final correlations = _computeSleepCorrelation(entries, allSleep);
    final todRows = _computeTodTrigger(entries, entryToTriggerIds, allTriggers);
    final coRows = _computeCoOccurrence(entries, entryToTriggerIds);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PeriodSelector(
          period: _period,
          onChanged: (p) => setState(() => _period = p),
        ),
        const SizedBox(height: 16),
        _TriggerImpactCard(rows: triggerRows, triggerById: triggerById),
        const SizedBox(height: 16),
        _SleepImpactCard(rows: sleepRows),
        const SizedBox(height: 16),
        _SleepCorrelationCard(correlations: correlations),
        const SizedBox(height: 16),
        _TodTriggerCard(rows: todRows, triggerById: triggerById),
        const SizedBox(height: 16),
        _CoOccurrenceCard(rows: coRows, triggerById: triggerById),
      ],
    );
  }
}

// --- Stat helpers ---------------------------------------------------------

List<Entry> _filterEntries(List<Entry> all, TimePeriod period) {
  final dur = period.duration;
  if (dur == null) return all;
  final cutoff = DateTime.now().subtract(dur);
  return all.where((e) => e.timestamp.isAfter(cutoff)).toList();
}

double _avg(Iterable<num> values) {
  if (values.isEmpty) return 0;
  return values.fold<double>(0, (a, b) => a + b) / values.length;
}

/// Sample variance (n − 1 in the denominator). Returns 0 for n < 2.
double _variance(Iterable<num> values) {
  if (values.length < 2) return 0;
  final mean = _avg(values);
  final sq =
      values.fold<double>(0, (acc, v) => acc + math.pow(v - mean, 2).toDouble());
  return sq / (values.length - 1);
}

/// Cohen's d for two independent samples (pooled std).
/// Returns null when either group has < 2 observations or pooled std is 0.
double? _cohensD(List<num> a, List<num> b) {
  if (a.length < 2 || b.length < 2) return null;
  final va = _variance(a);
  final vb = _variance(b);
  final pooled =
      math.sqrt(((a.length - 1) * va + (b.length - 1) * vb) / (a.length + b.length - 2));
  if (pooled == 0) return null;
  return (_avg(a) - _avg(b)) / pooled;
}

/// Pearson correlation coefficient. Returns null when n < 3 or either
/// series has zero variance.
double? _pearson(List<num> xs, List<num> ys) {
  if (xs.length != ys.length || xs.length < 3) return null;
  final mx = _avg(xs);
  final my = _avg(ys);
  double num = 0, dx = 0, dy = 0;
  for (var i = 0; i < xs.length; i++) {
    final ex = xs[i] - mx;
    final ey = ys[i] - my;
    num += ex * ey;
    dx += ex * ex;
    dy += ey * ey;
  }
  if (dx == 0 || dy == 0) return null;
  return num / math.sqrt(dx * dy);
}

// --- Empty ----------------------------------------------------------------

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(t.noEntriesEmptyState, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              t.addEntryHint,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onChanged});

  final TimePeriod period;
  final ValueChanged<TimePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.period, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<TimePeriod>(
            segments: TimePeriod.values
                .map((p) => ButtonSegment(value: p, label: Text(p.labelFor(t))))
                .toList(),
            selected: {period},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ),
      ],
    );
  }
}

// --- Trigger impact (with Cohen's d) -------------------------------------

class _TriggerImpactRow {
  _TriggerImpactRow({
    required this.triggerId,
    required this.countWith,
    required this.countWithout,
    required this.avgLoudnessWith,
    required this.avgDistressWith,
    required this.avgLoudnessWithout,
    required this.avgDistressWithout,
    required this.cohensDDistress,
  });

  final int triggerId;
  final int countWith;
  final int countWithout;
  final double avgLoudnessWith;
  final double avgDistressWith;
  final double avgLoudnessWithout;
  final double avgDistressWithout;
  final double? cohensDDistress;

  double get distressDelta => avgDistressWith - avgDistressWithout;
  double get loudnessDelta => avgLoudnessWith - avgLoudnessWithout;
}

List<_TriggerImpactRow> _computeTriggerImpact(
  List<Entry> entries,
  Map<int, Set<int>> entryToTriggerIds,
  List<Trigger> allTriggers,
) {
  final rows = <_TriggerImpactRow>[];
  for (final trigger in allTriggers) {
    final withTag = <Entry>[];
    final withoutTag = <Entry>[];
    for (final e in entries) {
      final ids = entryToTriggerIds[e.id];
      if (ids != null && ids.contains(trigger.id)) {
        withTag.add(e);
      } else {
        withoutTag.add(e);
      }
    }
    if (withTag.isEmpty) continue;
    rows.add(_TriggerImpactRow(
      triggerId: trigger.id,
      countWith: withTag.length,
      countWithout: withoutTag.length,
      avgLoudnessWith: _avg(withTag.map((e) => e.loudness)),
      avgDistressWith: _avg(withTag.map((e) => e.distress)),
      avgLoudnessWithout: _avg(withoutTag.map((e) => e.loudness)),
      avgDistressWithout: _avg(withoutTag.map((e) => e.distress)),
      cohensDDistress: _cohensD(
        withTag.map((e) => e.distress).toList(),
        withoutTag.map((e) => e.distress).toList(),
      ),
    ));
  }
  rows.sort((a, b) => b.distressDelta.compareTo(a.distressDelta));
  return rows;
}

class _TriggerImpactCard extends StatelessWidget {
  const _TriggerImpactCard({required this.rows, required this.triggerById});
  final List<_TriggerImpactRow> rows;
  final Map<int, Trigger> triggerById;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.triggerImpact, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              t.triggerImpactSubtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Text(t.noTriggerData, style: theme.textTheme.bodyMedium)
            else
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 16),
                _TriggerImpactItem(
                  row: rows[i],
                  trigger: triggerById[rows[i].triggerId]!,
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _TriggerImpactItem extends StatelessWidget {
  const _TriggerImpactItem({required this.row, required this.trigger});
  final _TriggerImpactRow row;
  final Trigger trigger;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final d = row.cohensDDistress;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  triggerLabel(t, trigger),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                t.sampleCount(row.countWith),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _DeltaPill(
                  label: t.avgDistressShort,
                  value: row.avgDistressWith,
                  delta: row.distressDelta,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DeltaPill(
                  label: t.avgLoudnessShort,
                  value: row.avgLoudnessWith,
                  delta: row.loudnessDelta,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          if (d != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${t.effectSizeLabel}: ',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(
                  d.toStringAsFixed(2),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _cohensDLabel(d),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
          if (row.countWith < 5) ...[
            const SizedBox(height: 4),
            Text(
              t.smallSampleHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Conventional Cohen's d magnitude buckets (Cohen, 1988).
  String _cohensDLabel(double d) {
    final abs = d.abs();
    if (abs < 0.2) return 'negligible';
    if (abs < 0.5) return 'small';
    if (abs < 0.8) return 'medium';
    return 'large';
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({
    required this.label,
    required this.value,
    required this.delta,
    required this.color,
  });

  final String label;
  final double value;
  final double delta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final deltaSign = delta >= 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value.toStringAsFixed(1),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${t.deltaPrefix} $deltaSign${delta.toStringAsFixed(1)}',
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Sleep impact ---------------------------------------------------------

enum _SleepBucket { poor, medium, good }

_SleepBucket _bucketFor(int quality) {
  if (quality <= 3) return _SleepBucket.poor;
  if (quality <= 6) return _SleepBucket.medium;
  return _SleepBucket.good;
}

class _SleepImpactRow {
  _SleepImpactRow({
    required this.bucket,
    required this.count,
    required this.avgLoudness,
    required this.avgDistress,
  });

  final _SleepBucket bucket;
  final int count;
  final double avgLoudness;
  final double avgDistress;
}

List<_SleepImpactRow> _computeSleepImpact(
  List<Entry> entries,
  List<SleepLog> sleep,
) {
  final sleepByDate = <DateTime, int>{};
  for (final s in sleep) {
    final d = DateTime(s.date.year, s.date.month, s.date.day);
    sleepByDate[d] = s.quality;
  }

  final byBucket = <_SleepBucket, List<Entry>>{};
  for (final e in entries) {
    final date = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
    final q = sleepByDate[date];
    if (q == null) continue;
    byBucket.putIfAbsent(_bucketFor(q), () => []).add(e);
  }

  return [
    for (final bucket in _SleepBucket.values)
      if (byBucket.containsKey(bucket))
        _SleepImpactRow(
          bucket: bucket,
          count: byBucket[bucket]!.length,
          avgLoudness: _avg(byBucket[bucket]!.map((e) => e.loudness)),
          avgDistress: _avg(byBucket[bucket]!.map((e) => e.distress)),
        ),
  ];
}

class _SleepImpactCard extends StatelessWidget {
  const _SleepImpactCard({required this.rows});
  final List<_SleepImpactRow> rows;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.sleepImpact, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              t.sleepImpactSubtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Text(t.noSleepImpactData, style: theme.textTheme.bodyMedium)
            else
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 16),
                _SleepImpactItem(row: rows[i]),
              ],
          ],
        ),
      ),
    );
  }
}

class _SleepImpactItem extends StatelessWidget {
  const _SleepImpactItem({required this.row});
  final _SleepImpactRow row;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final label = switch (row.bucket) {
      _SleepBucket.poor => t.sleepBucketPoor,
      _SleepBucket.medium => t.sleepBucketMedium,
      _SleepBucket.good => t.sleepBucketGood,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
              Text(
                t.sampleCount(row.count),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _MetricLine(
                  label: t.avgDistressShort,
                  value: row.avgDistress,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricLine(
                  label: t.avgLoudnessShort,
                  value: row.avgLoudness,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          if (row.count < 5) ...[
            const SizedBox(height: 4),
            Text(
              t.smallSampleHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          '$label:',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 4),
        Text(
          value.toStringAsFixed(1),
          style: theme.textTheme.titleSmall
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// --- Sleep correlation (Pearson r) ----------------------------------------

class _SleepCorrelation {
  _SleepCorrelation({required this.rDistress, required this.rLoudness, required this.n});
  final double? rDistress;
  final double? rLoudness;
  final int n;
}

_SleepCorrelation _computeSleepCorrelation(
  List<Entry> entries,
  List<SleepLog> sleep,
) {
  final sleepByDate = <DateTime, int>{};
  for (final s in sleep) {
    final d = DateTime(s.date.year, s.date.month, s.date.day);
    sleepByDate[d] = s.quality;
  }

  // Aggregate entries by day → daily averages.
  final entriesByDate = <DateTime, List<Entry>>{};
  for (final e in entries) {
    final d = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
    entriesByDate.putIfAbsent(d, () => []).add(e);
  }

  final xs = <double>[]; // sleep quality
  final yDistress = <double>[];
  final yLoudness = <double>[];

  for (final entry in entriesByDate.entries) {
    final q = sleepByDate[entry.key];
    if (q == null) continue;
    xs.add(q.toDouble());
    yDistress.add(_avg(entry.value.map((e) => e.distress)));
    yLoudness.add(_avg(entry.value.map((e) => e.loudness)));
  }

  return _SleepCorrelation(
    rDistress: _pearson(xs, yDistress),
    rLoudness: _pearson(xs, yLoudness),
    n: xs.length,
  );
}

class _SleepCorrelationCard extends StatelessWidget {
  const _SleepCorrelationCard({required this.correlations});
  final _SleepCorrelation correlations;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasData = correlations.rDistress != null || correlations.rLoudness != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.sleepCorrelation, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              t.sleepCorrelationSubtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (!hasData)
              Text(t.noCorrelationData, style: theme.textTheme.bodyMedium)
            else ...[
              _CorrelationRow(
                label: t.pearsonVsDistress,
                r: correlations.rDistress,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 8),
              _CorrelationRow(
                label: t.pearsonVsLoudness,
                r: correlations.rLoudness,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                t.sampleCount(correlations.n),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (correlations.n < 7) ...[
                const SizedBox(height: 4),
                Text(
                  t.smallSampleHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CorrelationRow extends StatelessWidget {
  const _CorrelationRow({required this.label, required this.r, required this.color});
  final String label;
  final double? r;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          r == null ? '—' : t.pearsonR(r!.toStringAsFixed(2)),
          style: theme.textTheme.titleSmall
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// --- Time-of-day × Trigger -----------------------------------------------

enum _ToD { morning, midday, afternoon, evening, night }

extension on _ToD {
  String labelFor(AppLocalizations t) => switch (this) {
        _ToD.morning => t.todMorning,
        _ToD.midday => t.todMidday,
        _ToD.afternoon => t.todAfternoon,
        _ToD.evening => t.todEvening,
        _ToD.night => t.todNight,
      };
}

_ToD _todOf(DateTime ts) {
  final h = ts.hour;
  if (h >= 5 && h < 11) return _ToD.morning;
  if (h >= 11 && h < 15) return _ToD.midday;
  if (h >= 15 && h < 18) return _ToD.afternoon;
  if (h >= 18 && h < 22) return _ToD.evening;
  return _ToD.night;
}

class _TodTriggerRow {
  _TodTriggerRow({
    required this.tod,
    required this.triggerId,
    required this.count,
    required this.avgDistress,
    required this.avgLoudness,
  });

  final _ToD tod;
  final int triggerId;
  final int count;
  final double avgDistress;
  final double avgLoudness;
}

List<_TodTriggerRow> _computeTodTrigger(
  List<Entry> entries,
  Map<int, Set<int>> entryToTriggerIds,
  List<Trigger> allTriggers,
) {
  final triggerIds = allTriggers.map((t) => t.id).toSet();
  final buckets = <(_ToD, int), List<Entry>>{};
  for (final e in entries) {
    final ids = entryToTriggerIds[e.id];
    if (ids == null || ids.isEmpty) continue;
    final tod = _todOf(e.timestamp);
    for (final tid in ids) {
      if (!triggerIds.contains(tid)) continue;
      buckets.putIfAbsent((tod, tid), () => []).add(e);
    }
  }

  final rows = <_TodTriggerRow>[];
  buckets.forEach((key, list) {
    if (list.length < 3) return;
    rows.add(_TodTriggerRow(
      tod: key.$1,
      triggerId: key.$2,
      count: list.length,
      avgDistress: _avg(list.map((e) => e.distress)),
      avgLoudness: _avg(list.map((e) => e.loudness)),
    ));
  });
  rows.sort((a, b) => b.avgDistress.compareTo(a.avgDistress));
  return rows.take(8).toList();
}

class _TodTriggerCard extends StatelessWidget {
  const _TodTriggerCard({required this.rows, required this.triggerById});
  final List<_TodTriggerRow> rows;
  final Map<int, Trigger> triggerById;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.todTriggerMatrix, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              t.todTriggerSubtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Text(t.noTodTriggerData, style: theme.textTheme.bodyMedium)
            else
              for (final row in rows) _TodTriggerRowView(row: row, trigger: triggerById[row.triggerId]!),
          ],
        ),
      ),
    );
  }
}

class _TodTriggerRowView extends StatelessWidget {
  const _TodTriggerRowView({required this.row, required this.trigger});
  final _TodTriggerRow row;
  final Trigger trigger;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '${triggerLabel(t, trigger)} • ${row.tod.labelFor(t)}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            '${t.avgDistressShort} ${row.avgDistress.toStringAsFixed(1)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(
            t.sampleCount(row.count),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// --- Tag co-occurrence ----------------------------------------------------

class _CoOccurrenceRow {
  _CoOccurrenceRow({
    required this.triggerIdA,
    required this.triggerIdB,
    required this.count,
    required this.avgDistress,
  });

  final int triggerIdA;
  final int triggerIdB;
  final int count;
  final double avgDistress;
}

List<_CoOccurrenceRow> _computeCoOccurrence(
  List<Entry> entries,
  Map<int, Set<int>> entryToTriggerIds,
) {
  // pairKey is encoded as "min:max" so order doesn't matter.
  final pairs = <(int, int), List<Entry>>{};
  for (final e in entries) {
    final ids = entryToTriggerIds[e.id];
    if (ids == null || ids.length < 2) continue;
    final list = ids.toList()..sort();
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final key = (list[i], list[j]);
        pairs.putIfAbsent(key, () => []).add(e);
      }
    }
  }

  final rows = <_CoOccurrenceRow>[];
  pairs.forEach((key, list) {
    if (list.length < 2) return;
    rows.add(_CoOccurrenceRow(
      triggerIdA: key.$1,
      triggerIdB: key.$2,
      count: list.length,
      avgDistress: _avg(list.map((e) => e.distress)),
    ));
  });
  rows.sort((a, b) => b.count.compareTo(a.count));
  return rows.take(5).toList();
}

class _CoOccurrenceCard extends StatelessWidget {
  const _CoOccurrenceCard({required this.rows, required this.triggerById});
  final List<_CoOccurrenceRow> rows;
  final Map<int, Trigger> triggerById;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.coOccurrence, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              t.coOccurrenceSubtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Text(t.noCoOccurrenceData, style: theme.textTheme.bodyMedium)
            else
              for (final row in rows)
                _CoOccurrenceRowView(
                  row: row,
                  triggerA: triggerById[row.triggerIdA]!,
                  triggerB: triggerById[row.triggerIdB]!,
                ),
          ],
        ),
      ),
    );
  }
}

class _CoOccurrenceRowView extends StatelessWidget {
  const _CoOccurrenceRowView({
    required this.row,
    required this.triggerA,
    required this.triggerB,
  });
  final _CoOccurrenceRow row;
  final Trigger triggerA;
  final Trigger triggerB;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '${triggerLabel(t, triggerA)} + ${triggerLabel(t, triggerB)}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            '${t.avgDistressShort} ${row.avgDistress.toStringAsFixed(1)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(
            t.sampleCount(row.count),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
