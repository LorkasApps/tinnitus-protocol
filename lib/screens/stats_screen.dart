import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';

enum TimePeriod { d7, d30, d90, all }

extension TimePeriodX on TimePeriod {
  String labelFor(AppLocalizations t) => switch (this) {
        TimePeriod.d7 => t.period7d,
        TimePeriod.d30 => t.period30d,
        TimePeriod.d90 => t.period90d,
        TimePeriod.all => t.periodAll,
      };

  Duration? get duration => switch (this) {
        TimePeriod.d7 => const Duration(days: 7),
        TimePeriod.d30 => const Duration(days: 30),
        TimePeriod.d90 => const Duration(days: 90),
        TimePeriod.all => null,
      };
}

enum AggregateMode { perEntry, perDay }

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  TimePeriod _period = TimePeriod.d30;
  AggregateMode _aggregate = AggregateMode.perDay;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final entriesAsync = ref.watch(entriesStreamProvider);
    final sleepAsync = ref.watch(sleepLogsStreamProvider);

    if (entriesAsync.isLoading || sleepAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (entriesAsync.hasError) {
      return Center(child: Text(t.errorPrefix(entriesAsync.error.toString())));
    }
    if (sleepAsync.hasError) {
      return Center(child: Text(t.errorPrefix(sleepAsync.error.toString())));
    }

    final allEntries = entriesAsync.value ?? const <Entry>[];
    final allSleep = sleepAsync.value ?? const <SleepLog>[];

    if (allEntries.isEmpty && allSleep.isEmpty) {
      return const _Empty();
    }

    final cutoff = _cutoffFor(_period, allEntries, allSleep);
    final entries = _filterByCutoff(allEntries, cutoff, (e) => e.timestamp);
    final sleep = _filterByCutoff(allSleep, cutoff, (s) => s.date);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Controls(
          period: _period,
          aggregate: _aggregate,
          onPeriodChanged: (p) => setState(() => _period = p),
          onAggregateChanged: (m) => setState(() => _aggregate = m),
        ),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          _FilteredEmpty(label: t.noTinnitusInPeriod)
        else ...[
          _TrendChartCard(entries: entries, aggregate: _aggregate),
          const SizedBox(height: 16),
        ],
        if (sleep.isEmpty)
          _FilteredEmpty(label: t.noSleepInPeriod)
        else ...[
          _SleepChartCard(logs: sleep),
          const SizedBox(height: 16),
        ],
        _StatsTableCard(entries: entries, sleep: sleep),
        const SizedBox(height: 16),
        if (entries.isNotEmpty) _TimeOfDayCard(entries: entries),
      ],
    );
  }
}

DateTime? _cutoffFor(
  TimePeriod period,
  List<Entry> entries,
  List<SleepLog> sleep,
) {
  final dur = period.duration;
  if (dur == null) return null;
  DateTime? anchor;
  for (final e in entries) {
    if (anchor == null || e.timestamp.isAfter(anchor)) anchor = e.timestamp;
  }
  for (final s in sleep) {
    if (anchor == null || s.date.isAfter(anchor)) anchor = s.date;
  }
  anchor ??= DateTime.now();
  final anchorDay = DateTime(anchor.year, anchor.month, anchor.day);
  return anchorDay.subtract(Duration(days: dur.inDays - 1));
}

List<T> _filterByCutoff<T>(
  List<T> all,
  DateTime? cutoff,
  DateTime Function(T) ts,
) {
  final list = [...all];
  if (cutoff != null) {
    list.removeWhere((e) => ts(e).isBefore(cutoff));
  }
  list.sort((a, b) => ts(a).compareTo(ts(b)));
  return list;
}

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
            Icon(Icons.show_chart, size: 64, color: theme.colorScheme.onSurfaceVariant),
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

class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.period,
    required this.aggregate,
    required this.onPeriodChanged,
    required this.onAggregateChanged,
  });

  final TimePeriod period;
  final AggregateMode aggregate;
  final ValueChanged<TimePeriod> onPeriodChanged;
  final ValueChanged<AggregateMode> onAggregateChanged;

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
            onSelectionChanged: (s) => onPeriodChanged(s.first),
          ),
        ),
        const SizedBox(height: 12),
        Text(t.tinnitusTrend, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<AggregateMode>(
            segments: [
              ButtonSegment(
                value: AggregateMode.perEntry,
                label: Text(t.perEntry),
                icon: const Icon(Icons.scatter_plot),
              ),
              ButtonSegment(
                value: AggregateMode.perDay,
                label: Text(t.perDay),
                icon: const Icon(Icons.calendar_today),
              ),
            ],
            selected: {aggregate},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onAggregateChanged(s.first),
          ),
        ),
      ],
    );
  }
}

class _DayBucket {
  _DayBucket({
    required this.day,
    required this.loudness,
    required this.distress,
    required this.count,
  });
  final DateTime day;
  final double loudness;
  final double distress;
  final int count;
}

