import '../models/restaurants/restaurant.dart';

const _days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
final _timeRange = RegExp(r'^(\d{1,2}):(\d{2})-(\d{1,2}):(\d{2})$');
final _daySpec = RegExp(r'^(Mo|Tu|We|Th|Fr|Sa|Su)(-(Mo|Tu|We|Th|Fr|Sa|Su))?$');

/// Converts an OpenStreetMap `opening_hours` value into weekly slots, for
/// the common forms only: rules like `Mo-Fr 12:00-14:30,19:00-22:30` or
/// `Sa off`, separated by `;`, a later rule replacing the earlier ones for
/// its days (as in OSM). Anything else (public holidays, months, open ends,
/// comments, 24/7...) returns null rather than a wrong schedule.
List<OpeningSlot>? parseOsmOpeningHours(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final byDay = <int, List<OpeningSlot>>{};

  for (final rawRule in value.split(';')) {
    final rule = rawRule.trim();
    if (rule.isEmpty) continue;

    // "Mo-Fr,Su 12:00-14:00" or just "10:00-18:00" (every day)
    final space = rule.indexOf(' ');
    final hasDays = space > 0 && !rule.substring(0, space).contains(':');
    final dayPart = hasDays ? rule.substring(0, space) : null;
    final timePart = (hasDays ? rule.substring(space + 1) : rule).trim();

    final days =
        dayPart == null ? List.generate(7, (d) => d) : _parseDays(dayPart);
    if (days == null) return null;

    if (timePart == 'off' || timePart == 'closed') {
      for (final day in days) {
        byDay[day] = [];
      }
      continue;
    }

    final ranges = <(String, String)>[];
    for (final rawRange in timePart.split(',')) {
      final match = _timeRange.firstMatch(rawRange.trim());
      if (match == null) return null;
      final open = _time(match.group(1)!, match.group(2)!);
      final close = _time(match.group(3)!, match.group(4)!);
      if (open == null || close == null || open == close) return null;
      ranges.add((open, close));
    }
    for (final day in days) {
      byDay[day] = [
        for (final (open, close) in ranges)
          OpeningSlot(day: day, open: open, close: close),
      ];
    }
  }

  final slots = [for (final daySlots in byDay.values) ...daySlots];
  if (slots.isEmpty || OpeningSlot.anyOverlap(slots)) return null;
  return slots;
}

/// "Mo-Fr,Su" → [0, 1, 2, 3, 4, 6]; null when not understood.
List<int>? _parseDays(String spec) {
  final days = <int>{};
  for (final part in spec.split(',')) {
    final match = _daySpec.firstMatch(part.trim());
    if (match == null) return null;
    final start = _days.indexOf(match.group(1)!);
    final end = match.group(3) == null ? start : _days.indexOf(match.group(3)!);
    // A range may wrap around the week ("Fr-Mo")
    for (var day = start;; day = (day + 1) % 7) {
      days.add(day);
      if (day == end) break;
    }
  }
  return days.toList()..sort();
}

/// "9", "30" → "09:30"; "24:00" (end of day) → "00:00". Null if invalid.
String? _time(String hours, String minutes) {
  final h = int.parse(hours);
  final m = int.parse(minutes);
  if (m > 59 || h > 24 || (h == 24 && m > 0)) return null;
  return '${(h % 24).toString().padLeft(2, '0')}:${minutes.padLeft(2, '0')}';
}
