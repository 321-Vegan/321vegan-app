import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Handle offline "interesting products" scan events with automatic retry
/// We need this in case the user scans a product while offline
///
/// Each queued event carries a locally-generated `id`, and queue entries are
/// removed/updated by id: index-based mutation is unsafe when a new scan and
/// a retry pass touch the queue concurrently.
class OfflineScanService {
  static const String _pendingScanEventsKey = 'pending_scan_events';

  /// Queue used by older app versions for events whose first POST failed.
  /// No code writes to it anymore; leftovers are migrated into the pending
  /// queue once (see [_loadPendingEvents]) and the key is deleted.
  static const String _legacyFailedScanEventsKey = 'failed_scan_events';

  /// A pending event is dropped after this many rejected post attempts so a
  /// permanently-rejected scan can't stay in the queue and retry forever.
  static const int _maxPendingRetries = 5;

  static final Random _random = Random();

  static String _newEventId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(0xFFFFFF)}';

  /// Load the pending queue, backfilling ids on events stored by older app
  /// versions and absorbing the legacy failed queue. Persists only when
  /// something actually changed.
  static Future<List<Map<String, dynamic>>> _loadPendingEvents(
      SharedPreferences prefs) async {
    final List<String> stored = prefs.getStringList(_pendingScanEventsKey) ?? [];
    final events = <Map<String, dynamic>>[];
    bool changed = false;

    for (final raw in stored) {
      try {
        final event = json.decode(raw) as Map<String, dynamic>;
        if (event['id'] == null) {
          event['id'] = _newEventId();
          changed = true;
        }
        events.add(event);
      } catch (e) {
        debugPrint('Dropping unreadable pending scan event: $e');
        changed = true;
      }
    }

    // One-time migration of the legacy failed queue: those events were real
    // scans that never made it to the server, so give them another chance —
    // except ones that had already exhausted their 3 legacy retries.
    if (prefs.containsKey(_legacyFailedScanEventsKey)) {
      final List<String> legacy =
          prefs.getStringList(_legacyFailedScanEventsKey) ?? [];
      for (final raw in legacy) {
        try {
          final event = json.decode(raw) as Map<String, dynamic>;
          if (((event['retry_count'] as int?) ?? 0) >= 3) continue;
          event['id'] = _newEventId();
          event.remove('scan_event_id');
          events.add(event);
        } catch (_) {}
      }
      await prefs.remove(_legacyFailedScanEventsKey);
      changed = true;
    }

    if (changed) {
      await _savePendingEvents(prefs, events);
    }
    return events;
  }

  static Future<void> _savePendingEvents(
      SharedPreferences prefs, List<Map<String, dynamic>> events) async {
    await prefs.setStringList(
      _pendingScanEventsKey,
      events.map(json.encode).toList(),
    );
  }

  /// Save a pending scan event to local storage.
  /// Returns the stored event (including its generated id), or null if
  /// persisting failed.
  static Future<Map<String, dynamic>?> savePendingScanEvent({
    required String ean,
    double? latitude,
    double? longitude,
    int? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final events = await _loadPendingEvents(prefs);

      final scanEvent = {
        'id': _newEventId(),
        'ean': ean,
        'latitude': latitude,
        'longitude': longitude,
        'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'retry_count': 0,
      };

      events.add(scanEvent);
      await _savePendingEvents(prefs, events);
      return scanEvent;
    } catch (e) {
      debugPrint('Failed to save pending scan event: $e');
      return null;
    }
  }

  /// Get all pending scan events
  static Future<List<Map<String, dynamic>>> getPendingScanEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await _loadPendingEvents(prefs);
    } catch (e) {
      debugPrint('Failed to get pending scan events: $e');
      return [];
    }
  }

  /// Remove a pending scan event by its id
  static Future<void> removePendingScanEvent(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final events = await _loadPendingEvents(prefs);
      events.removeWhere((event) => event['id'] == id);
      await _savePendingEvents(prefs, events);
    } catch (e) {
      debugPrint('Failed to remove pending scan event: $e');
    }
  }

  /// Increment the retry counter on the pending event with [id], persisting
  /// the change. Once it reaches [_maxPendingRetries] the event is removed.
  static Future<void> _bumpPendingRetryOrDrop(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final events = await _loadPendingEvents(prefs);
      final index = events.indexWhere((event) => event['id'] == id);
      if (index == -1) return;

      final event = events[index];
      final retryCount = ((event['retry_count'] as int?) ?? 0) + 1;
      if (retryCount >= _maxPendingRetries) {
        events.removeAt(index);
        debugPrint('Dropping pending scan event after $_maxPendingRetries '
            'rejected attempts: ${event['ean']}');
      } else {
        event['retry_count'] = retryCount;
      }
      await _savePendingEvents(prefs, events);
    } catch (e) {
      debugPrint('Failed to bump pending scan event retry: $e');
    }
  }

  /// Post a scan event with offline support
  /// Returns a tuple: (success, response, shouldShowDialog)
  static Future<(bool, Map<String, dynamic>?, bool)>
      postScanEventWithOfflineSupport({
    required String ean,
    double? latitude,
    double? longitude,
    int? userId,
  }) async {
    // First, save to local storage as a pending event
    final scanEvent = await savePendingScanEvent(
      ean: ean,
      latitude: latitude,
      longitude: longitude,
      userId: userId,
    );

    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    final hasConnection = !connectivityResult.contains(ConnectivityResult.none);

    if (!hasConnection) {
      return (false, null, false);
    }

    // Try to post to API
    try {
      final response = await ApiService.postScanEvent(
        ean: ean,
        latitude: latitude,
        longitude: longitude,
        userId: userId,
      );

      if (response != null) {
        // Success! Remove from pending
        final id = scanEvent?['id'] as String?;
        if (id != null) {
          await removePendingScanEvent(id);
        }
        return (true, response, true);
      } else {
        // Server responded but rejected the request (non-2xx). Count the
        // attempt so a permanently-rejected scan is eventually dropped by
        // retryPendingScans instead of being retried forever.
        final id = scanEvent?['id'] as String?;
        if (id != null) {
          await _bumpPendingRetryOrDrop(id);
        }
        return (false, null, false);
      }
    } catch (e) {
      // Network/connection error — no response from the server. The pending
      // event already covers retry, so leave it untouched (and don't count
      // the attempt: bad connectivity must never drop valid scans).
      return (false, null, false);
    }
  }

  /// Retry all pending scan events
  /// Returns a tuple: (successCount, List of events that need shop confirmation)
  /// Each shop confirmation event contains: {ean, shop_name, scan_event_id}
  static Future<(int, List<Map<String, dynamic>>)> retryPendingScans() async {
    int successCount = 0;
    List<Map<String, dynamic>> shopConfirmationsNeeded = [];

    // Check connectivity first
    final connectivityResult = await Connectivity().checkConnectivity();
    final hasConnection = !connectivityResult.contains(ConnectivityResult.none);

    if (!hasConnection) {
      return (0, <Map<String, dynamic>>[]);
    }

    final pendingEvents = await getPendingScanEvents();
    for (final event in pendingEvents) {
      final id = event['id'] as String;
      try {
        final response = await ApiService.postScanEvent(
          ean: event['ean'],
          latitude: event['latitude'],
          longitude: event['longitude'],
          // The user who scanned, captured at scan time. Falls back to the
          // currently logged-in user for events queued while logged out.
          userId: (event['user_id'] as int?) ?? AuthService.currentUser?.id,
        );

        if (response != null) {
          await removePendingScanEvent(id);
          successCount++;

          // Check if shop confirmation is needed
          final shopName = response['shop_name'] as String?;
          final scanEventId = response['id'] as int?;
          if (shopName != null && scanEventId != null) {
            shopConfirmationsNeeded.add({
              'ean': event['ean'],
              'shop_name': shopName,
              'scan_event_id': scanEventId,
              'nearby_shops': response['nearby_shops'],
              'shop_id': response['shop_id'],
            });
          }
        } else {
          // Server responded but rejected the request (non-2xx). Count the
          // attempt and drop the event once it has exhausted its retries so a
          // permanently-rejected scan doesn't stay in the queue forever.
          await _bumpPendingRetryOrDrop(id);
        }
      } catch (e) {
        // Network/connection error — no response from the server (offline,
        // captive portal, dead zone). Leave the event untouched WITHOUT
        // counting it against the cap, and stop the pass: the connection is
        // gone, so the remaining events would each just burn a timeout.
        debugPrint('Network error retrying pending scan (will retry): $e');
        break;
      }
    }

    if (successCount > 0) {
      debugPrint('📤 Successfully synced $successCount scan event(s)');
    }

    return (successCount, shopConfirmationsNeeded);
  }

  /// Get count of pending events
  static Future<int> getPendingCount() async {
    final pending = await getPendingScanEvents();
    return pending.length;
  }
}
