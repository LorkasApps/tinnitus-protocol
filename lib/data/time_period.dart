import '../l10n/app_localizations.dart';

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
