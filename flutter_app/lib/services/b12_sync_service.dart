import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/b12_intake.dart';
import '../models/b12_reminder_settings.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'b12_reminder_service.dart';

/// Mirrors locally recorded B12 intakes to the API (`/b12-intakes/`).
///
/// The local history ([B12ReminderService]) stays the source of truth for
/// the UI; this service pushes each intake day to the server so it can feed
/// the future XP system:
///  - each new intake is appended to a persistent queue flushed on the next
///    [sync] trigger: app start, login, or the next intake. Intakes
///    recorded offline simply stay queued until then;
///  - the first sync of a user after each app launch reconciles with the
///    server both ways: every local day the server is missing is queued,
///    and every server day missing locally (reinstall, other device) is
///    merged into the local history. This covers history recorded before
///    this app version existed and heals any day that ever slipped past
///    the queue.
///
/// Each queued entry snapshots the reminder frequency in effect when the
/// intake was recorded: B12 dosage schemes differ (daily, weekly, twice
/// weekly, biweekly), so a raw intake count is not comparable between users
/// and the server needs the rhythm to score intakes fairly.
class B12SyncService {
  static const String _pendingKey = 'b12_intakes_unsynced';

  /// Local intake history entries older than this user's first sync belong
  /// to whoever recorded them; the owner marker prevents attributing them
  /// to a different account that logs in later on this device.
  static const String _historyOwnerKey = 'b12_history_owner_user_id';

  /// Completes when the most recently requested sync pass has finished.
  static Future<void> _lastSync = Future.value();

  /// Users already reconciled since app launch. In memory on purpose:
  /// reconciliation is cheap (one GET, usually no diff), so re-running it
  /// once per launch keeps server and local histories converging without
  /// a persistent flag that could go stale.
  static final Set<int> _reconciledUsers = {};

