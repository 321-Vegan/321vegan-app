import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'auth_service.dart';
import 'veganuary_service.dart';

/// Saves the Veganuary progress of a logged-in user on the API
/// (`/me/veganuary-days`), to get it back on another device or after a
/// reinstall. Like the B12 intakes (see B12SyncService), the progress
/// stored on the device stays the reference for the app:
///  - each day done is queued, then sent on the next [sync] (now, app
///    start, login, the Veganuary tab opened): offline, it just waits;
///  - the first sync of a user after each launch reconciles both ways:
///    the days the server doesn't have are queued, the server's days
///    missing here are added to the device's progress.
/// The progress follows whoever logs in: the course done before logging in,
/// or under another account on this device, is added to the account (the
/// same person changing accounts is likelier than two people doing the
/// course on one phone). Only the days done are saved, not a day left
/// halfway. Everything goes through one chain ([_chain]): a sync, then the
/// next, so they can't step on each other.
class VeganuarySyncService {
  VeganuarySyncService._();

  /// Day numbers still to send.
  static const String _pendingKey = 'veganuary_days_unsynced';

  /// Id of the user whose days are still to forget on the server after a
  /// reset (see [reset]).
  static const String _pendingResetKey = 'veganuary_reset_unsynced';

  static Future<bool> _lastSync = Future.value(false);

  /// Users reconciled since launch (in memory: once per launch is enough,
  /// and keeps both sides converging).
  static final Set<int> _reconciledUsers = {};

  /// Call once [day] is saved as done on the device.
  static Future<void> onDayCompleted(int day) async {
    if (!AuthService.isLoggedIn) return;
    await _enqueue(await SharedPreferences.getInstance(), [day]);
    unawaited(sync());
  }

  /// Debug: the dates moved on the device ([days] all done): sent again.
  static Future<void> onDatesChanged(Iterable<int> days) async {
    if (!AuthService.isLoggedIn) return;
    await _enqueue(await SharedPreferences.getInstance(), days.toList());
    unawaited(sync());
  }

  /// Sends what's queued, reconciling first if not done since launch. True
  /// when the device's progress changed (days got back from the server):
  /// the path then reloads it.
  static Future<bool> sync() => _chain(_doSync);

  /// Runs [task] once the ones before it are done.
  static Future<bool> _chain(Future<bool> Function() task) {
    final run = _lastSync.then((_) => task());
    _lastSync = run.catchError((_) => false);
    return run;
  }

  static Future<bool> _doSync() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return false;
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return false;
      final prefs = await SharedPreferences.getInstance();

      // A reset not sent yet first: the reconciliation would bring the
      // server's days back
      if (!await _sendReset(prefs, user.id)) return false;

      var changed = false;
      if (!_reconciledUsers.contains(user.id)) {
        final reconciled = await _reconcile(prefs);
        if (reconciled != null) {
          _reconciledUsers.add(user.id);
          changed = reconciled;
        }
      }
      await _flush(prefs);
      return changed;
    } catch (e) {
      debugPrint('Veganuary progress sync failed (will retry): $e');
      return false;
    }
  }

  /// Both ways, see the class; null when the server's days couldn't be
  /// fetched (tried again on the next sync), else whether the device's
  /// progress changed.
  static Future<bool?> _reconcile(SharedPreferences prefs) async {
    final serverDays = await ApiService.getVeganuaryDays();
    if (serverDays == null) return null;
    final days = {for (final d in serverDays) d.day: d.completedOn};
    final myths = {
      for (final d in serverDays)
        if (d.mythId != null) d.day: d.mythId!,
    };

    // Done here and not on the server (offline, before logging in, or
    // under another account), or done earlier here: sent
    final local = await VeganuaryService.loadProgress();
    await _enqueue(prefs, [
      for (final MapEntry(key: day, value: date) in local.completedAt.entries)
        if (days[day] == null || date.isBefore(days[day]!)) day,
    ]);
    // The other way, read and written at once: a day done meanwhile on the
    // day page isn't lost
    return VeganuaryService.mergeProgress(days, myths);
  }

  /// Answers a retry won't change: the day is dropped from the queue.
  static const Set<int> _dropStatuses = {400, 404, 422};

  /// Sends the queued days one by one; stops at the first failure that may
  /// pass (offline, session expired, server down), keeping the rest.
  static Future<void> _flush(SharedPreferences prefs) async {
    final progress = await VeganuaryService.loadProgress();
    for (final day in prefs.getStringList(_pendingKey) ?? const <String>[]) {
      final number = int.parse(day);
      final date = progress.completedAt[number];
      if (date != null) {
        final status = await ApiService.putVeganuaryDay(
          day: number,
          completedOn: DateFormat('yyyy-MM-dd').format(date),
          mythId: progress.pickedMyths[number],
        );
        final sent = status >= 200 && status < 300;
        if (!sent && !_dropStatuses.contains(status)) return;
      }
      // Read again: a day queued meanwhile mustn't be lost
      final current = prefs.getStringList(_pendingKey) ?? [];
      current.remove(day);
      await prefs.setStringList(_pendingKey, current);
    }
  }

  static Future<void> _enqueue(SharedPreferences prefs, List<int> days) async {
    final pending = prefs.getStringList(_pendingKey) ?? [];
    final added = {
      for (final day in days)
        if (!pending.contains('$day')) '$day',
    };
    if (added.isEmpty) return;
    await prefs.setStringList(_pendingKey, [...pending, ...added]);
  }

  /// On logout or account deletion: what wasn't sent isn't attributed to
  /// the next account logging in on this device. The device's progress is
  /// kept (and added to that account).
  static Future<void> clearPending() async {
    _reconciledUsers.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }

  /// Debug: the course started over. In the chain, after a sync in
  /// progress (which could otherwise send days again afterwards): the
  /// device's progress is cleared with [clearLocal], then the server's days
  /// are forgotten too; offline, at the next sync, before anything else.
  static Future<void> reset(Future<void> Function() clearLocal) =>
      _chain(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_pendingKey);
        await clearLocal();
        final user = AuthService.currentUser;
        if (user != null) {
          await prefs.setInt(_pendingResetKey, user.id);
          await _sendReset(prefs, user.id);
        }
        return false;
      });

  /// Sends a reset not sent yet (see [reset]); false when it couldn't be
  /// (offline): nothing else is sent until it is.
  static Future<bool> _sendReset(SharedPreferences prefs, int userId) async {
    final resetFor = prefs.getInt(_pendingResetKey);
    if (resetFor == null) return true;
    // Another account logged in since: not its days to forget
    if (resetFor == userId && !await ApiService.deleteVeganuaryDays()) {
      return false;
    }
    await prefs.remove(_pendingResetKey);
    return true;
  }
}
