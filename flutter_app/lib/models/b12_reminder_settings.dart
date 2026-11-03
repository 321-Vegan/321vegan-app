enum ReminderFrequency {
  daily,
  weekly,
  twiceWeekly,
  biweekly,
  monthly, // stored by index: new values go last
}

class B12ReminderSettings {
  /// Monthly reminders stop at the 28th so every month has the day — the
  /// OS-repeating trigger would silently skip months without it.
  static const int maxDayOfMonth = 28;

  bool enabled;
  ReminderFrequency frequency;
  int hour; // 0-23
  int minute; // 0-59
  int? dayOfWeek; // 1-7 (Monday = 1, Sunday = 7), null for daily
  List<int>? daysOfWeek; // For twiceWeekly: exactly 2 days (1-7)
  DateTime? biweeklyStartDate; // Starting date for biweekly cycle
  int? dayOfMonth; // For monthly: 1-[maxDayOfMonth]

  B12ReminderSettings({
    this.enabled = false,
    this.frequency = ReminderFrequency.daily,
    this.hour = 9,
    this.minute = 0,
    this.dayOfWeek = 1, // Default to Monday
    this.daysOfWeek,
    this.biweeklyStartDate,
    this.dayOfMonth,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'frequency': frequency.index,
      'hour': hour,
      'minute': minute,
      'dayOfWeek': dayOfWeek,
      'daysOfWeek': daysOfWeek,
      'biweeklyStartDate': biweeklyStartDate?.millisecondsSinceEpoch,
      'dayOfMonth': dayOfMonth,
    };
  }

  // Create from JSON
  factory B12ReminderSettings.fromJson(Map<String, dynamic> json) {
    return B12ReminderSettings(
      enabled: json['enabled'] ?? false,
      frequency: ReminderFrequency.values[json['frequency'] ?? 1],
      hour: json['hour'] ?? 9,
      minute: json['minute'] ?? 0,
      dayOfWeek: json['dayOfWeek'],
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      biweeklyStartDate: json['biweeklyStartDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['biweeklyStartDate'])
          : null,
      dayOfMonth: json['dayOfMonth'],
    );
  }

  // Get a user-friendly description of the reminder
  String getDescription() {
    if (!enabled) return 'Désactivé';

    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    switch (frequency) {
      case ReminderFrequency.daily:
        return 'Tous les jours à $timeStr';
      case ReminderFrequency.weekly:
        final dayName = _getDayName(dayOfWeek ?? 1);
        return 'Chaque $dayName à $timeStr';
      case ReminderFrequency.twiceWeekly:
        if (daysOfWeek != null && daysOfWeek!.length == 2) {
          final sorted = List<int>.from(daysOfWeek!)..sort();
          final day1 = _getDayName(sorted[0]);
          final day2 = _getDayName(sorted[1]);
          return 'Chaque $day1 et $day2 à $timeStr';
        }
        return 'Deux fois par semaine à $timeStr';
      case ReminderFrequency.biweekly:
        final dayName = _getDayName(dayOfWeek ?? 1);
        return 'Toutes les deux semaines le $dayName à $timeStr';
      case ReminderFrequency.monthly:
        final day = dayOfMonth ?? 1;
        return 'Le ${day == 1 ? '1er' : '$day'} de chaque mois à $timeStr';
    }
  }

  String _getDayName(int day) {
    switch (day) {
      case 1:
        return 'lundi';
      case 2:
        return 'mardi';
      case 3:
        return 'mercredi';
      case 4:
        return 'jeudi';
      case 5:
        return 'vendredi';
      case 6:
        return 'samedi';
      case 7:
        return 'dimanche';
      default:
        return 'lundi';
    }
  }

  B12ReminderSettings copyWith({
    bool? enabled,
    ReminderFrequency? frequency,
    int? hour,
    int? minute,
    Object? dayOfWeek = _undefined,
    Object? daysOfWeek = _undefined,
    Object? biweeklyStartDate = _undefined,
    Object? dayOfMonth = _undefined,
  }) {
    return B12ReminderSettings(
      enabled: enabled ?? this.enabled,
      frequency: frequency ?? this.frequency,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      dayOfWeek: identical(dayOfWeek, _undefined)
          ? this.dayOfWeek
          : (dayOfWeek as int?),
      daysOfWeek: identical(daysOfWeek, _undefined)
          ? this.daysOfWeek
          : (daysOfWeek as List<int>?),
      biweeklyStartDate: identical(biweeklyStartDate, _undefined)
          ? this.biweeklyStartDate
          : (biweeklyStartDate as DateTime?),
      dayOfMonth: identical(dayOfMonth, _undefined)
          ? this.dayOfMonth
          : (dayOfMonth as int?),
    );
  }
}

// Sentinel value for optional parameters in copyWith
const Object _undefined = Object();
