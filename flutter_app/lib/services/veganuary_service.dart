import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/veganuary/veganuary_content.dart';
import '../models/veganuary/veganuary_progress.dart';

/// Content (bundled JSON) and progress (stored on the device) of the
/// Veganuary course.
class VeganuaryService {
  VeganuaryService._();

  static const int totalDays = 31;

  /// The Discord server where people doing the course ask their questions
  /// and talk with vegans (intro sheet, path's header).
  static const String discordUrl = 'https://discord.gg/a8xrF2b23S';
  static const String discordLogo =
      'lib/assets/images/remerciements/discord.png';

  /// One file per week, in order; add the next weeks here as they're
  /// written (and in pubspec.yaml). Checked by test/models/veganuary_test.
  static const List<String> weekAssets = [
    'lib/assets/veganuary/week1.json',
    'lib/assets/veganuary/week2.json',
    'lib/assets/veganuary/week3.json',
    'lib/assets/veganuary/week4.json',
    'lib/assets/veganuary/week5.json',
  ];

  static const String _progressKey = 'veganuary_progress';
  static const String _welcomeSeenKey = 'veganuary_welcome_seen';

  static List<VeganuaryWeek>? _weeks;

  static Future<List<VeganuaryWeek>> loadWeeks() async {
    return _weeks ??= [
      for (final asset in weekAssets)
        VeganuaryWeek.fromJson(jsonDecode(await rootBundle.loadString(asset))
            as Map<String, dynamic>),
    ];
  }

  static Future<VeganuaryProgress> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey);
    if (raw == null) return const VeganuaryProgress();
    return VeganuaryProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<VeganuaryProgress> completeDay(int day,
      {String? mythId}) async {
    final progress = await loadProgress();
    // Opened again to reread: keeps the date it was first done.
    if (progress.isCompleted(day)) return progress;
    final updated = progress.withCompleted(day, mythId: mythId);
    await _save(updated);
    return updated;
  }

  /// Saves where the user is in a day not done yet, to resume it there.
  static Future<void> saveStarted(VeganuaryStartedDay started,
      {String? mythId}) async {
    final progress = await loadProgress();
    if (progress.isCompleted(started.day)) return;
    await _save(progress.withStarted(started, mythId: mythId));
  }

  /// Whether the intro sheet was closed with its last button.
  static Future<bool> welcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_welcomeSeenKey) ?? false;
  }

  static Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeSeenKey, true);
  }

  /// Also shows the intro sheet again.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_progressKey);
    await prefs.remove(_welcomeSeenKey);
  }

  /// Debug: moves every completion one day back, to open the next day
  /// without waiting until tomorrow.
  static Future<void> shiftOneDayBack() async {
    final progress = await loadProgress();
    await _save(progress.copyWith(
      completedAt: progress.completedAt.map((day, date) =>
          MapEntry(day, DateTime(date.year, date.month, date.day - 1))),
    ));
  }

  /// Debug: the next day done without opening it (no idée reçue picked),
  /// dated yesterday so the one after opens right away.
  static Future<void> debugCompleteNextDay() async {
    final progress = await loadProgress();
    if (progress.nextDay > totalDays) return;
    final now = DateTime.now();
    await _save(progress.withCompleted(progress.nextDay,
        now: DateTime(now.year, now.month, now.day - 1)));
  }

  static Future<void> _save(VeganuaryProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_progressKey, jsonEncode(progress.toJson()));
  }
}
