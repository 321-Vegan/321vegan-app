import 'package:flutter/foundation.dart';
import 'restaurant_api_service.dart';

/// Number of restaurant selections sent to the user that they haven't seen
/// yet (pending, not opened), for the bell and the "Lieux sauvegardés" row.
/// The API keeps what was seen: opening the selections tab marks them all.
class SelectionBadgeService {
  SelectionBadgeService._();

  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  /// Keeps the last count on failure.
  static Future<void> refreshUnreadCount() async {
    final count = await RestaurantApiService.getUnreadSelectionCount();
    if (count != null) unreadCount.value = count;
  }

  /// The user opened their received selections.
  static Future<void> markAllSeen() async {
    if (unreadCount.value == 0) return;
    if (await RestaurantApiService.markReceivedSelectionsSeen()) {
      unreadCount.value = 0;
    }
  }
}
