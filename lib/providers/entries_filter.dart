import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session-scoped filter for the Entries tab. Tag matching is inclusive
/// (OR): an entry passes when it carries at least one of [triggerIds].
class EntriesFilter {
  const EntriesFilter({this.triggerIds = const {}, this.range});
  final Set<int> triggerIds;
  final DateTimeRange? range;

  bool get isActive => triggerIds.isNotEmpty || range != null;

  EntriesFilter copyWith({
    Set<int>? triggerIds,
    DateTimeRange? range,
    bool clearRange = false,
  }) {
    return EntriesFilter(
      triggerIds: triggerIds ?? this.triggerIds,
      range: clearRange ? null : (range ?? this.range),
    );
  }
}

final entriesFilterProvider =
    StateProvider<EntriesFilter>((ref) => const EntriesFilter());
