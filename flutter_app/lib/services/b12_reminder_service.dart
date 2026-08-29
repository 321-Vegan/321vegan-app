import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/b12_intake.dart';
import '../models/b12_reminder_settings.dart';
import 'b12_sync_service.dart';
import 'notification_service.dart';

class B12ReminderService {
  static const String _settingsKey = 'b12_reminder_settings';
  static const int _notificationId = 1000;
  static const int _biweeklyNotificationId = 1001; // biweekly's second slot
  static const String _intakeHistoryKey = 'b12_intake_history';

  static final NotificationService _notificationService = NotificationService();

  /// Bumped whenever the locally stored intake history changes, so UI
  /// already on screen can reload. The main case is the post-login sync
  /// restoring the server-side history after the profile page has loaded.
  static final ValueNotifier<int> historyRevision = ValueNotifier(0);

  static void _notifyHistoryChanged() => historyRevision.value++;

  static Future<B12ReminderSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);

    if (settingsJson != null) {
      try {
        return B12ReminderSettings.fromJson(json.decode(settingsJson));
      } catch (e) {
        return B12ReminderSettings();
      }
    }

    return B12ReminderSettings();
  }

  static Future<void> saveSettings(B12ReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, json.encode(settings.toJson()));
    // Streak/next-intake estimates depend on frequency: make UI recompute.
    _notifyHistoryChanged();
  }

  /// Adopts [frequency] as the reminder frequency when no settings were ever
  /// saved on this device, so estimates follow the rhythm the history was
  /// recorded under instead of the daily default. [lastIntake] anchors the
  /// day of week for weekly/biweekly rhythms. Reminders themselves stay
  /// disabled — only the rhythm is adopted.
  static Future<void> adoptFrequencyIfUnset(
      ReminderFrequency frequency, DateTime lastIntake) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_settingsKey) != null) return;
    await saveSettings(B12ReminderSettings(
      frequency: frequency,
      dayOfWeek: lastIntake.weekday,
    ));
  }

  static Future<void> scheduleReminder(B12ReminderSettings settings) async {
    await cancelReminder();

    if (!settings.enabled) {
      await saveSettings(settings);
      return;
    }

    // "enabled" must persist even without OS notification permission —
    // permission only gates whether we can actually schedule it.
    final hasPermission = await _notificationService.requestPermissions();
    if (hasPermission) {
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
    }

    // Save the settings regardless of whether scheduling succeeded.
    await saveSettings(settings);
  }

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
    final skipToday = await _isTakenOnDay(now);

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
      if (todayScheduledTime.isBefore(now) || skipToday) {
        daysUntilTarget = 7;
      }
    }

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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'b12_next_notification_date',
      candidateDate.millisecondsSinceEpoch,
    );
  }

  /// Marks a notification as received (biweekly tracking).
  static Future<void> markNotificationReceived() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'b12_last_notification_date',
      DateTime.now().millisecondsSinceEpoch,
    );

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

  static Future<void> cancelReminder() async {
    await _notificationService.cancelNotification(_notificationId);
    await _notificationService.cancelNotification(_biweeklyNotificationId);
  }

  /// Get next scheduled notification time. If today's dose was already
  /// taken, today's slot (even if its time-of-day hasn't passed yet) is
  /// skipped in favor of the next one — otherwise a same-day reminder would
  /// keep reading as "due today" right after the user just took it.
  static Future<DateTime?> getNextNotificationTime() async {
    final settings = await getSettings();

    if (!settings.enabled) {
      return null;
    }

    final now = DateTime.now();
    final skipToday = await _isTakenOnDay(now);

    switch (settings.frequency) {
      case ReminderFrequency.daily:
        var nextTime = DateTime(
          now.year,
          now.month,
          now.day,
          settings.hour,
          settings.minute,
        );

        if (nextTime.isBefore(now) || skipToday) {
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
          if (todayScheduledTime.isBefore(now) || skipToday) {
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
            if (todayTime.isBefore(now) || skipToday) {
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
        final prefs = await SharedPreferences.getInstance();
        final nextDateMillis = prefs.getInt('b12_next_notification_date');

        if (nextDateMillis != null) {
          try {
            final saved = DateTime.fromMillisecondsSinceEpoch(nextDateMillis);
            if (saved.isAfter(now) && !(skipToday && _isSameDay(saved, now))) {
              return saved;
            }
            // ignore: empty_catches
          } catch (e) {}
        }

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
          if (todayScheduledTime.isBefore(now) || skipToday) {
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

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Whether an intake was recorded for [day]'s calendar date.
  static Future<bool> _isTakenOnDay(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final intakes = await _loadIntakes(prefs);
    final key = _dayFormat.format(DateTime(day.year, day.month, day.day));
    return intakes.any((intake) => _dayFormat.format(intake.date) == key);
  }

  /// Intakes are stored as JSON entries `{"date": "yyyy-MM-dd",
  /// "frequency": "biweekly"}`. The date is a calendar day (not an epoch
  /// timestamp) so it can't shift, get re-uploaded, or get duplicated by
  /// sync when the device changes timezone.
  static final DateFormat _dayFormat = DateFormat('yyyy-MM-dd');

  /// Loads the intake history, migrating legacy entries in place: epoch-millis
  /// (pre-sync format) and bare `yyyy-MM-dd` strings (pre-frequency format).
  /// Legacy entries get a null frequency until sync backfills it.
  static Future<List<B12Intake>> _loadIntakes(SharedPreferences prefs) async {
    final raw = prefs.getStringList(_intakeHistoryKey) ?? [];
    var migrated = false;
    final byDay = <String, B12Intake>{};
    for (final entry in raw) {
      String? day;
      String? frequency;
      if (entry.startsWith('{')) {
        try {
          final decoded = json.decode(entry) as Map<String, dynamic>;
          day = decoded['date'] as String?;
          frequency = decoded['frequency'] as String?;
        } catch (e) {
          migrated = true; // drop the unreadable entry
          continue;
        }
      } else if (entry.contains('-')) {
        migrated = true;
        day = entry;
      } else {
        migrated = true;
        final millis = int.tryParse(entry);
        if (millis == null) continue;
        day = _dayFormat.format(DateTime.fromMillisecondsSinceEpoch(millis));
      }
      final date = day == null ? null : DateTime.tryParse(day);
      if (date == null) continue;
      _putIntake(byDay, B12Intake(date: date, frequency: frequency));
    }
    final intakes = byDay.values.toList();
    if (migrated) await _saveIntakes(prefs, intakes);
    return intakes;
  }

  /// Index an intake by its day, preferring an entry that knows its
  /// frequency when the same day appears twice.
  static void _putIntake(Map<String, B12Intake> byDay, B12Intake intake) {
    final key = _dayFormat.format(intake.date);
    final existing = byDay[key];
    if (existing == null ||
        (existing.frequency == null && intake.frequency != null)) {
      byDay[key] = intake;
    }
  }

  static Future<void> _saveIntakes(
      SharedPreferences prefs, List<B12Intake> intakes) async {
    await prefs.setStringList(
      _intakeHistoryKey,
      intakes
          .map((intake) => json.encode({
                'date': _dayFormat.format(intake.date),
                'frequency': intake.frequency,
              }))
          .toList(),
    );
  }

  /// Record a B12 intake for today, snapshotting the frequency currently
  /// in effect: the streak judges each intake against the rhythm it was
  /// taken under, and the server needs it to score intakes fairly.
  static Future<void> recordB12Intake() async {
    final prefs = await SharedPreferences.getInstance();
    final intakes = await _loadIntakes(prefs);

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final todayKey = _dayFormat.format(todayDate);

    if (intakes.any((intake) => _dayFormat.format(intake.date) == todayKey)) {
      return;
    }

    final settings = await getSettings();
    intakes.add(B12Intake(
      date: todayDate,
      frequency: reminderFrequencyToApi(settings.frequency),
    ));
    await _saveIntakes(prefs, intakes);
    _notifyHistoryChanged();

    // Biweekly's OS notification is a one-off tied to a tracked "next date"
    // (unlike the other frequencies' OS-repeating triggers), so push it out
    // to the next occurrence if today was the scheduled date.
    if (settings.enabled && settings.frequency == ReminderFrequency.biweekly) {
      await scheduleReminder(settings);
    }

    // Mirror the intake to the API (offline-safe, queued)
    unawaited(B12SyncService.onIntakeRecorded(todayDate, settings.frequency));
  }

  /// Replace the whole local history. Used when the device's history was
  /// recorded under another account and must be swapped for the current
  /// account's server-side history.
  static Future<void> replaceIntakeHistory(List<B12Intake> intakes) async {
    final prefs = await SharedPreferences.getInstance();
    final byDay = <String, B12Intake>{};
    for (final intake in intakes) {
      _putIntake(byDay, intake);
    }
    await _saveIntakes(prefs, byDay.values.toList());
    _notifyHistoryChanged();
  }

  /// Merge intakes into the local history (union, never removes days).
  /// Used to restore the server-side history on a new device or after a
  /// reinstall; also backfills the frequency of local days that predate
  /// frequency tracking. Returns the number of days actually added.
  static Future<int> mergeIntakeHistory(List<B12Intake> incoming) async {
    final prefs = await SharedPreferences.getInstance();
    final intakes = await _loadIntakes(prefs);
    final byDay = <String, B12Intake>{
      for (final intake in intakes) _dayFormat.format(intake.date): intake,
    };

    var added = 0;
    var backfilled = false;
    for (final intake in incoming) {
      final key = _dayFormat.format(intake.date);
      final existing = byDay[key];
      if (existing == null) {
        byDay[key] = intake;
        added++;
      } else if (existing.frequency == null && intake.frequency != null) {
        byDay[key] = intake;
        backfilled = true;
      }
    }
    if (added > 0 || backfilled) {
      await _saveIntakes(prefs, byDay.values.toList());
      _notifyHistoryChanged();
    }
    return added;
  }

  /// Get the B12 intakes, sorted descending (most recent first).
  /// Dates are local-midnight [DateTime]s.
  static Future<List<B12Intake>> getB12Intakes() async {
    final prefs = await SharedPreferences.getInstance();
    final intakes = await _loadIntakes(prefs);
    intakes.sort((a, b) => b.date.compareTo(a.date));
    return intakes;
  }

  /// Get the B12 intake days, sorted descending (most recent first).
  static Future<List<DateTime>> getB12IntakeHistory() async {
    final intakes = await getB12Intakes();
    return intakes.map((intake) => intake.date).toList();
  }

  /// Current streak: days covered by the unbroken chain of on-schedule
  /// intakes through today. Counting days (not intakes) keeps it fair across
  /// rhythms — a week on schedule is worth 7 whether daily or weekly.
  ///
  /// Each intake allows a gap based on the frequency in effect when it was
  /// recorded, so a history mixing rhythms is scored the way it was lived.
  /// Intakes with no snapshot fall back to the configured frequency.
  static Future<int> getB12Streak() async {
    final intakes = await getB12Intakes();
    if (intakes.isEmpty) return 0;

    final settings = await getSettings();
    int maxGapAfter(B12Intake intake) => _maxGapDaysForFrequency(
        reminderFrequencyFromApi(intake.frequency) ?? settings.frequency);

    final today = DateTime.now();

    // Streak is broken if the latest intake is already overdue
    if (calendarDaysBetween(intakes.first.date, today) >
        maxGapAfter(intakes.first)) {
      return 0;
    }

    DateTime chainStart = intakes.first.date;
    for (int i = 0; i < intakes.length - 1; i++) {
      final older = intakes[i + 1];
      if (calendarDaysBetween(older.date, intakes[i].date) <=
          maxGapAfter(older)) {
        chainStart = older.date;
      } else {
        break;
      }
    }
    final days = calendarDaysBetween(chainStart, today) + 1;
    // A clock/timezone change can leave the latest intake in the future;
    // a non-empty, non-overdue history is a streak of at least 1.
    return days < 1 ? 1 : days;
  }

  /// Signed count of calendar days from [from] to [to]. Local
  /// `difference().inDays` is one hour short across a DST spring-forward;
  /// diffing as UTC keeps every day exactly 24h.
  static int calendarDaysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays;

  /// "aujourd'hui" / "demain" / the weekday otherwise — the relative-day
  /// phrasing shared by every screen that shows a B12 reminder date
  /// (Paramètres, l'historique, la configuration).
  static String relativeDayLabel(DateTime date) {
    final inDays = calendarDaysBetween(DateTime.now(), date);
    if (inDays <= 0) return 'aujourd\'hui';
    if (inDays == 1) return 'demain';
    return DateFormat('EEEE d MMMM', 'fr_FR').format(date);
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

  /// Whether [day] was an expected intake day under [settings] — lets the
  /// history calendar tell a genuinely missed day from one the rhythm never
  /// required. Always false when reminders were never enabled.
  ///
  /// Frequency isn't tracked historically (only per-intake — see
  /// [B12Intake.frequency]), so this projects the *current* settings back
  /// across the calendar, same as the streak calculation's fallback.
  static bool isDueDay(DateTime day, B12ReminderSettings settings) {
    if (!settings.enabled) return false;
    switch (settings.frequency) {
      case ReminderFrequency.daily:
        return true;
      case ReminderFrequency.weekly:
        return settings.dayOfWeek != null && day.weekday == settings.dayOfWeek;
      case ReminderFrequency.twiceWeekly:
        return settings.daysOfWeek?.contains(day.weekday) ?? false;
      case ReminderFrequency.biweekly:
        if (settings.dayOfWeek == null || day.weekday != settings.dayOfWeek) {
          return false;
        }
        final start = settings.biweeklyStartDate;
        if (start == null) return true;
        final startDay = DateTime(start.year, start.month, start.day);
        final dayOnly = DateTime(day.year, day.month, day.day);
        final weeksDiff = calendarDaysBetween(startDay, dayOnly) ~/ 7;
        return weeksDiff % 2 == 0;
    }
  }
}
