import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'error_report_badge_service.dart';

/// A single in-app notification counter contributing to the profile badge.
class ProfileNotificationSource {
  const ProfileNotificationSource({
    required this.count,
    required this.refresh,
  });

  /// Current number of unread notifications for this source. The owning
  /// service updates it whenever the count changes (fetch, mark-as-seen…).
  final ValueNotifier<int> count;

  /// Re-query the source (called on app start and after login).
  final Future<void> Function() refresh;
}

/// Aggregates the app's in-app notification counters into the number shown
/// on the "Profil" item of the bottom tab bar.
///
/// To plug a new notification system in, expose a `ValueNotifier<int>` and
/// a refresh method from its service, and add them to [_sources] below —
/// the tab badge picks it up automatically.
class ProfileNotificationService {
  ProfileNotificationService._();

  static final List<ProfileNotificationSource> _sources = [
    // Responses to the user's signalements the user hasn't read yet.
    ProfileNotificationSource(
      count: ErrorReportBadgeService.unreadCount,
      refresh: ErrorReportBadgeService.refreshUnreadCount,
    ),
  ];

  /// Fires whenever any source's count changes.
  static final Listenable listenable =
      Listenable.merge([for (final s in _sources) s.count]);

  /// Total unread notifications across all sources.
  static int get total =>
      _sources.fold(0, (sum, source) => sum + source.count.value);

  /// Re-query every source. All current sources are account-bound, so this
  /// is a no-op when logged out.
  static Future<void> refreshAll() async {
    if (!AuthService.isLoggedIn) return;
    await Future.wait([for (final s in _sources) s.refresh()]);
  }
}
