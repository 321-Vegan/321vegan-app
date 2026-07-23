import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/error_report.dart';
import 'api_service.dart';

/// Tracks which handled error reports the user has already seen, so the
/// profile can show a "new response" badge when the team treats a report.
///
/// The set of seen IDs is compared against the reports fetched from
/// GET /me/error-reports: a report that is handled but not in the seen set
/// triggers the badge. Opening the listing marks everything as seen.
class ErrorReportBadgeService {
  static const String _seenHandledKey = 'error_reports_seen_handled_ids';

  /// Page size for the badge fetch. The listing modal reuses the fetched
  /// page as its first page, so its pagination uses this same size.
  static const int pageSize = 100;

  /// Current number of unread responses, shared between the profile card
  /// and the "Profil" item of the bottom tab bar.
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  /// Fetch the first page of the user's error reports and refresh
  /// [unreadCount]. Returns the fetched page so callers can reuse it
  /// (e.g. hand it to the listing modal) instead of refetching.
  static Future<ErrorReportPaginated?> refreshUnreadCount() async {
    final result = await ApiService.getMyErrorReports(
        page: 1, pageSize: pageSize);
    if (result == null) return null;
    unreadCount.value = await countUnseenHandled(result.items);
    return result;
  }

  /// Number of reports in [reports] that are handled but haven't been seen
  /// yet.
  static Future<int> countUnseenHandled(List<ErrorReport> reports) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = (prefs.getStringList(_seenHandledKey) ?? []).toSet();
      return reports
          .where((r) => r.handled && !seen.contains(r.id.toString()))
          .length;
    } catch (e) {
      debugPrint('Failed to check unseen error report responses: $e');
      return 0;
    }
  }

  /// Mark the handled reports among [reports] as seen. The stored set is
  /// replaced (not merged): the badge check only ever looks at the same
  /// fetch window, so IDs outside it are irrelevant.
  static Future<void> markHandledAsSeen(List<ErrorReport> reports) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _seenHandledKey,
        reports.where((r) => r.handled).map((r) => r.id.toString()).toList(),
      );
    } catch (e) {
      debugPrint('Failed to mark error report responses as seen: $e');
    }
    unreadCount.value = 0;
  }
}
