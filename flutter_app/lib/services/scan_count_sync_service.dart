import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../helpers/preference_helper.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Keeps the server-side user scan counter (`/users/me/scans`) in sync with
/// the local scan count.
///
/// The local count ([PreferencesHelper.incrementTotalScanCount]) stays the
/// source of truth for the UI; this service mirrors it to the API:
///  - on first login the server counter is seeded from the local total
///    (PUT /users/me/scans) so users who scanned before having an account
///    don't restart at zero — the server only applies the seed while its
///    counter is still 0, so an existing account is never overwritten;
///  - each scan made while logged in is added to a persistent "unsynced"
///    counter which is flushed as a single batched increment
///    (POST /users/me/scans {count: n}). Scans made offline (bad connection
///    in a shop) simply accumulate and are sent on the next [sync] trigger:
///    app start, app resume, connectivity regained, or the next scan.
class ScanCountSyncService {
  static const String _unsyncedCountKey = 'scan_count_unsynced';
  static const String _initializedKeyPrefix = 'scan_count_initialized_user_';

  /// The API rejects increments above this in a single request.
  static const int _maxIncrementPerRequest = 10000;

  static bool _isSyncing = false;

  /// Record one scan for the server counter. Call after the local total has
  /// been incremented. No-op when logged out: pre-account scans reach the
  /// server through the seeding done on first login.
  static Future<void> onScanRecorded() async {
    if (!AuthService.isLoggedIn) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _unsyncedCountKey, (prefs.getInt(_unsyncedCountKey) ?? 0) + 1);
    } catch (e) {
      debugPrint('Failed to queue scan count increment: $e');
      return;
    }
    unawaited(sync());
  }

  /// Push local scan-count state to the server: seed the counter once per
  /// user, then flush any unsynced increments. Safe to call opportunistically
  /// (app start, connectivity regained, after a scan): it serializes itself
  /// and does nothing when there is nothing to send.
  static Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final user = AuthService.currentUser;
      if (user == null) return;

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) return;

      final prefs = await SharedPreferences.getInstance();

      if (!(prefs.getBool('$_initializedKeyPrefix${user.id}') ?? false)) {
        final initialized = await _initializeServerCount(prefs, user.id);
        // Increments must never reach the server before the seed: they would
        // make the counter non-zero and the seed would never apply. So on
        // failure, skip the flush too and retry both on the next trigger.
        if (!initialized) return;
      }

      await _flushUnsynced(prefs);
    } catch (e) {
      debugPrint('Scan count sync failed (will retry): $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Seed the server counter from the local total, once per user on this
  /// device. Returns false when the request failed.
  static Future<bool> _initializeServerCount(
      SharedPreferences prefs, int userId) async {
    // Snapshot before the request: scans recorded while it is in flight are
    // not part of the total being sent and must stay queued.
    final unsyncedBefore = prefs.getInt(_unsyncedCountKey) ?? 0;
    final localTotal = await PreferencesHelper.getTotalScanCount();

    final serverCount =
        await ApiService.initializeUserScanCount(count: localTotal);
    if (serverCount == null) return false;

    await prefs.setBool('$_initializedKeyPrefix$userId', true);

    // If the server accepted the seed, the currently unsynced scans are
    // already included in the local total we just sent — drop them so the
    // flush doesn't double-count them.
    if (serverCount == localTotal && unsyncedBefore > 0) {
      final remaining = (prefs.getInt(_unsyncedCountKey) ?? 0) - unsyncedBefore;
      await prefs.setInt(_unsyncedCountKey, remaining < 0 ? 0 : remaining);
    }
    return true;
  }

  /// Send the accumulated unsynced scans as one batched increment.
  static Future<void> _flushUnsynced(SharedPreferences prefs) async {
    final pending = prefs.getInt(_unsyncedCountKey) ?? 0;
    if (pending <= 0) return;

    final toSend =
        pending > _maxIncrementPerRequest ? _maxIncrementPerRequest : pending;
    final newCount = await ApiService.incrementUserScanCount(count: toSend);
    if (newCount == null) return; // keep the counter, retry on next trigger

    // Subtract what was sent rather than resetting: scans recorded while the
    // request was in flight stay queued for the next flush.
    final remaining = (prefs.getInt(_unsyncedCountKey) ?? 0) - toSend;
    await prefs.setInt(_unsyncedCountKey, remaining < 0 ? 0 : remaining);
    debugPrint('📤 Synced $toSend scan(s) to user counter (total $newCount)');
  }

  /// Forget queued increments. Called on explicit logout/account deletion so
  /// pending scans are not attributed to the next account that logs in on
  /// this device. The local total itself is kept.
  static Future<void> clearUnsynced() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_unsyncedCountKey);
    } catch (e) {
      debugPrint('Failed to clear unsynced scan count: $e');
    }
  }
}
