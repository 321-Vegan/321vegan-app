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
/// after skipping day 2: day 2 then day 3).
class VeganuaryProgress {
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

  /// Share of [day] read so far, 0 to 1 (1 once done).
  double dayProgress(int day) {
    if (isCompleted(day)) return 1;
    final started = this.started;
    return started != null && started.day == day ? started.fraction : 0;
  }

  VeganuaryDayState stateOf(int day, {DateTime? now}) {
    if (isCompleted(day)) return VeganuaryDayState.completed;
    if (day != nextDay) return VeganuaryDayState.locked;
    if (day == 1) return VeganuaryDayState.available;
    final today = dateOnly(now ?? DateTime.now());
    return unlockDate(day).isAfter(today)
        ? VeganuaryDayState.tomorrow
        : VeganuaryDayState.available;
  }

  /// Date [day] opens; day 1 must be done.
  DateTime unlockDate(int day) {
    final start = completedAt[1]!;
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

/// Where the user left a day: [screen] pages read out of [screens].
class VeganuaryStartedDay {
  final int day;
  final int screen;
  final int screens;

  const VeganuaryStartedDay({
    required this.day,
    required this.screen,
    required this.screens,
  });

  factory VeganuaryStartedDay.fromJson(Map<String, dynamic> json) {
    return VeganuaryStartedDay(
      day: json['day'] as int,
      screen: json['screen'] as int,
      screens: json['screens'] as int,
    );
  }

  Map<String, dynamic> toJson() =>
      {'day': day, 'screen': screen, 'screens': screens};

  double get fraction => screens == 0 ? 0 : (screen / screens).clamp(0, 1);
}