  /// Queue one intake day for the server. Call after the local history has
  /// been updated. No-op when logged out: pre-account intakes reach the
  /// server through the history seeding done on the first sync after login.
  static Future<void> onIntakeRecorded(
      DateTime day, ReminderFrequency frequency) async {
    if (!AuthService.isLoggedIn) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await _enqueue(prefs, [day], frequency);
    } catch (e) {
      debugPrint('Failed to queue B12 intake: $e');
      return;
    }
    unawaited(sync());
  }

  /// Push queued intakes to the server, reconciling local and server
  /// histories on the first sync of a user since app launch. Safe to call
  /// opportunistically (app start, login, after an intake): concurrent
  /// calls are chained rather than dropped, so each caller's future only
  /// completes after a full pass covering everything queued before the
  /// call — logout relies on this before dropping the queue.
  static Future<void> sync() {
    final run = _lastSync.then((_) => _doSync());
    _lastSync = run;
    return run;
  }

  static Future<void> _doSync() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return;

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) return;

      final prefs = await SharedPreferences.getInstance();

      if (!_reconciledUsers.contains(user.id)) {
        if (await _reconcile(prefs, user.id)) {
          _reconciledUsers.add(user.id);
        }
      }

      await _flush(prefs);
    } catch (e) {
      debugPrint('B12 intake sync failed (will retry): $e');
    }
  }

  /// Two-way reconciliation with the server:
  ///  - locally recorded days the server doesn't have yet are queued for
  ///    upload (the current frequency setting is the best available
  ///    approximation for days recorded before syncing existed);
  ///  - server days missing locally are merged into the local history, so
  ///    it comes back automatically after a reinstall or on a new device.
  /// The upload direction only applies when the local history belongs to
  /// this user (or to nobody yet — pre-account history seeds the first
  /// account that logs in): a history recorded under another account is
  /// replaced by this account's server history instead of being uploaded.
  /// Returns false when the server history couldn't be fetched, so the
  /// caller retries on the next sync.
  static Future<bool> _reconcile(SharedPreferences prefs, int userId) async {
    final serverIntakes = await ApiService.getB12Intakes();
    if (serverIntakes == null) return false;

    // Adopt the server-side rhythm before anything below reads the local
    // settings: on a device where reminders were never configured, the
    // daily default would break weekly/biweekly streaks computed from the
    // restored history and mislabel the local days queued for upload.
    await _adoptServerFrequencyIfUnset(serverIntakes);

    final ownerId = prefs.getInt(_historyOwnerKey);
    if (ownerId != null && ownerId != userId) {
      // The device's history was recorded under another account. Adopt this
      // account's server history, keeping only the days queued since this
      // user logged in (their own intakes — the previous account's queue
      // was dropped at logout).
      final pendingIntakes = (prefs.getStringList(_pendingKey) ?? [])
          .map((e) => json.decode(e) as Map<String, dynamic>)
          .map((entry) {
        final date = DateTime.tryParse(entry['date'] as String? ?? '');
        return date == null
            ? null
            : B12Intake(date: date, frequency: entry['frequency'] as String?);
      }).whereType<B12Intake>();
      await B12ReminderService.replaceIntakeHistory(
          [...serverIntakes, ...pendingIntakes]);
      await prefs.setInt(_historyOwnerKey, userId);
      debugPrint('👤 B12 history belonged to another account — '
          'replaced with the server history');
      return true;
    }

    final serverSet = serverIntakes
        .map((intake) => DateFormat('yyyy-MM-dd').format(intake.date))
        .toSet();
    final localIntakes = await B12ReminderService.getB12Intakes();
    final missing = localIntakes
        .where((intake) =>
            !serverSet.contains(DateFormat('yyyy-MM-dd').format(intake.date)))
        .toList();

    if (missing.isNotEmpty) {
      // Upload each day with its own frequency snapshot when known; the
      // current setting approximates days recorded before frequency
      // tracking existed.
      final settings = await B12ReminderService.getSettings();
      for (final intake in missing) {
        await _enqueue(prefs, [intake.date],
            reminderFrequencyFromApi(intake.frequency) ?? settings.frequency);
      }
    }

    final restored =
        await B12ReminderService.mergeIntakeHistory(serverIntakes);
    if (restored > 0) {
      debugPrint('📥 Restored $restored B12 intake day(s) from server');
    }
    await prefs.setInt(_historyOwnerKey, userId);
    return true;
  }

  /// Hand the frequency snapshot of the most recent server intake to
  /// [B12ReminderService.adoptFrequencyIfUnset], so a device where
  /// reminders were never configured interprets the restored history with
  /// the rhythm it was recorded under instead of the daily default.
  static Future<void> _adoptServerFrequencyIfUnset(
      List<B12Intake> intakes) async {
    ReminderFrequency? frequency;
    DateTime? latest;
    for (final intake in intakes) {
      final parsed = reminderFrequencyFromApi(intake.frequency);
      if (parsed == null) continue;
      if (latest == null || intake.date.isAfter(latest)) {
        latest = intake.date;
        frequency = parsed;
      }
    }
    if (frequency != null) {
      await B12ReminderService.adoptFrequencyIfUnset(frequency, latest!);
    }
  }

  /// Forget queued intakes. Called on explicit logout/account deletion so
  /// pending intakes are not attributed to the next account that logs in on
  /// this device. The local history itself is kept.
  static Future<void> clearPending() async {
    // Re-reconcile on the next login even within this app session: intakes
    // recorded while logged out only reach the server through reconcile.
    _reconciledUsers.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingKey);
    } catch (e) {
      debugPrint('Failed to clear unsynced B12 intakes: $e');
    }
  }

  static Future<void> _enqueue(SharedPreferences prefs, List<DateTime> days,
      ReminderFrequency frequency) async {
    final pending = prefs.getStringList(_pendingKey) ?? [];
    final queuedDates = pending
        .map((e) => (json.decode(e) as Map<String, dynamic>)['date'])
        .toSet();

    var changed = false;
    for (final day in days) {
      final date = DateFormat('yyyy-MM-dd').format(day);
      if (queuedDates.contains(date)) continue;
      pending.add(json.encode({
        'date': date,
        'frequency': reminderFrequencyToApi(frequency),
      }));
      queuedDates.add(date);
      changed = true;
    }
    if (changed) await prefs.setStringList(_pendingKey, pending);
  }

  /// Rejections that a retry can never fix: invalid data or state (409 is
  /// the expected duplicate-day answer and means "already synced"). Anything
  /// else — 401/403 (expired session that the HTTP client couldn't refresh),
  /// 429 (rate limit), 5xx — is treated as transient and keeps the entry
  /// queued for the next sync, typically after the next login.
  static const Set<int> _dropStatuses = {400, 404, 409, 422};

  /// Send queued intakes one by one, dropping each on success or on a
  /// permanent rejection ([_dropStatuses]) so a poison entry can't block
  /// the queue. A transient failure aborts the flush and the remaining
  /// entries stay queued for the next trigger; so does a network error,
  /// via the throw caught in [sync].
  static Future<void> _flush(SharedPreferences prefs) async {
    final pending = prefs.getStringList(_pendingKey) ?? [];
    if (pending.isEmpty) return;

    for (final entry in pending) {
      final decoded = json.decode(entry) as Map<String, dynamic>;
      final status = await ApiService.postB12Intake(
        intakeDate: decoded['date'] as String,
        frequency: decoded['frequency'] as String?,
      );
      final synced = status >= 200 && status < 300;
      if (!synced && !_dropStatuses.contains(status)) return;

      // Re-read before removing: an intake queued while a request was in
      // flight must not be lost by writing back a stale list.
      final current = prefs.getStringList(_pendingKey) ?? [];
      current.remove(entry);
      await prefs.setStringList(_pendingKey, current);
      if (synced) {
        debugPrint('📤 Synced B12 intake of ${decoded['date']}');
      }
    }
  }

}
