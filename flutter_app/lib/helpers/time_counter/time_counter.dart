/// Elapsed time since a target date, split into calendar units.
class TimeBreakdown {
  final int years, months, days, hours, minutes, seconds;

  const TimeBreakdown({
    this.years = 0,
    this.months = 0,
    this.days = 0,
    this.hours = 0,
    this.minutes = 0,
    this.seconds = 0,
  });

  /// Computes the breakdown between [target] and [now]. Returns zeros when
  /// [target] is null or in the future.
  factory TimeBreakdown.between(DateTime? target, DateTime now) {
    if (target == null || !now.isAfter(target)) return const TimeBreakdown();

    int years = now.year - target.year;
    int months = now.month - target.month;
    int days = now.day - target.day;
    int hours = now.hour - target.hour;
    int minutes = now.minute - target.minute;
    int seconds = now.second - target.second;

    if (seconds < 0) {
      seconds += 60;
      minutes -= 1;
    }
    if (minutes < 0) {
      minutes += 60;
      hours -= 1;
    }
    if (hours < 0) {
      hours += 24;
      days -= 1;
    }
    if (days < 0) {
      days += DateTime(now.year, now.month, 0).day;
      months -= 1;
    }
    if (months < 0) {
      months += 12;
      years -= 1;
    }

    return TimeBreakdown(
      years: years,
      months: months,
      days: days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
    );
  }
}

