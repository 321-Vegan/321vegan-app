import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/error_report.dart';

/// Tracks which handled error reports the user has already seen, so the
/// profile can show a "new response" badge when the team treats a report.
///
/// The set of seen IDs is compared against the reports fetched from
/// GET /me/error-reports: a report that is handled but not in the seen set
/// triggers the badge. Opening the listing marks everything as seen.
class ErrorReportBadgeService {
  static const String _seenHandledKey = 'error_reports_seen_handled_ids';

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
  }
}
