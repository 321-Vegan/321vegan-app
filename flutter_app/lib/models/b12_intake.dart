import 'b12_reminder_settings.dart';

/// One recorded B12 intake: the day it was taken plus the reminder
/// frequency in effect when it was recorded (API/storage values: 'daily',
/// 'weekly', 'twice_weekly', 'biweekly'; null for intakes recorded before
/// frequency snapshotting existed).
class B12Intake {
  final DateTime date;
  final String? frequency;

  B12Intake({required this.date, this.frequency});
}

/// Parse an API/storage frequency value; null for unknown values so the
/// caller can fall back to the configured frequency.
ReminderFrequency? reminderFrequencyFromApi(String? frequency) {
  switch (frequency) {
    case 'daily':
      return ReminderFrequency.daily;
    case 'weekly':
      return ReminderFrequency.weekly;
    case 'twice_weekly':
      return ReminderFrequency.twiceWeekly;
    case 'biweekly':
      return ReminderFrequency.biweekly;
    default:
      return null;
  }
}

String reminderFrequencyToApi(ReminderFrequency frequency) {
  switch (frequency) {
    case ReminderFrequency.daily:
      return 'daily';
    case ReminderFrequency.weekly:
      return 'weekly';
    case ReminderFrequency.twiceWeekly:
      return 'twice_weekly';
    case ReminderFrequency.biweekly:
      return 'biweekly';
  }
}
