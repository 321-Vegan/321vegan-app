import 'package:timezone/timezone.dart' as tz;
import '../helpers/preference_helper.dart';
import 'notification_service.dart';

/// Schedules a yearly notification celebrating the user's vegan anniversary,
/// based on the date they started being vegan ([PreferencesHelper.getSelectedDateFromPrefs]).
class AnniversaryService {
  static const int _notificationId = 2000;

  /// Hour of the day (local time) at which the anniversary notification fires.
  static const int _hour = 13;
  static const int _minute = 50;

  static final NotificationService _notificationService = NotificationService();

  /// (Re)schedule the anniversary notification for the given vegan start date.
  /// Requests notification permission — call this from a user-initiated moment
  /// (e.g. when the user sets or changes their vegan start date).
  static Future<void> scheduleAnniversary(DateTime veganSince) async {
    // Record that we've prompted for notification permission, so the one-time
    // startup prompt (see home page) doesn't ask again redundantly.
    await PreferencesHelper.markNotificationPermissionAsked();

    final hasPermission = await _notificationService.requestPermissions();
    if (!hasPermission) return;

    // Explicit date change, so always (re)schedule to pick up the new date.
    await _schedule(veganSince);
  }

  /// Reschedule silently at app startup, if a vegan date exists and
  /// notifications are enabled. Same id → cheap, idempotent overwrite.
  static Future<void> rescheduleIfNeeded() async {
    final veganSince = await PreferencesHelper.getSelectedDateFromPrefs();
    if (veganSince == null) return;

    final enabled = await _notificationService.areNotificationsEnabled();
    if (!enabled) return;

    await _schedule(veganSince);
  }

  /// Cancel the scheduled anniversary notification (e.g. when the user removes
  /// their vegan start date).
  static Future<void> cancel() async {
    await _notificationService.cancelNotification(_notificationId);
  }

  /// (Re)schedule the yearly anniversary notification. Uses a fixed id, so this
  /// overwrites any existing schedule without an explicit cancel.
  ///
  /// The yearly OS trigger matches month/day/time but not the year, so a
  /// registration made on the start day would fire that same day. We skip
  /// scheduling when the start date is today; the next launch's
  /// [rescheduleIfNeeded] sets up the real one-year-later anniversary.
  static Future<void> _schedule(DateTime veganSince) async {
    final now = tz.TZDateTime.now(tz.local);
    if (now.year == veganSince.year &&
        now.month == veganSince.month &&
        now.day == veganSince.day) {
      // Clear any prior schedule so no stale notification remains.
      await cancel();
      return;
    }

    await _notificationService.scheduleAnnualNotification(
      id: _notificationId,
      title: '💚 Joyeux véganniversaire !',
      body: 'Une nouvelle année végane à célébrer',
      scheduledDate: _nextAnniversary(veganSince),
      payload: 'vegan_anniversary',
    );
  }

  /// Whole vegan years between [veganSince] and [now]. Counts from the y/m/d
  /// fields, not `inDays ~/ 365`, so leap years and time-of-day don't skew it.
  ///
  /// Mirrors [_anniversaryFor]: a Feb 29 start is celebrated on Feb 28 in
  /// non-leap years, so the year count ticks over on Feb 28 those years too.
  static int veganYears(DateTime veganSince, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final lastDayOfMonth =
        DateTime(reference.year, veganSince.month + 1, 0).day;
    final anniversaryDay =
        veganSince.day < lastDayOfMonth ? veganSince.day : lastDayOfMonth;
    var years = reference.year - veganSince.year;
    if (reference.month < veganSince.month ||
        (reference.month == veganSince.month &&
            reference.day < anniversaryDay)) {
      years--;
    }
    return years;
  }

  /// Compute the next occurrence of the anniversary (month/day of [veganSince])
  /// at the configured time. If this year's date has already passed, returns
  /// next year's.
  static tz.TZDateTime _nextAnniversary(DateTime veganSince) {
    final now = tz.TZDateTime.now(tz.local);
    var date = _anniversaryFor(now.year, veganSince);
    if (!date.isAfter(now)) {
      date = _anniversaryFor(now.year + 1, veganSince);
    }
    return date;
  }

  /// Build the anniversary date in [year]. A Feb 29 start date is pinned to
  /// Feb 28 in non-leap years (rather than rolling over to March 1).
  static tz.TZDateTime _anniversaryFor(int year, DateTime veganSince) {
    final lastDayOfMonth = DateTime(year, veganSince.month + 1, 0).day;
    final day =
        veganSince.day < lastDayOfMonth ? veganSince.day : lastDayOfMonth;
    return tz.TZDateTime(tz.local, year, veganSince.month, day, _hour, _minute);
  }
}
