import 'package:flutter_test/flutter_test.dart';
import 'package:vegan_app/models/veganuary/veganuary_progress.dart';
import 'package:vegan_app/services/veganuary_reminder_service.dart';

void main() {
  group('VeganuaryReminderService.plannedDates', () {
    // Day 1 done on Monday 5 January
    final dayOneDone = const VeganuaryProgress()
        .withCompleted(1, now: DateTime(2026, 1, 5, 20));

    test('none before day 1 is done', () {
      expect(
        VeganuaryReminderService.plannedDates(const VeganuaryProgress(),
            now: DateTime(2026, 1, 5, 8)),
        isEmpty,
      );
    });

    test('from the morning the next day opens, at 10h, a week ahead', () {
      final dates = VeganuaryReminderService.plannedDates(dayOneDone,
          now: DateTime(2026, 1, 5, 21));
      expect(dates.first, DateTime(2026, 1, 6, 10));
      expect(dates, hasLength(7));
      expect(dates.last, DateTime(2026, 1, 12, 10));
    });

    test('this morning too when a day is open, if before 10h', () {
      final dates = VeganuaryReminderService.plannedDates(dayOneDone,
          now: DateTime(2026, 1, 7, 9));
      expect(dates.first, DateTime(2026, 1, 7, 10));
    });

    test('not this morning once past 10h', () {
      final dates = VeganuaryReminderService.plannedDates(dayOneDone,
          now: DateTime(2026, 1, 7, 11));
      expect(dates.first, DateTime(2026, 1, 8, 10));
    });

    test('not this morning when today\'s day was already opened', () {
      final dates = VeganuaryReminderService.plannedDates(
        dayOneDone,
        lastOpened: DateTime(2026, 1, 7),
        now: DateTime(2026, 1, 7, 8),
      );
      expect(dates.first, DateTime(2026, 1, 8, 10));
    });

    test('none once the course is over', () {
      var progress = const VeganuaryProgress();
      for (int day = 1; day <= 31; day++) {
        progress = progress.withCompleted(day, now: DateTime(2026, 1, day));
      }
      expect(
        VeganuaryReminderService.plannedDates(progress,
            now: DateTime(2026, 2, 1, 8)),
        isEmpty,
      );
    });
  });
}
