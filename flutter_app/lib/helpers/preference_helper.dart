import 'dart:convert'; // Import for JSON encoding/decoding
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_scores.dart';
import '../services/auth_service.dart';
import 'helper.dart';

/// Avatar assets available for selection (Paramètres > Avatar) and for the
/// "random avatar" roll below. Illustrations by @vilainevegane.illustration,
/// @kodasmarket.art and @ancielouille.
const List<String> kAvailableAvatars = [
  'lapin.png',
  'ver.png',
  'poisson.png',
  'canard.png',
  'poule.png',
  'mouton.png',
  'cochon.png',
  'vache.png',
  'chat.png',
];

class PreferencesHelper {
  // Internal method: saves date to local storage only (no backend update)
  // Used by AuthService to avoid circular backend calls during login sync
  static Future<void> saveSelectedDateToPrefsOnly(
      DateTime? selectedDate) async {
    final prefs = await SharedPreferences.getInstance();
    String? dateString;
    if (selectedDate == null) {
      dateString = "none";
    } else {
      dateString = selectedDate.toIso8601String();
    }
    await prefs.setString('selected_date', dateString);
  }

  // Method to add a selected date to shared preferences and update backend if logged in
  static Future<void> addSelectedDateToPrefs(DateTime? selectedDate) async {
    await saveSelectedDateToPrefsOnly(selectedDate);

    // If user is logged in, also update on the backend
    if (selectedDate != null && AuthService.isLoggedIn) {
      await AuthService.updateUser(veganSince: selectedDate);
    }
  }

  // Clears the vegan-since date locally and, if logged in, on the backend.
  static Future<void> removeSelectedDateFromPrefs() async {
    await saveSelectedDateToPrefsOnly(null);
    if (AuthService.isLoggedIn) {
      await AuthService.updateUser(clearVeganSince: true);
    }
  }

