import '../l10n/app_localizations.dart';
import 'database.dart';

/// Returns the user-visible label for [trigger]:
/// - Custom triggers display their stored label.
/// - Predefined triggers are looked up via [AppLocalizations] by their key.
String triggerLabel(AppLocalizations t, Trigger trigger) {
  final custom = trigger.customLabel;
  if (custom != null) return custom;
  return switch (trigger.key) {
    'stress' => t.triggerStress,
    'loudSound' => t.triggerLoudSound,
    'caffeine' => t.triggerCaffeine,
    'alcohol' => t.triggerAlcohol,
    'lackOfSleep' => t.triggerLackOfSleep,
    'weather' => t.triggerWeather,
    'screenTime' => t.triggerScreenTime,
    'exercise' => t.triggerExercise,
    'medication' => t.triggerMedication,
    'headache' => t.triggerHeadache,
    _ => trigger.key,
  };
}
