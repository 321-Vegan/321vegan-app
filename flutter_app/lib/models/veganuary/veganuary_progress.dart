import 'veganuary_content.dart';

enum VeganuaryDayState {
  completed,

  /// The next day to do, open now.
  available,

  /// The next day to do, open tomorrow: the user is up to date.
  tomorrow,
  locked,
}

/// Where the user is in the course. The day day 1 is done starts it: day N
/// opens N-1 days later. Days missed are caught up, in order (back on day 3
/// after skipping day 2: day 2 then day 3). Started in January, day N opens
/// on January N instead (see [unlockDate]).
class VeganuaryProgress {
  /// Beta tests: each day opens as soon as the one before it is done, not
  /// the next day (`VEGANUARY_UNLOCK_RIGHT_AWAY=true` in .env, set in
  /// main.dart). Never in a build for the stores.
  static bool unlockRightAway = false;

  /// Day number → date it was done (local, no time).
  final Map<int, DateTime> completedAt;

  /// Day number → id of the idée reçue picked that day (also for the day
  /// started, to resume on its answer).
  final Map<int, String> pickedMyths;

  /// The next day, left halfway.
  final VeganuaryStartedDay? started;

  const VeganuaryProgress({
    this.completedAt = const {},
    this.pickedMyths = const {},
    this.started,
  });

