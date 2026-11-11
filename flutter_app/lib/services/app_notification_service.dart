import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../pages/app_pages/Profile/error_reports_page.dart';
import '../pages/app_pages/Profile/my_contributions_page.dart';
import '../models/restaurants/restaurant_selection.dart';
import '../widgets/restaurants/restaurant_detail_page.dart';
import '../widgets/restaurants/selection_page.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'restaurant_api_service.dart';

/// The user's notification inbox from the API (GET /me/notifications),
/// shown in the Dashboard bell. Server pushes only signal that something is
/// new: the inbox is always reloaded from the API.
class AppNotificationService {
  AppNotificationService._();

  static const int _pageSize = 100;

  /// Newest first.
  static final ValueNotifier<List<AppNotification>> items =
      ValueNotifier<List<AppNotification>>(const []);

  /// Unread notifications, for the bell badge.
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  static void _set(List<AppNotification> notifications) {
    items.value = List.unmodifiable(notifications);
    unreadCount.value = notifications.where((n) => !n.isRead).length;
  }

  /// Reloads every page from the start, so read states and deletions made
  /// on another device are picked up too. Keeps the current list on failure.
  static Future<void> refresh() async {
    if (!AuthService.isLoggedIn) return clear();
    final all = <AppNotification>[];
    var afterId = 0;
    while (true) {
      final page = await ApiService.getMyNotifications(
          afterId: afterId, limit: _pageSize);
      if (page == null) return;
      all.addAll(page);
      if (page.length < _pageSize) break;
      afterId = page.last.id;
    }
    _set(all.reversed.toList());
  }

  /// Logout: the inbox belongs to the previous account.
  static void clear() => _set(const []);

  static Future<void> markRead(int id) async {
    final current = items.value;
    final known = current.any((n) => n.id == id);
    if (known) {
      _set([for (final n in current) n.id == id ? n.markedRead() : n]);
    }
    await ApiService.markNotificationRead(id);
    // Push tapped before the inbox had it: load it, now read
    if (!known) await refresh();
  }

  static Future<void> delete(int id) async {
    _set([for (final n in items.value) if (n.id != id) n]);
    // Put it back if the API didn't take it
    if (!await ApiService.deleteNotification(id)) await refresh();
  }

  /// Opens what [notification] is about and marks it read.
  static Future<void> open(
      BuildContext context, AppNotification notification) async {
    markRead(notification.id);
    switch (notification.type) {
      case AppNotification.errorReportHandled:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ErrorReportsPage()),
        );
      case AppNotification.restaurantValidated ||
            AppNotification.restaurantRejected ||
            AppNotification.restaurantContacted:
        await _openRestaurant(
            context, notification, MyContributionsPage.placesTab);
      case AppNotification.restaurantSuggestionApproved ||
            AppNotification.restaurantSuggestionRejected:
        await _openRestaurant(
            context, notification, MyContributionsPage.suggestionsTab);
      case AppNotification.selectionReceived:
        final id = notification.payload['selection_id'];
        if (id is! int) return;
        // The page loads it from its id, with its accept/refuse buttons
        await SelectionPage.open(
          context,
          RestaurantSelection(
              id: id, title: '', ownerNickname: '', isOwner: false),
        );
    }
  }

  /// The place's page; when it's gone (refused, delisted), the
  /// contributions tab listing its status and the moderator's reason.
  static Future<void> _openRestaurant(BuildContext context,
      AppNotification notification, int fallbackTab) async {
    // A duplicate merged away: the place kept instead
    final id = notification.payload['merged_into'] ??
        notification.payload['restaurant_id'];
    final restaurant =
        id is int ? await RestaurantApiService.getRestaurant(id) : null;
    if (!context.mounted) return;
    if (restaurant != null) {
      await RestaurantDetailPage.open(context, restaurant);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyContributionsPage(initialTab: fallbackTab),
      ),
    );
  }
}