List<_DayBucket> _groupByDay(List<Entry> entries) {
  final Map<DateTime, List<Entry>> byDay = {};
  for (final e in entries) {
    final d = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
    byDay.putIfAbsent(d, () => []).add(e);
  }
  final keys = byDay.keys.toList()..sort();
  return [
    for (final k in keys)
      _DayBucket(
        day: k,
        loudness: _avg(byDay[k]!.map((e) => e.loudness)),
        distress: _avg(byDay[k]!.map((e) => e.distress)),
        count: byDay[k]!.length,
      )
  ];
}

double _avg(Iterable<int> v) {
  if (v.isEmpty) return 0;
  return v.reduce((a, b) => a + b) / v.length;
}

LineTouchData _lineTooltip(ThemeData theme) {
  return LineTouchData(
    touchTooltipData: LineTouchTooltipData(
      getTooltipColor: (_) => theme.colorScheme.inverseSurface,
      getTooltipItems: (spots) => [
        for (final s in spots)
          LineTooltipItem(
            s.y.toStringAsFixed(1),
            TextStyle(
              color: theme.colorScheme.onInverseSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    ),
  );
}

BarTouchData _barTooltip(ThemeData theme) {
  return BarTouchData(
    touchTooltipData: BarTouchTooltipData(
      getTooltipColor: (_) => theme.colorScheme.inverseSurface,
      getTooltipItem: (group, groupIdx, rod, rodIdx) => BarTooltipItem(
        rod.toY.toStringAsFixed(1),
        TextStyle(
          color: theme.colorScheme.onInverseSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _TrendChartCard extends StatelessWidget {
  const _TrendChartCard({required this.entries, required this.aggregate});
  final List<Entry> entries;
  final AggregateMode aggregate;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final loc = Localizations.localeOf(context).languageCode;
    final dateFmt = DateFormat.Md(loc);

    late List<FlSpot> loudness;
    late List<FlSpot> distress;
    late int len;
    late String Function(int index) labelAt;
    late String title;

    if (aggregate == AggregateMode.perDay) {
      final days = _groupByDay(entries);
      len = days.length;
      loudness = [for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), days[i].loudness)];
      distress = [for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), days[i].distress)];
      labelAt = (i) => dateFmt.format(days[i].day);
      title = t.tinnitusPerDayTitle(len);
    } else {
      len = entries.length;
      loudness = [for (var i = 0; i < entries.length; i++) FlSpot(i.toDouble(), entries[i].loudness.toDouble())];
      distress = [for (var i = 0; i < entries.length; i++) FlSpot(i.toDouble(), entries[i].distress.toDouble())];
      labelAt = (i) => dateFmt.format(entries[i].timestamp);
      title = t.tinnitusPerEntryTitle(entries.length);
    }

    final tickInterval = (len / 5).clamp(1, double.infinity).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 10,
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, interval: 2, reservedSize: 30),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: tickInterval,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= len) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(labelAt(idx), style: theme.textTheme.bodySmall),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineTouchData: _lineTooltip(theme),
                  lineBarsData: [
                    _line(loudness, theme.colorScheme.primary),
                    _line(distress, theme.colorScheme.error),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Legend(label: t.loudness, color: theme.colorScheme.primary),
                _Legend(label: t.distress, color: theme.colorScheme.error),
              ],
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      color: color,
      isCurved: true,
      barWidth: 2.5,
      dotData: const FlDotData(show: false),
    );
  }
}

class _SleepChartCard extends StatelessWidget {
  const _SleepChartCard({required this.logs});
  final List<SleepLog> logs;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final loc = Localizations.localeOf(context).languageCode;
    final dateFmt = DateFormat.Md(loc);
    final spots = [
      for (var i = 0; i < logs.length; i++)
        FlSpot(i.toDouble(), logs[i].quality.toDouble())
    ];
    final tickInterval = (logs.length / 5).clamp(1, double.infinity).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.sleepChartTitle(logs.length), style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 10,
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, interval: 2, reservedSize: 30),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: tickInterval,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= logs.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(dateFmt.format(logs[idx].date), style: theme.textTheme.bodySmall),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineTouchData: _lineTooltip(theme),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      color: theme.colorScheme.tertiary,
                      isCurved: true,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _Legend(label: t.sleep, color: theme.colorScheme.tertiary),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _MetricStats {
  _MetricStats({required this.min, required this.max, required this.mean, required this.median});
  final int min;
  final int max;
  final double mean;
  final double median;

  static _MetricStats? from(Iterable<int> values) {
    final list = values.toList()..sort();
    if (list.isEmpty) return null;
    final mean = list.reduce((a, b) => a + b) / list.length;
    final mid = list.length ~/ 2;
    final median = list.length.isOdd ? list[mid].toDouble() : (list[mid - 1] + list[mid]) / 2;
    return _MetricStats(min: list.first, max: list.last, mean: mean, median: median);
  }
}