  factory VeganuaryProgress.fromJson(Map<String, dynamic> json) {
    final started = json['started'] as Map<String, dynamic>?;
    return VeganuaryProgress(
      started: started == null ? null : VeganuaryStartedDay.fromJson(started),
      completedAt: {
        for (final entry
            in (json['completed'] as Map<String, dynamic>? ?? {}).entries)
          int.parse(entry.key): DateTime.parse(entry.value as String),
      },
      pickedMyths: {
        for (final entry
            in (json['myths'] as Map<String, dynamic>? ?? {}).entries)
          int.parse(entry.key): entry.value as String,
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'completed': {
          for (final entry in completedAt.entries)
            '${entry.key}': _formatDate(entry.value),
        },
        'myths': {
          for (final entry in pickedMyths.entries) '${entry.key}': entry.value,
        },
        if (started != null) 'started': started!.toJson(),
      };

  /// First day not done yet (32 once the course is over).
  int get nextDay => completedAt.length + 1;

  bool isCompleted(int day) => completedAt.containsKey(day);

  bool isWeekDone(VeganuaryWeek week) =>
      week.days.every((day) => isCompleted(day.number));

  /// The recipes of the days done, in order.
  List<RecipeStep> unlockedRecipes(List<VeganuaryWeek> weeks) => [
        for (final week in weeks)
          for (final day in week.days)
            if (isCompleted(day.number)) ...day.steps.whereType<RecipeStep>(),
      ];

  /// Share of [day] read so far, 0 to 1 (1 once done).
  double dayProgress(int day) {
    if (isCompleted(day)) return 1;
    final started = this.started;
    return started != null && started.day == day ? started.fraction : 0;
  }

  VeganuaryDayState stateOf(int day, {DateTime? now}) {
    if (isCompleted(day)) return VeganuaryDayState.completed;
    if (day != nextDay) return VeganuaryDayState.locked;
    if (day == 1 || unlockRightAway) return VeganuaryDayState.available;
    final today = dateOnly(now ?? DateTime.now());
    return unlockDate(day).isAfter(today)
        ? VeganuaryDayState.tomorrow
        : VeganuaryDayState.available;
  }

  /// Date [day] opens; day 1 must be done. Started in January, it follows
  /// the calendar: day N opens on January N (started on the 5th, days 2 to 5
  /// open right after day 1).
  DateTime unlockDate(int day) {
    final start = completedAt[1]!;
    if (start.month == DateTime.january) return DateTime(start.year, 1, day);
    return DateTime(start.year, start.month, start.day + day - 1);
  }

  VeganuaryProgress withCompleted(int day, {String? mythId, DateTime? now}) {
    return VeganuaryProgress(
      completedAt: {...completedAt, day: dateOnly(now ?? DateTime.now())},
      pickedMyths: {...pickedMyths, if (mythId != null) day: mythId},
    );
  }

  VeganuaryProgress withStarted(VeganuaryStartedDay started, {String? mythId}) {
    return VeganuaryProgress(
      completedAt: completedAt,
      pickedMyths: {...pickedMyths, if (mythId != null) started.day: mythId},
      started: started,
    );
  }

  /// With the days done elsewhere (another device, the server, see
  /// VeganuarySyncService) added: a day done on both keeps its earliest
  /// date, and the idée reçue known for it. A started day done elsewhere is
  /// no longer started.
  VeganuaryProgress mergedWith(
      Map<int, DateTime> days, Map<int, String> myths) {
    final merged = {...completedAt};
    days.forEach((day, date) {
      final local = merged[day];
      if (local == null || date.isBefore(local)) merged[day] = dateOnly(date);
    });
    final started = this.started;
    return VeganuaryProgress(
      completedAt: merged,
      pickedMyths: {...myths, ...pickedMyths},
      started:
          started != null && merged.containsKey(started.day) ? null : started,
    );
  }

  /// Only the days done in a row from day 1, up to [lastDay]: what the
  /// course counts on ([nextDay], [unlockDate] from day 1). Days after a
  /// gap (e.g. from the server, after a reset on another device) are left
  /// out, with their idées reçues.
  VeganuaryProgress contiguous({required int lastDay}) {
    final kept = <int, DateTime>{};
    for (var day = 1; day <= lastDay && completedAt.containsKey(day); day++) {
      kept[day] = completedAt[day]!;
    }
    if (kept.length == completedAt.length) return this;
    final started = this.started;
    final keepStarted = started != null && started.day == kept.length + 1;
    return VeganuaryProgress(
      completedAt: kept,
      pickedMyths: {
        for (final entry in pickedMyths.entries)
          if (kept.containsKey(entry.key) ||
              (keepStarted && entry.key == started.day))
            entry.key: entry.value,
      },
      started: keepStarted ? started : null,
    );
  }

  VeganuaryProgress copyWith({Map<int, DateTime>? completedAt}) {
    return VeganuaryProgress(
      completedAt: completedAt ?? this.completedAt,
      pickedMyths: pickedMyths,
      started: started,
    );
  }

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// Where the user left a day: [screen] pages read out of [screens], and
/// what was done on them, to find it again.
class VeganuaryStartedDay {
  final int day;
  final int screen;
  final int screens;

  /// Page index of each quiz answered → index of the choice picked.
  final Map<int, int> quizAnswers;

  /// Labels of the grid cards opened.
  final Set<String> openedCards;

  const VeganuaryStartedDay({
    required this.day,
    required this.screen,
    required this.screens,
    this.quizAnswers = const {},
    this.openedCards = const {},
  });

  factory VeganuaryStartedDay.fromJson(Map<String, dynamic> json) {
    return VeganuaryStartedDay(
      day: json['day'] as int,
      screen: json['screen'] as int,
      screens: json['screens'] as int,
      quizAnswers: {
        for (final entry
            in (json['quiz'] as Map<String, dynamic>? ?? {}).entries)
          int.parse(entry.key): entry.value as int,
      },
      openedCards: {...?(json['cards'] as List?)?.cast<String>()},
    );
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'screen': screen,
        'screens': screens,
        if (quizAnswers.isNotEmpty)
          'quiz': {
            for (final entry in quizAnswers.entries)
              '${entry.key}': entry.value,
          },
        if (openedCards.isNotEmpty) 'cards': openedCards.toList(),
      };

  double get fraction => screens == 0 ? 0 : (screen / screens).clamp(0, 1);
}
