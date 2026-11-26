import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'veganuary_reminder_service.dart';

/// When the Veganuary opens: before, its tab shows a teaser instead. The
/// date comes from the API (`opens_at` of `/veganuary-weeks/version`, set
/// on the API), kept for the next launches; [defaultOpensAt] until it's
/// ever been fetched.
class VeganuaryLaunch {
  static final DateTime defaultOpensAt = DateTime(2027, 1, 1);
  static const String _opensAtKey = 'veganuary_opens_at';

  /// Beta tests: open whatever the date (`VEGANUARY_OPEN_RIGHT_AWAY=true` in
  /// .env, set in main.dart). Never in a build for the stores.
  static bool openRightAway = false;

  static DateTime _opensAt = defaultOpensAt;
  static DateTime get opensAt => _opensAt;

  /// Whether the course is open; switches on its own at [opensAt] (the app
  /// open at midnight, or back to it after).
  static final ValueNotifier<bool> isOpen = ValueNotifier(false);

  static Timer? _timer;
  static AppLifecycleListener? _lifecycle;

  /// The date kept from last time. Before the first frame: the tab shows
  /// the right thing straight away.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _opensAt =
        DateTime.tryParse(prefs.getString(_opensAtKey) ?? '') ?? defaultOpensAt;
    // Timers don't run while the app is in the background; the date may
    // have changed on the API meanwhile
    _lifecycle ??= AppLifecycleListener(onResume: () {
      _update();
      if (!isOpen.value) unawaited(refresh());
    });
    _update();
  }

  /// The date set on the API, if it can be reached: none there brings back
  /// [defaultOpensAt].
  static Future<void> refresh() async {
    final remote = await ApiService.getVeganuaryVersion();
    if (remote == null) return;
    final prefs = await SharedPreferences.getInstance();
    final opensAt = remote.opensAt;
    if (opensAt == null) {
      await prefs.remove(_opensAtKey);
    } else {
      await prefs.setString(_opensAtKey, opensAt.toIso8601String());
    }
    final changed = _opensAt != (opensAt ?? defaultOpensAt);
    _opensAt = opensAt ?? defaultOpensAt;
    _update();
    // The opening reminder follows the new date
    if (changed) {
      unawaited(VeganuaryReminderService.rescheduleOpeningReminder());
    }
  }

  static void _update() {
    _timer?.cancel();
    final now = DateTime.now();
    isOpen.value = openRightAway || !now.isBefore(_opensAt);
    if (!isOpen.value) _timer = Timer(_opensAt.difference(now), _update);
  }

  /// [opensAt] to display: "1er janvier".
  static String get opensAtLabel => DateFormat('d MMMM', 'fr_FR')
      .format(_opensAt)
      .replaceFirst(RegExp(r'^1 '), '1er ');
}