class _StatsTableCard extends StatelessWidget {
  const _StatsTableCard({required this.entries, required this.sleep});
  final List<Entry> entries;
  final List<SleepLog> sleep;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final loud = _MetricStats.from(entries.map((e) => e.loudness));
    final dist = _MetricStats.from(entries.map((e) => e.distress));
    final slp = _MetricStats.from(sleep.map((e) => e.quality));

    if (loud == null && dist == null && slp == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${t.statsTitle} · ${t.sampleCount(entries.length + sleep.length)}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHigh),
                  children: [
                    _Cell(t.colMetric, header: true),
                    _Cell(t.colMin, header: true),
                    _Cell(t.colMean, header: true),
                    _Cell(t.colMedian, header: true),
                    _Cell(t.colMax, header: true),
                  ],
                ),
                if (loud != null) _row(t.loudness, loud),
                if (dist != null) _row(t.distress, dist),
                if (slp != null) _row(t.sleep, slp),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _row(String name, _MetricStats s) {
    String f(double v) => v.toStringAsFixed(1);
    return TableRow(children: [
      _Cell(name),
      _Cell('${s.min}'),
      _Cell(f(s.mean)),
      _Cell(f(s.median)),
      _Cell('${s.max}'),
    ]);
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.header = false});
  final String text;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final style = header
        ? Theme.of(context).textTheme.labelMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(text, style: style),
    );
  }
}

enum _ToD { morning, midday, afternoon, evening, night }

extension on _ToD {
  String labelFor(AppLocalizations t) => switch (this) {
        _ToD.morning => t.todMorning,
        _ToD.midday => t.todMidday,
        _ToD.afternoon => t.todAfternoon,
        _ToD.evening => t.todEvening,
        _ToD.night => t.todNight,
      };

  String get range => switch (this) {
        _ToD.morning => '5–11',
        _ToD.midday => '11–15',
        _ToD.afternoon => '15–18',
        _ToD.evening => '18–22',
        _ToD.night => '22–5',
      };
}

_ToD _bucketOf(DateTime t) {
  final h = t.hour;
  if (h >= 5 && h < 11) return _ToD.morning;
  if (h >= 11 && h < 15) return _ToD.midday;
  if (h >= 15 && h < 18) return _ToD.afternoon;
  if (h >= 18 && h < 22) return _ToD.evening;
  return _ToD.night;
}

class _ToDStats {
  _ToDStats({required this.count, required this.loudness, required this.distress});
  final int count;
  final double loudness;
  final double distress;
}

class _TimeOfDayCard extends StatelessWidget {
  const _TimeOfDayCard({required this.entries});
  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final Map<_ToD, List<Entry>> grouped = {for (final t in _ToD.values) t: []};
    for (final e in entries) {
      grouped[_bucketOf(e.timestamp)]!.add(e);
    }
    final stats = <_ToD, _ToDStats>{
      for (final t in _ToD.values)
        t: _ToDStats(
          count: grouped[t]!.length,
          loudness: _avg(grouped[t]!.map((e) => e.loudness)),
          distress: _avg(grouped[t]!.map((e) => e.distress)),
        ),
    };

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < _ToD.values.length; i++) {
      final tod = _ToD.values[i];
      final s = stats[tod]!;
      groups.add(
        BarChartGroupData(
          x: i,
          barsSpace: 2,
          barRods: [
            _rod(s.loudness, theme.colorScheme.primary),
            _rod(s.distress, theme.colorScheme.error),
          ],
        ),
      );
    }

    final anyData = stats.values.any((s) => s.count > 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${t.timeOfDay} · ${t.sampleCount(entries.length)}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              t.timeOfDaySubtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (!anyData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(t.noDataInPeriod, style: theme.textTheme.bodyMedium),
                ),
              )
            else ...[
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    minY: 0,
                    maxY: 10,
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    barTouchData: _barTooltip(theme),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true, interval: 2, reservedSize: 28),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= _ToD.values.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _ToD.values[idx].labelFor(t),
                                style: theme.textTheme.bodySmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: groups,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Legend(label: t.loudness, color: theme.colorScheme.primary),
                  _Legend(label: t.distress, color: theme.colorScheme.error),
                ],
              ),
              const SizedBox(height: 12),
              Text(t.countPerTimeOfDay, style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              ..._ToD.values.map((tod) {
                final s = stats[tod]!;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text('${tod.labelFor(t)} (${tod.range})')),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${s.count}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: s.count == 0
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  BarChartRodData _rod(double v, Color color) {
    return BarChartRodData(
      toY: v,
      color: color,
      width: 10,
      borderRadius: const BorderRadius.all(Radius.circular(2)),
    );
  }
}
