import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/veganuary_images.dart';
import '../models/veganuary/veganuary_content.dart';
import '../models/veganuary/veganuary_progress.dart';
import 'api_service.dart';
import 'veganuary_sync_service.dart';

/// Content and progress (stored on the device) of the Veganuary course.
/// The content is on the API only (not in this open source repository):
/// downloaded on the first visit, then kept on the device, and downloaded
/// again when edited there (see [refreshContent]).
class VeganuaryService {
  VeganuaryService._();

  static const int totalDays = 31;

  /// The Discord server where people doing the course ask their questions
  /// and talk with vegans (intro sheet, path's header).
  static const String discordUrl = 'https://discord.gg/a8xrF2b23S';
  static const String discordLogo =
      'lib/assets/images/remerciements/discord.png';

  static const String _progressKey = 'veganuary_progress';
  static const String _welcomeSeenKey = 'veganuary_welcome_seen';

  static List<VeganuaryWeek>? _weeks;

  /// The weeks kept on the device; downloaded first if there are none yet.
  /// Throws [VeganuaryContentUnavailable] when they can't be (offline on
  /// the first visit).
  static Future<List<VeganuaryWeek>> loadWeeks() async {
    final loaded = _weeks;
    if (loaded != null) return loaded;
    var weeks = await _downloadedWeeks();
    if (weeks.isEmpty) {
      await refreshContent();
      weeks = await _downloadedWeeks();
    }
    if (weeks.isEmpty) throw const VeganuaryContentUnavailable();
    _prefetchImagesOnce();
    return _weeks = weeks;
  }

  static bool _imagesChecked = false;

  /// Once per launch, in the background: the images not downloaded yet
  /// (e.g. offline the last time), for the course to work offline.
  static Future<void> _prefetchImagesOnce() async {
    if (_imagesChecked) return;
    _imagesChecked = true;
    final saved = await _readDownloaded();
    if (saved != null) await prefetchVeganuaryImages(saved['weeks'] as List);
  }

  /// The weeks downloaded from the API, with their version:
  /// `{"version": ..., "weeks": [...]}`.
  static Future<File> get _downloadedFile async => File(
      '${(await getApplicationSupportDirectory()).path}/veganuary_weeks.json');

  static Future<Map<String, dynamic>?> _readDownloaded() async {
    try {
      final file = await _downloadedFile;
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Veganuary downloaded content unreadable: $e');
      return null;
    }
  }

  static Future<List<VeganuaryWeek>> _downloadedWeeks() async {
    final saved = await _readDownloaded();
    if (saved == null) return const [];
    try {
      return [
        for (final week in saved['weeks'] as List)
          VeganuaryWeek.fromRemoteJson(week as Map<String, dynamic>),
      ]..sort((a, b) => a.number.compareTo(b.number));
    } catch (e) {
      // Kept only once read without error: shouldn't happen
      debugPrint('Veganuary downloaded content invalid: $e');
      return const [];
    }
  }

  /// Downloads the weeks from the API when they changed since last time;
  /// true when they did (to load them again). Weeks that can't be read, or
  /// none at all, are not kept: the ones before stay. Asked twice at once
  /// (the first visit loads and refreshes), downloads once.
  static Future<bool> refreshContent() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  static Future<bool>? _refreshing;

  static Future<bool> _refresh() async {
    final remote = await ApiService.getVeganuaryVersion();
    // Offline, or nothing on the API: next time
    if (remote?.version == null) return false;
    final saved = await _readDownloaded();
    if (remote!.version == saved?['version']) return false;
    final weeks = await ApiService.getVeganuaryWeeks();
    if (weeks == null || weeks.isEmpty) return false;
    try {
      for (final week in weeks) {
        VeganuaryWeek.fromRemoteJson(week);
      }
    } catch (e) {
      debugPrint('Veganuary content from the API invalid, not kept: $e');
      return false;
    }
    await (await _downloadedFile)
        .writeAsString(jsonEncode({'version': remote.version, 'weeks': weeks}));
    _weeks = null;
    _imagesChecked = false;
    return true;
  }

  static Future<VeganuaryProgress> loadProgress() async =>
      _read(await SharedPreferences.getInstance());

  static VeganuaryProgress _read(SharedPreferences prefs) {
    final raw = prefs.getString(_progressKey);
    if (raw == null) return const VeganuaryProgress();
    return VeganuaryProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Reads the progress, changes it and writes it back with nothing in
  /// between (no await: SharedPreferences updates its cache right away,
  /// the disk after). A write from elsewhere at the same time (the day
  /// page, the sync with the server) can't be overwritten by a stale copy.
  static Future<VeganuaryProgress> _update(
      VeganuaryProgress Function(VeganuaryProgress progress) change) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = change(_read(prefs));
    await prefs.setString(_progressKey, jsonEncode(updated.toJson()));
    return updated;
  }

  static Future<VeganuaryProgress> completeDay(int day,
      {String? mythId}) async {
    var done = false;
    final updated = await _update((progress) {
      // Opened again to reread: keeps the date it was first done.
      if (progress.isCompleted(day)) return progress;
      done = true;
      return progress.withCompleted(day, mythId: mythId);
    });
    if (done) unawaited(VeganuarySyncService.onDayCompleted(day));
    return updated;
  }

  /// Adds the days done on another device (from the server, see
  /// VeganuarySyncService), keeping only days in a row from day 1; true
  /// when there are new ones (the path then reloads).
  static Future<bool> mergeProgress(
      Map<int, DateTime> days, Map<int, String> myths) async {
    var changed = false;
    await _update((progress) {
      final merged =
          progress.mergedWith(days, myths).contiguous(lastDay: totalDays);
      changed = !mapEquals(merged.completedAt, progress.completedAt);
      return merged;
    });
    return changed;
  }

  /// Saves where the user is in a day not done yet, to resume it there.
  static Future<void> saveStarted(VeganuaryStartedDay started,
      {String? mythId}) =>
      _update((progress) => progress.isCompleted(started.day)
          ? progress
          : progress.withStarted(started, mythId: mythId));

  /// Whether the intro sheet was closed with its last button.
  static Future<bool> welcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_welcomeSeenKey) ?? false;
  }

  static Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeSeenKey, true);
  }

  /// Debug: starts the course over, also showing the intro sheet again;
  /// on the server too for a logged-in user (see VeganuarySyncService).
  static Future<void> reset() => VeganuarySyncService.reset(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_progressKey);
        await prefs.remove(_welcomeSeenKey);
      });

  /// Debug: moves every completion one day back, to open the next day
  /// without waiting until tomorrow.
  static Future<void> shiftOneDayBack() async {
    final updated = await _update((progress) => progress.copyWith(
          completedAt: progress.completedAt.map((day, date) =>
              MapEntry(day, DateTime(date.year, date.month, date.day - 1))),
        ));
    await VeganuarySyncService.onDatesChanged(updated.completedAt.keys);
  }

  /// Debug: the next day done without opening it (no idée reçue picked),
  /// dated yesterday so the one after opens right away.
  static Future<void> debugCompleteNextDay() async {
    int? done;
    await _update((progress) {
      if (progress.nextDay > totalDays) return progress;
      done = progress.nextDay;
      final now = DateTime.now();
      return progress.withCompleted(progress.nextDay,
          now: DateTime(now.year, now.month, now.day - 1));
    });
    if (done != null) await VeganuarySyncService.onDayCompleted(done!);
  }
}

/// The course's content isn't on the device yet, and can't be downloaded
/// (offline on the first visit).
class VeganuaryContentUnavailable implements Exception {
  const VeganuaryContentUnavailable();
}
