import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/badge.dart' as app_badge;
import '../models/user.dart';
import '../widgets/badges/badge_unlock_modal.dart';

class BadgeService {
  static const String _unlockedBadgesKey = 'unlocked_badges';

  /// Get list of currently unlocked badge IDs based on user stats
  static List<String> getUnlockedBadgeIds({
    required int productsSent,
    required DateTime? veganSince,
    required int supporterLevel,
    required int errorReports,
  }) {
    final unlockedBadges = <String>[];

    for (final badge in app_badge.Badges.all) {
      if (badge.isUnlocked(
        productsSent: productsSent,
        veganSince: veganSince,
        supporterLevel: supporterLevel,
        errorSolved: errorReports,
      )) {
        unlockedBadges.add(badge.id);
      }
    }

    return unlockedBadges;
  }

  /// Get list of previously unlocked badges from storage
  static Future<List<String>> getPreviouslyUnlockedBadges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_unlockedBadgesKey) ?? [];
    } catch (e) {
      debugPrint('Error loading previously unlocked badges: $e');
      return [];
    }
  }

  /// Save currently unlocked badges to storage
  static Future<void> saveUnlockedBadges(List<String> badgeIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_unlockedBadgesKey, badgeIds);
    } catch (e) {
      debugPrint('Error saving unlocked badges: $e');
    }
  }

  /// Detect newly unlocked badges and return them
  static Future<List<app_badge.Badge>> detectNewlyUnlockedBadges(
      User user) async {
    final currentlyUnlocked = getUnlockedBadgeIds(
      productsSent: user.nbProductsSent ?? 0,
      veganSince: user.veganSince,
      supporterLevel: user.supporterLevel ?? 0,
      errorReports: user.nbErrorReports ?? 0,
    );

    final previouslyUnlocked = await getPreviouslyUnlockedBadges();

    // Find badges that are in currentlyUnlocked but not in previouslyUnlocked
    final newBadgeIds = currentlyUnlocked
        .where((id) => !previouslyUnlocked.contains(id))
        .toList();

    // Get the actual badge objects
    final newBadges = app_badge.Badges.all
        .where((badge) => newBadgeIds.contains(badge.id))
        .toList();

    // Update the stored list
    if (newBadges.isNotEmpty) {
      await saveUnlockedBadges(currentlyUnlocked);
    }

    return newBadges;
  }

  /// Check for new badges and show modal if any are found
  static Future<void> checkAndShowNewBadges(
    BuildContext context,
    User user, {
    bool mounted = true,
  }) async {
    if (!mounted) return;

    final newBadges = await detectNewlyUnlockedBadges(user);

    if (newBadges.isNotEmpty && context.mounted) {
      // Show a single bottom sheet listing all newly unlocked badges as a
      // slider
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => BadgeUnlockModal(badges: newBadges),
      );
    }
  }

  /// Initialize badge tracking for a user (call on first login or profile creation)
  static Future<void> initializeBadgeTracking(User user) async {
    final currentlyUnlocked = getUnlockedBadgeIds(
      productsSent: user.nbProductsSent ?? 0,
      veganSince: user.veganSince,
      supporterLevel: user.supporterLevel ?? 0,
      errorReports: user.nbErrorReports ?? 0,
    );

    // Only save if we don't have any previous data
    final previouslyUnlocked = await getPreviouslyUnlockedBadges();
    if (previouslyUnlocked.isEmpty) {
      await saveUnlockedBadges(currentlyUnlocked);
    }
  }

  /// Force update the unlocked badges (useful for debugging or reset)
  static Future<void> forceUpdateUnlockedBadges(User user) async {
    final currentlyUnlocked = getUnlockedBadgeIds(
      productsSent: user.nbProductsSent ?? 0,
      veganSince: user.veganSince,
      supporterLevel: user.supporterLevel ?? 0,
      errorReports: user.nbErrorReports ?? 0,
    );

    await saveUnlockedBadges(currentlyUnlocked);
  }

  /// Clear all badge tracking (for logout or account deletion)
  static Future<void> clearBadgeTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_unlockedBadgesKey);
    } catch (e) {
      debugPrint('Error clearing badge tracking: $e');
    }
  }
}
