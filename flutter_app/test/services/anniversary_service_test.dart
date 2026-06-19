import 'package:flutter_test/flutter_test.dart';
import 'package:vegan_app/services/anniversary_service.dart';

void main() {
  group('AnniversaryService.veganYears', () {
    test('counts a full year when start has a later time-of-day than the fire '
        'time (the off-by-one bug)', () {
      // Started at 14:30; the notification fires at 10:00 on the anniversary,
      // so `now - start` is ~365 days minus a few hours. inDays ~/ 365 would
      // truncate to 0/1; the calendar-based count must be exact.
      final start = DateTime(2026, 6, 18, 14, 30);

      expect(
        AnniversaryService.veganYears(start, now: DateTime(2027, 6, 18, 10, 0)),
        1,
      );
      expect(
        AnniversaryService.veganYears(start, now: DateTime(2028, 6, 18, 10, 0)),
        2,
      );
    });

    test('day before the anniversary has not ticked over yet', () {
      final start = DateTime(2026, 6, 18, 14, 30);
      expect(
        AnniversaryService.veganYears(start, now: DateTime(2027, 6, 17, 23, 59)),
        0,
      );
    });

    test('exact anniversary day at any time counts the new year', () {
      final start = DateTime(2024, 3, 10);
      // Even a fire time earlier in the day than the start's time-of-day.
      expect(
        AnniversaryService.veganYears(start, now: DateTime(2027, 3, 10, 0, 0)),
        3,
      );
    });

    test('earlier month in the year has not reached the anniversary', () {
      final start = DateTime(2020, 8, 15);
      expect(
        AnniversaryService.veganYears(start, now: DateTime(2025, 3, 1)),
        4,
      );
      // Same year, after the anniversary month.
      expect(
        AnniversaryService.veganYears(start, now: DateTime(2025, 9, 1)),
        5,
      );
    });

    group('Feb 29 start (pinned to Feb 28 in non-leap years)', () {
      final start = DateTime(2024, 2, 29);

      test('ticks over on Feb 28 in a non-leap year', () {
        // Notification fires Feb 28, 2027 to celebrate 3 years; the count must
        // agree with that — not lag a year because 28 < 29.
        expect(
          AnniversaryService.veganYears(start, now: DateTime(2027, 2, 28, 10, 0)),
          3,
        );
      });

      test('has not ticked over on Feb 27 in a non-leap year', () {
        expect(
          AnniversaryService.veganYears(start, now: DateTime(2027, 2, 27, 10, 0)),
          2,
        );
      });

      test('ticks over on the real Feb 29 in a leap year', () {
        expect(
          AnniversaryService.veganYears(start, now: DateTime(2028, 2, 29, 10, 0)),
          4,
        );
      });
    });

    test('leap days within the span do not skew the count', () {
      // 2016 → 2024 spans two intervening Feb 29s; a day-count division could
      // drift, the calendar count cannot.
      final start = DateTime(2016, 1, 10);
      expect(
        AnniversaryService.veganYears(start, now: DateTime(2024, 1, 10, 10, 0)),
        8,
      );
    });
  });
}
