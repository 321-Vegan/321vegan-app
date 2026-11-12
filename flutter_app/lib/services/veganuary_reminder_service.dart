import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../helpers/preference_helper.dart';
import '../models/veganuary/veganuary_progress.dart';
import 'notification_service.dart';
import 'veganuary_service.dart';

/// Veganuary daily reminder, opt-in (offered at the end of day 1): at 10h,
/// "votre jour N vous attend", unless the user already opened that day's
/// Veganuary before.
///
/// One-shot notifications planned a week ahead and planned again on every
/// change (a day opened or done, app start), since a repeating one couldn't
/// skip a day. Back in the app at least once a week, the user keeps getting
/// them; gone for longer, they stop.
class VeganuaryReminderService {
  VeganuaryReminderService._();

  /// 3000 to 3006, one per planned morning.
  static const int _firstNotificationId = 3000;

  /// After the planned ones, so they don't cancel it.
  static const int _testNotificationId = 3099;
  static const int _daysAhead = 7;
  static const int _hour = 10;

  /// Absent: never asked.
  static const String _enabledKey = 'veganuary_reminders_enabled';

  /// Last day (yyyy-mm-dd) a day not done yet was opened.
  static const String _lastOpenedKey = 'veganuary_last_opened';

  static final NotificationService _notificationService = NotificationService();

  /// Null if the user was never asked.
  static Future<bool?> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey);
  }

  /// Asks the OS permission (call it from a user action). False if refused:
  /// the reminder then stays off.
  static Future<bool> enable() async {
    await PreferencesHelper.markNotificationPermissionAsked();
    final granted = await _notificationService.requestPermissions();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, granted);
    await reschedule();
    return granted;
  }

  /// Also for "Non merci": the offer isn't made again.
  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await _cancelAll();
  }

  /// Debug: as if never asked (with the progress reset, so day 1 offers
  /// it again).
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_enabledKey);
    await prefs.remove(_lastOpenedKey);
    await _cancelAll();
  }

  /// A day not done yet was opened: no reminder this morning anymore.
  static Future<void> markDayOpened() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastOpenedKey,
        VeganuaryProgress.dateOnly(DateTime.now()).toIso8601String());
    await reschedule();
  }

  /// Plans the next mornings again from the progress (silent: never asks
  /// for the permission).
  static Future<void> reschedule() async {
    try {
      await _cancelAll();
      if (await isEnabled() != true) return;
      if (!await _notificationService.areNotificationsEnabled()) return;

      final prefs = await SharedPreferences.getInstance();
      final lastOpened = prefs.getString(_lastOpenedKey);
      final progress = await VeganuaryService.loadProgress();
      final dates = plannedDates(
        progress,
        lastOpened: lastOpened == null ? null : DateTime.parse(lastOpened),
        now: DateTime.now(),
      );
      for (int i = 0; i < dates.length; i++) {
        final date = dates[i];
        await _schedule(
          id: _firstNotificationId + i,
          day: progress.nextDay,
          date: tz.TZDateTime(
              tz.local, date.year, date.month, date.day, date.hour),
        );
      }
    } catch (e) {
      debugPrint('VeganuaryReminderService: reschedule failed: $e');
    }
  }

  /// Debug: the reminder in a few seconds, to see it (and tap it) without
  /// waiting until 10h — a simulator's clock can't be changed.
  static Future<void> showTestSoon() async {
    await _notificationService.requestPermissions();
    final progress = await VeganuaryService.loadProgress();
    await _schedule(
      id: _testNotificationId,
      day: progress.nextDay,
      date: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
    );
  }

  static Future<void> _schedule({
    required int id,
    required int day,
    required tz.TZDateTime date,
  }) {
    return _notificationService.scheduleVeganuaryReminder(
      id: id,
      title: 'Veganuary : jour $day',
      body: 'Votre jour $day vous attend : une info et une idée reçue '
          'à démonter.',
      scheduledDate: date,
    );
  }

  /// The mornings (10h) to remind on, from [now]: from the day the next
  /// day opens (today when it's open already), but not today once a day
  /// was opened today. None before day 1 is done (the reminder is offered
  /// at its end), nor once the course is over.
  @visibleForTesting
  static List<DateTime> plannedDates(
    VeganuaryProgress progress, {
    DateTime? lastOpened,
    required DateTime now,
  }) {
    final day = progress.nextDay;
    if (day == 1 || day > VeganuaryService.totalDays) return [];
    final today = VeganuaryProgress.dateOnly(now);
    final unlock = progress.unlockDate(day);
    final first = unlock.isAfter(today) ? unlock : today;
    return [
      for (int i = 0; i < _daysAhead; i++)
        DateTime(first.year, first.month, first.day + i, _hour),
    ]
        .where((date) =>
            date.isAfter(now) &&
            !(VeganuaryProgress.dateOnly(date) == today && lastOpened == today))
        .toList();
  }

  static Future<void> _cancelAll() async {
    for (int i = 0; i < _daysAhead; i++) {
      await _notificationService.cancelNotification(_firstNotificationId + i);
    }
  }
}
