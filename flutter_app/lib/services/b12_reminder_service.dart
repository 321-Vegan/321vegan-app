import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/b12_reminder_settings.dart';
import 'notification_service.dart';

class B12ReminderService {
  static const String _settingsKey = 'b12_reminder_settings';
  static const int _notificationId = 1000; // Unique ID for B12 notifications
  static const int _biweeklyNotificationId =
      1001; // Second ID for biweekly alternating
  static const String _intakeHistoryKey = 'b12_intake_history';

  static final NotificationService _notificationService = NotificationService();

  /// Get saved reminder settings
  static Future<B12ReminderSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);

    if (settingsJson != null) {
      try {
        return B12ReminderSettings.fromJson(json.decode(settingsJson));
      } catch (e) {
        // If there's an error parsing, return default settings
        return B12ReminderSettings();
      }
    }

    return B12ReminderSettings();
  }

  /// Save reminder settings
  static Future<void> saveSettings(B12ReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, json.encode(settings.toJson()));
  }

  /// Schedule reminder based on settings
  static Future<void> scheduleReminder(B12ReminderSettings settings) async {
    // Cancel any existing reminders first
    await cancelReminder();

    if (!settings.enabled) {
      await saveSettings(settings);
      return;
    }

    // Request notification permissions
    final hasPermission = await _notificationService.requestPermissions();
    if (!hasPermission) {
      return;
    }

    const title = '💊 Rappel B12';
    const body = 'N\'oubliez pas de prendre votre vitamine B12 !';

    switch (settings.frequency) {
      case ReminderFrequency.daily:
        await _notificationService.scheduleDailyNotification(
          id: _notificationId,
          title: title,
          body: body,
          hour: settings.hour,
          minute: settings.minute,
          payload: 'b12_reminder',
        );
        break;

      case ReminderFrequency.weekly:
        if (settings.dayOfWeek != null) {
          await _notificationService.scheduleWeeklyNotification(
            id: _notificationId,
            title: title,
            body: body,
            dayOfWeek: settings.dayOfWeek!,
            hour: settings.hour,
            minute: settings.minute,
            payload: 'b12_reminder',
          );
        }
        break;

      case ReminderFrequency.twiceWeekly:
        if (settings.daysOfWeek != null && settings.daysOfWeek!.length == 2) {
          final sorted = List<int>.from(settings.daysOfWeek!)..sort();
          // Schedule two weekly notifications, one for each selected day
          await _notificationService.scheduleWeeklyNotification(
            id: _notificationId,
            title: title,
            body: body,
            dayOfWeek: sorted[0],
            hour: settings.hour,
            minute: settings.minute,
            payload: 'b12_reminder',
          );
          await _notificationService.scheduleWeeklyNotification(
            id: _biweeklyNotificationId,
            title: title,
            body: body,
            dayOfWeek: sorted[1],
            hour: settings.hour,
            minute: settings.minute,
            payload: 'b12_reminder',
          );
        }
        break;

      case ReminderFrequency.biweekly:
        if (settings.dayOfWeek != null) {
          await _scheduleBiweeklyNotification(
            id: _notificationId,
            title: title,
            body: body,
            dayOfWeek: settings.dayOfWeek!,
            hour: settings.hour,
            minute: settings.minute,
            payload: 'b12_reminder_biweekly',
            startDate: settings.biweeklyStartDate,
          );
        }
        break;
    }

    // Save the settings
    await saveSettings(settings);
  }

  /// Schedule a biweekly notification
  static Future<void> _scheduleBiweeklyNotification({
    required int id,
    required String title,
    required String body,
    required int dayOfWeek,
    required int hour,
    required int minute,
    String? payload,
    DateTime? startDate,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    // Calculate days until the next target day of week
    int daysUntilTarget = (dayOfWeek - now.weekday) % 7;
    if (daysUntilTarget == 0) {
      final todayScheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (todayScheduledTime.isBefore(now)) {
        daysUntilTarget = 7;
      }
    }

    // Candidate date = next occurrence of this day of week
    var candidateDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).add(Duration(days: daysUntilTarget));

    // Use startDate to determine which week is a "reminder week"
    if (startDate != null) {
      final startDay = DateTime(startDate.year, startDate.month, startDate.day);
      final candidateDay =
          DateTime(candidateDate.year, candidateDate.month, candidateDate.day);
      final daysDiff = candidateDay.difference(startDay).inDays;
      // If the number of weeks since start is odd, shift by 7 days
      final weeksDiff = daysDiff ~/ 7;
      if (weeksDiff % 2 != 0) {
        candidateDate = candidateDate.add(const Duration(days: 7));
      }
    } else {
      // Fallback: use last notification date for alternating
      final prefs = await SharedPreferences.getInstance();
      final lastNotificationMillis = prefs.getInt('b12_last_notification_date');
      if (lastNotificationMillis != null) {
        try {
          final lastDate =
              DateTime.fromMillisecondsSinceEpoch(lastNotificationMillis);
          final daysSinceLastNotification = now.difference(lastDate).inDays;
          if (daysSinceLastNotification < 7) {
            candidateDate = candidateDate.add(const Duration(days: 7));
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }
    }

    await _notificationService.scheduleNotification(
      id: id,
      title: title,
      body: body,
      scheduledDate: candidateDate,
      payload: payload,
    );

    // Save the scheduled date for biweekly tracking
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'b12_next_notification_date',
      candidateDate.millisecondsSinceEpoch,
    );
  }

  /// Mark that notification was received (for biweekly tracking)
  static Future<void> markNotificationReceived() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'b12_last_notification_date',
      DateTime.now().millisecondsSinceEpoch,
    );

    // If biweekly, reschedule the next one
    final settings = await getSettings();
    if (settings.enabled && settings.frequency == ReminderFrequency.biweekly) {
      await scheduleReminder(settings);
    }
  }

  /// Check if the biweekly notification has passed without being acknowledged
  /// and reschedule if needed. Call this on app resume.
  static Future<void> checkAndRescheduleIfNeeded() async {
    final settings = await getSettings();
    if (!settings.enabled || settings.frequency != ReminderFrequency.biweekly) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final nextMillis = prefs.getInt('b12_next_notification_date');
    if (nextMillis == null ||
        DateTime.fromMillisecondsSinceEpoch(nextMillis)
            .isBefore(DateTime.now())) {
      await scheduleReminder(settings);
    }
  }

  /// Cancel all B12 reminders
  static Future<void> cancelReminder() async {
    await _notificationService.cancelNotification(_notificationId);
    await _notificationService.cancelNotification(_biweeklyNotificationId);
  }

  /// Get next scheduled notification time
  static Future<DateTime?> getNextNotificationTime() async {
    final settings = await getSettings();

    if (!settings.enabled) {
      return null;
    }

    final now = DateTime.now();

    switch (settings.frequency) {
      case ReminderFrequency.daily:
        var nextTime = DateTime(
          now.year,
          now.month,
          now.day,
          settings.hour,
          settings.minute,
        );

        if (nextTime.isBefore(now)) {
          nextTime = nextTime.add(const Duration(days: 1));
        }

        return nextTime;

      case ReminderFrequency.weekly:
        if (settings.dayOfWeek == null) return null;

        int daysUntilTarget = (settings.dayOfWeek! - now.weekday) % 7;
        if (daysUntilTarget == 0) {
          final todayScheduledTime = DateTime(
            now.year,
            now.month,
            now.day,
            settings.hour,
            settings.minute,
          );
          if (todayScheduledTime.isBefore(now)) {
            daysUntilTarget = 7;
          }
        }

        return DateTime(
          now.year,
          now.month,
          now.day,
          settings.hour,
          settings.minute,
        ).add(Duration(days: daysUntilTarget));

      case ReminderFrequency.twiceWeekly:
        if (settings.daysOfWeek == null || settings.daysOfWeek!.length != 2) {
          return null;
        }

        DateTime? earliest;
        for (final day in settings.daysOfWeek!) {
          int daysUntil = (day - now.weekday) % 7;
          if (daysUntil == 0) {
            final todayTime = DateTime(
              now.year,
              now.month,
              now.day,
              settings.hour,
              settings.minute,
            );
            if (todayTime.isBefore(now)) {
              daysUntil = 7;
            }
          }

          final candidate = DateTime(
            now.year,
            now.month,
            now.day,
            settings.hour,
            settings.minute,
          ).add(Duration(days: daysUntil));

          if (earliest == null || candidate.isBefore(earliest)) {
            earliest = candidate;
          }
        }

        return earliest;

      case ReminderFrequency.biweekly:
        // For biweekly, check the saved next notification date
        final prefs = await SharedPreferences.getInstance();
        final nextDateMillis = prefs.getInt('b12_next_notification_date');

        if (nextDateMillis != null) {
          try {
            final saved = DateTime.fromMillisecondsSinceEpoch(nextDateMillis);
            if (saved.isAfter(now)) return saved;
            // ignore: empty_catches
          } catch (e) {}
        }

        // Calculate next biweekly occurrence
        if (settings.dayOfWeek == null) return null;

        int daysUntilTarget = (settings.dayOfWeek! - now.weekday) % 7;
        if (daysUntilTarget == 0) {
          final todayScheduledTime = DateTime(
            now.year,
            now.month,
            now.day,
            settings.hour,
            settings.minute,
          );
          if (todayScheduledTime.isBefore(now)) {
            daysUntilTarget = 7;
          }
        }

        var candidate = DateTime(
          now.year,
          now.month,
          now.day,
          settings.hour,
          settings.minute,
        ).add(Duration(days: daysUntilTarget));

        // Use startDate to determine correct week parity
        if (settings.biweeklyStartDate != null) {
          final startDay = DateTime(
            settings.biweeklyStartDate!.year,
            settings.biweeklyStartDate!.month,
            settings.biweeklyStartDate!.day,
          );
          final candidateDay =
              DateTime(candidate.year, candidate.month, candidate.day);
          final daysDiff = candidateDay.difference(startDay).inDays;
          final weeksDiff = daysDiff ~/ 7;
          if (weeksDiff % 2 != 0) {
            candidate = candidate.add(const Duration(days: 7));
          }
        }

        return candidate;
    }
  }

  /// Record a B12 intake for today
  static Future<void> recordB12Intake() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_intakeHistoryKey) ?? [];

    // Store as day-only timestamp to avoid duplicates on the same day
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final todayMillis = todayDate.millisecondsSinceEpoch.toString();

    // Don't add duplicate for same day
    if (!historyJson.contains(todayMillis)) {
      historyJson.add(todayMillis);
      await prefs.setStringList(_intakeHistoryKey, historyJson);
    }
  }

  /// Get B12 intake history, sorted descending (most recent first)
  static Future<List<DateTime>> getB12IntakeHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_intakeHistoryKey) ?? [];

    final dates = historyJson
        .map((ms) {
          try {
            return DateTime.fromMillisecondsSinceEpoch(int.parse(ms));
          } catch (e) {
            return null;
          }
        })
        .whereType<DateTime>()
        .toList();

    dates.sort((a, b) => b.compareTo(a));
    return dates;
  }



  /// Current streak: number of days covered by the unbroken chain of
  /// on-schedule intakes, from the chain's first intake through today.
  /// Counting days (rather than intakes) keeps the streak fair across
  /// different intake rhythms: a week on schedule is worth 7 whether it
  /// took seven daily intakes or a single weekly one. The allowed gap
  /// between intakes follows the configured reminder frequency.
  static Future<int> getB12Streak() async {
    final history = await getB12IntakeHistory();
    if (history.isEmpty) return 0;

    final settings = await getSettings();
    final maxGapDays = _maxGapDaysForFrequency(settings.frequency);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Streak is broken if the latest intake is already overdue
    if (today.difference(history.first).inDays > maxGapDays) return 0;

    DateTime chainStart = history.first;
    for (int i = 0; i < history.length - 1; i++) {
      if (history[i].difference(history[i + 1]).inDays <= maxGapDays) {
        chainStart = history[i + 1];
      } else {
        break;
      }
    }
    return today.difference(chainStart).inDays + 1;
  }

  /// Maximum days between two intakes before the streak breaks
  /// (expected interval plus a small grace period)
  static int _maxGapDaysForFrequency(ReminderFrequency frequency) {
    switch (frequency) {
      case ReminderFrequency.daily:
        return 1;
      case ReminderFrequency.twiceWeekly:
        return 5;
      case ReminderFrequency.weekly:
        return 8;
      case ReminderFrequency.biweekly:
        return 16;
    }
  }

  /// Check if notifications are enabled in system settings
  static Future<bool> areNotificationsEnabled() async {
    return await _notificationService.areNotificationsEnabled();
  }
}