  // Method to get a selected date from shared preferences
  static Future<DateTime?> getSelectedDateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    String? dateString = prefs.getString('selected_date');
    if (dateString != null && dateString != "none") {
      // Older/synced entries may carry an incorrect UTC "Z" suffix from the
      // backend (see Helper's asLocalWallClock doc) — reinterpret rather
      // than .toLocal(), which would shift an already-local value again.
      return DateTime.parse(dateString).asLocalWallClock();
    }
    return null;
  }

  static Future<bool> isCodeInPreferences(String code) async {
    final prefs = await SharedPreferences.getInstance();
    String? codesJson = prefs.getString('codes_with_status');
    if (codesJson != null) {
      Map<String, bool> codesWithStatus =
          Map<String, bool>.from(json.decode(codesJson));
      bool containsCode = codesWithStatus.containsKey(code);
      return containsCode;
    }
    return false;
  }

  // Save 'show boycott' preference
  static Future<void> setShowBoycottPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_boycott', value);
  }

  // Load 'show boycott' preference
  static Future<bool> getShowBoycottPref() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('show_boycott') ??
        true; // Default to true to show boycott
  }

  // Save 'show scores' preference
  static Future<void> setShowScoresPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('product_scores_enabled', value);
  }

  // Load 'show scores' preference
  static Future<bool> getShowScoresPref() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('product_scores_enabled') ?? true;
  }

  // Save 'haptic feedback' preference
  static Future<void> setHapticFeedbackPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptic_feedback_enabled', value);
  }

  // Load 'haptic feedback' preference
  static Future<bool> getHapticFeedbackPref() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('haptic_feedback_enabled') ?? true;
  }

  // Method to add or remove a code based on success status
  static Future<void> addCodeToPreferences(String? code, bool success) async {
    if (code == null) return;

    final prefs = await SharedPreferences.getInstance();
    String? codesJson = prefs.getString('codes_with_status');

    // Decode the JSON string to a Map
    Map<String, bool> codesWithStatus =
        codesJson != null ? Map<String, bool>.from(json.decode(codesJson)) : {};

    if (!success && codesWithStatus[code] != true) {
      codesWithStatus[code] = false;
    } else if (success) {
      // If success is true, set the status to true
      codesWithStatus[code] = true;
    }

    // Track total successful submissions
    int totalSuccessful = 0;
    if (prefs.getInt('total_successful_submissions') == null) {
      totalSuccessful = await migrateTotalSuccessfulSubmissions();
    } else {
      totalSuccessful = prefs.getInt('total_successful_submissions') ?? 0;
    }
    if (success) {
      totalSuccessful++;
      await prefs.setInt('total_successful_submissions', totalSuccessful);
    }

    // Ensure the codes list contains a maximum of 300 items
    if (codesWithStatus.length > 300) {
      List<MapEntry<String, bool>> entries = codesWithStatus.entries.toList();
      // Remove the oldest entries (first in the list)
      entries.removeRange(0, entries.length - 300);
      codesWithStatus = Map.fromEntries(entries);
    }

    await prefs.setString('codes_with_status', json.encode(codesWithStatus));
  }

  // Method to get all codes with their status from shared preferences
  static Future<Map<String, bool>> getCodesWithStatusFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    String? codesJson = prefs.getString('codes_with_status');

    if (codesJson != null) {
      // Decode the JSON string back to a Map
      return Map<String, bool>.from(json.decode(codesJson));
    }
    return {};
  }

  /// Saves the name/brand the user typed when submitting a product, so the
  /// "Envoyés" page can show something better than "Nom inconnu" while the
  /// product hasn't been reviewed and added to the local database yet.
  static Future<void> saveSubmittedProductInfo({
    required String code,
    required String name,
    required String brand,
  }) async {
    if (name.isEmpty && brand.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('submitted_product_info');
    final info = raw != null
        ? Map<String, dynamic>.from(json.decode(raw))
        : <String, dynamic>{};

    info[code] = {'name': name, 'brand': brand};

    // Same cap as codes_with_status, so this can't grow unbounded.
    if (info.length > 300) {
      final entries = info.entries.toList();
      entries.removeRange(0, entries.length - 300);
      info
        ..clear()
        ..addEntries(entries);
    }

    await prefs.setString('submitted_product_info', json.encode(info));
  }

  /// Returns the {name, brand} the user typed for [code] when submitting it,
  /// or null if nothing was saved (e.g. submitted before this existed).
  static Future<Map<String, String>?> getSubmittedProductInfo(
      String code) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('submitted_product_info');
    if (raw == null) return null;

    final info = Map<String, dynamic>.from(json.decode(raw));
    final entry = info[code];
    if (entry == null) return null;
    return Map<String, String>.from(entry as Map);
  }

  // Method to get only successfully sent codes
  static Future<List<String>> getSuccessfulCodesFromPreferences() async {
    Map<String, bool> codesWithStatus =
        await getCodesWithStatusFromPreferences();
    return codesWithStatus.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
  }

  // Method to get total number of successful submissions (including removed ones)
  static Future<int> getTotalSuccessfulSubmissions() async {
    final prefs = await SharedPreferences.getInstance();
    int total = 0;
    if (prefs.getInt('total_successful_submissions') == null) {
      total = await migrateTotalSuccessfulSubmissions();
    } else {
      total = prefs.getInt('total_successful_submissions') ?? 0;
    }

    return total;
  }

  static Future<int> migrateTotalSuccessfulSubmissions() async {
    final prefs = await SharedPreferences.getInstance();
    int total = 0;

    Map<String, bool> codesWithStatus =
        await getCodesWithStatusFromPreferences();
    total =
        codesWithStatus.entries.where((entry) => entry.value == true).length;
    await prefs.setInt('total_successful_submissions', total);
    return total;
  }

  static Future<void> addBarcodeToHistory(String barcode) async {
    final prefs = await SharedPreferences.getInstance();
    String? historyJson = prefs.getString('scan_history');

    List<Map<String, dynamic>> history = historyJson != null
        ? List<Map<String, dynamic>>.from(json.decode(historyJson))
        : [];

    // Get the current timestamp
    final now = DateTime.now();

    // Check if the barcode already exists in the same minute
    final alreadyExists = history.any((item) {
      final itemTimestamp = DateTime.parse(item['timestamp']);
      return item['barcode'] == barcode &&
          itemTimestamp.year == now.year &&
          itemTimestamp.month == now.month &&
          itemTimestamp.day == now.day &&
          itemTimestamp.hour == now.hour &&
          itemTimestamp.minute == now.minute;
    });

    // If it doesn't exist, add it to the history
    if (!alreadyExists) {
      history.add({
        'barcode': barcode,
        'timestamp': now.toIso8601String(),
      });

      // Ensure the history contains a maximum of 50 items
      if (history.length > 50) {
        history.removeAt(0); // Remove the oldest entry
      }

      // Save the updated history back to shared preferences
      await prefs.setString('scan_history', json.encode(history));
    }
  }

  /// Persists the Nutriscore/Green-score fetched right after a scan onto
  /// the matching history entry, so the history page never has to re-fetch
  /// them from OpenFoodFacts just to display past scans. Patches the most
  /// recent entry for [barcode] that doesn't have scores yet.
  static Future<void> cacheScanScores(String barcode, ProductScores scores) async {
    if (!scores.hasNutriscore && !scores.hasEcoscore) return;

    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('scan_history');
    if (historyJson == null) return;

    final history =
        List<Map<String, dynamic>>.from(json.decode(historyJson));
    for (var i = history.length - 1; i >= 0; i--) {
      if (history[i]['barcode'] == barcode &&
          history[i]['nutriscore'] == null &&
          history[i]['ecoscore'] == null) {
        history[i] = {
          ...history[i],
          if (scores.nutriscoreGrade != null)
            'nutriscore': scores.nutriscoreGrade,
          if (scores.ecoscoreGrade != null) 'ecoscore': scores.ecoscoreGrade,
        };
        await prefs.setString('scan_history', json.encode(history));
        return;
      }
    }
  }

  /// Looks up scores already cached (via [cacheScanScores]) on a past
  /// history entry for [barcode], so the caller can skip hitting
  /// OpenFoodFacts again for a product we've already scored. Returns null
  /// if there's no history entry for it yet, or none with scores.
  static Future<ProductScores?> getCachedScores(String barcode) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('scan_history');
    if (historyJson == null) return null;

    final history =
        List<Map<String, dynamic>>.from(json.decode(historyJson));
    for (var i = history.length - 1; i >= 0; i--) {
      if (history[i]['barcode'] != barcode) continue;
      final nutriscore = history[i]['nutriscore'] as String?;
      final ecoscore = history[i]['ecoscore'] as String?;
      if (nutriscore == null && ecoscore == null) continue;
      return ProductScores(
        nutriscoreGrade: nutriscore,
        ecoscoreGrade: ecoscore,
      );
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getScanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    String? historyJson = prefs.getString('scan_history');

    if (historyJson != null) {
      return List<Map<String, dynamic>>.from(json.decode(historyJson))
          .reversed
          .toList();
    }
    return [];
  }

  static Future<void> clearScanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('scan_history');
  }

  // Avatar preference methods

  /// Fires whenever the avatar is saved, so widgets showing it (e.g. the
  /// bottom tab bar) can refresh without being wired to the profile UI.
  static final ValueNotifier<String?> avatarNotifier = ValueNotifier(null);

  static Future<void> saveAvatar(String? avatar) async {
    final prefs = await SharedPreferences.getInstance();
    if (avatar == null) {
      await prefs.remove('user_avatar');
    } else {
      await prefs.setString('user_avatar', avatar);
    }
    avatarNotifier.value = avatar;
  }

  static Future<String?> getAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_avatar');
  }

  static Future<void> saveRandomAvatarEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('random_avatar_enabled', enabled);
  }

  static Future<bool> getRandomAvatarEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('random_avatar_enabled') ?? false;
  }

  /// Picks a new random avatar (different from the current one, so the
  /// change is always visible) and saves it, syncing it to the account when
  /// logged in. No-op when the "random avatar" preference is off. Call once
  /// per app launch.
  static Future<void> rollRandomAvatarIfEnabled() async {
    if (!await getRandomAvatarEnabled()) return;

    final current = await getAvatar();
    final choices = kAvailableAvatars.where((a) => a != current).toList();
    final pool = choices.isNotEmpty ? choices : kAvailableAvatars;
    final next = pool[Random().nextInt(pool.length)];

    await saveAvatar(next);
    if (AuthService.isLoggedIn) {
      await AuthService.updateUser(avatar: next);
    }
  }

  // Account prompt methods
  static const String _totalScanCountKey = 'total_scan_count';

  static Future<int> incrementTotalScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_totalScanCountKey) ?? 0) + 1;
    await prefs.setInt(_totalScanCountKey, count);
    return count;
  }

  static Future<int> getTotalScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalScanCountKey) ?? 0;
  }

  // Dashboard B12 reminder banner
  static const String _b12BannerDismissedKey = 'b12_banner_dismissed';

  static Future<void> markB12BannerDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_b12BannerDismissedKey, true);
  }

  static Future<bool> hasB12BannerBeenDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_b12BannerDismissedKey) ?? false;
  }

  // Membership prompt methods
  static const String _membershipHitScanCountKey = 'membership_hit_scan_count';
  static const String _membershipPromptNextThresholdKey =
      'membership_prompt_next_threshold';
  static const int _membershipPromptInitialThreshold = 5;
  static const int _membershipPromptSnoozeScans = 10;

  /// Increments the scan counter and returns whether this scan just crossed
  /// the next threshold, i.e. the subscription prompt should be shown now.
  static Future<bool> incrementMembershipHitScanCount() async {
    final prefs = await SharedPreferences.getInstance();

    final count = (prefs.getInt(_membershipHitScanCountKey) ?? 0) + 1;
    await prefs.setInt(_membershipHitScanCountKey, count);

    final nextThreshold = prefs.getInt(_membershipPromptNextThresholdKey) ??
        _membershipPromptInitialThreshold;
    return count >= nextThreshold;
  }

  static Future<void> snoozeMembershipPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_membershipHitScanCountKey) ?? 0;
    await prefs.setInt(_membershipPromptNextThresholdKey,
        count + _membershipPromptSnoozeScans);
  }

  // Product not-found report methods
  static String _notFoundReportKey(String ean, int shopId) =>
      'not_found_report_${ean}_$shopId';

  static Future<void> saveProductNotFoundReport(String ean, int shopId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _notFoundReportKey(ean, shopId), DateTime.now().toIso8601String());
  }

  static Future<DateTime?> getProductNotFoundReportedAt(
      String ean, int shopId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_notFoundReportKey(ean, shopId));
    if (stored == null) return null;
    return DateTime.tryParse(stored);
  }

  // Product found-report methods
  static String _foundReportKey(String ean, int shopId) =>
      'found_report_${ean}_$shopId';

  static Future<void> saveProductFoundReport(String ean, int shopId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _foundReportKey(ean, shopId), DateTime.now().toIso8601String());
  }

  static Future<DateTime?> getProductFoundReportedAt(
      String ean, int shopId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_foundReportKey(ean, shopId));
    if (stored == null) return null;
    return DateTime.tryParse(stored);
  }

  // Free score reveal methods (weekly quota for non-subscribers)
  static const String _scoreRevealsWeekKey = 'score_reveals_week';
  static const String _scoreRevealsBarcodesKey = 'score_reveals_barcodes';
  static const int freeScoreRevealsPerWeek = 3;

  // Monday of the current week, used to detect when the quota resets
  static String _currentScoreRevealWeek() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return monday.toIso8601String();
  }

  static Future<List<String>> _getRevealedBarcodesThisWeek() async {
    final prefs = await SharedPreferences.getInstance();
    final week = _currentScoreRevealWeek();
    if (prefs.getString(_scoreRevealsWeekKey) != week) {
      await prefs.setString(_scoreRevealsWeekKey, week);
      await prefs.setStringList(_scoreRevealsBarcodesKey, []);
      return [];
    }
    return prefs.getStringList(_scoreRevealsBarcodesKey) ?? [];
  }

  /// Uses a free score reveal for [barcode] if available.
  /// Returns the number of reveals remaining after this one, or null if the
  /// weekly quota is exhausted. Re-revealing a barcode already seen this week
  /// is free and doesn't consume quota.
  static Future<int?> useFreeScoreReveal(String barcode) async {
    final prefs = await SharedPreferences.getInstance();
    final revealed = await _getRevealedBarcodesThisWeek();
    if (revealed.contains(barcode)) {
      return freeScoreRevealsPerWeek - revealed.length;
    }
    if (revealed.length >= freeScoreRevealsPerWeek) return null;
    revealed.add(barcode);
    await prefs.setStringList(_scoreRevealsBarcodesKey, revealed);
    return freeScoreRevealsPerWeek - revealed.length;
  }

  // Map free trial methods (one-time 6-hour unlock for non-subscribers)
  static const String _mapFreeTrialStartKey = 'map_free_trial_started_at';
  static const Duration mapFreeTrialDuration = Duration(hours: 6);

  static Future<bool> hasUsedMapFreeTrial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_mapFreeTrialStartKey) != null;
  }

  static Future<void> markMapFreeTrialUsed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _mapFreeTrialStartKey, DateTime.now().toIso8601String());
  }

  /// When the one-time map trial expires, or null if never started.
  static Future<DateTime?> getMapFreeTrialEnd() async {
    final prefs = await SharedPreferences.getInstance();
    final started = prefs.getString(_mapFreeTrialStartKey);
    if (started == null) return null;
    final startedAt = DateTime.tryParse(started);
    if (startedAt == null) return null;
    return startedAt.add(mapFreeTrialDuration);
  }

  // Pending email change methods
  // Stores the new email the user requested but hasn't confirmed yet (the
  // confirmation happens on the web app). Used to show an "awaiting
  // verification" badge until the backend email matches the confirmed one.
  static const String _pendingEmailChangeKey = 'pending_email_change';

  static Future<void> savePendingEmailChange(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingEmailChangeKey, email);
  }

  static Future<String?> getPendingEmailChange() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingEmailChangeKey);
  }

  static Future<void> clearPendingEmailChange() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingEmailChangeKey);
  }

  static const String _notificationPermissionAskedKey =
      'notification_permission_asked';

  // Mark that we've proactively requested the (app-wide) notification permission
  static Future<void> markNotificationPermissionAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationPermissionAskedKey, true);
  }

  // Check if we've already proactively requested notification permission
  static Future<bool> hasNotificationPermissionBeenAsked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationPermissionAskedKey) ?? false;
  }
}
