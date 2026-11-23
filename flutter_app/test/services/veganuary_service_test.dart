import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vegan_app/models/veganuary/veganuary_progress.dart';
import 'package:vegan_app/services/veganuary_service.dart';

void main() {
  const started = VeganuaryStartedDay(
      day: 3, screen: 1, screens: 5, quizAnswers: {}, openedCards: {});

  Future<void> deviceProgress(VeganuaryProgress progress) async {
    SharedPreferences.setMockInitialValues({
      'veganuary_progress': jsonEncode(progress.toJson()),
    });
  }

  group('VeganuaryService.mergeProgress (days from the server)', () {
    test('adds them, in a row from day 1, and says the path changed',
        () async {
      await deviceProgress(VeganuaryProgress(
          completedAt: {1: DateTime(2026, 1, 3)}, pickedMyths: {1: 'soja'}));

      final changed = await VeganuaryService.mergeProgress({
        1: DateTime(2026, 1, 2),
        2: DateTime(2026, 1, 4),
        5: DateTime(2026, 1, 8),
      }, {
        2: 'carences',
        5: 'b12',
      });

      expect(changed, isTrue);
      final progress = await VeganuaryService.loadProgress();
      expect(progress.completedAt,
          {1: DateTime(2026, 1, 2), 2: DateTime(2026, 1, 4)});
      expect(progress.pickedMyths, {1: 'soja', 2: 'carences'});
    });

    test('nothing new: unchanged', () async {
      await deviceProgress(
          VeganuaryProgress(completedAt: {1: DateTime(2026, 1, 3)}));
      expect(
          await VeganuaryService.mergeProgress({1: DateTime(2026, 1, 3)}, {}),
          isFalse);
    });

    test('at the same time as the day page, neither write is lost',
        () async {
      await deviceProgress(VeganuaryProgress(completedAt: {
        1: DateTime(2026, 1, 3),
        2: DateTime(2026, 1, 4),
      }));

      // The sync merges the server's days while the day page saves where
      // the user is in day 3
      await Future.wait([
        VeganuaryService.mergeProgress({1: DateTime(2026, 1, 1)}, {}),
        VeganuaryService.saveStarted(started),
      ]);

      final progress = await VeganuaryService.loadProgress();
      expect(progress.completedAt[1], DateTime(2026, 1, 1));
      expect(progress.started?.day, 3);
    });

    test('at the same time as a day done, neither write is lost', () async {
      await deviceProgress(
          VeganuaryProgress(completedAt: {1: DateTime(2026, 1, 3)}));

      await Future.wait([
        VeganuaryService.mergeProgress({1: DateTime(2026, 1, 1)}, {}),
        VeganuaryService.completeDay(2, mythId: 'soja'),
      ]);

      final progress = await VeganuaryService.loadProgress();
      expect(progress.completedAt.keys, containsAll([1, 2]));
      expect(progress.completedAt[1], DateTime(2026, 1, 1));
      expect(progress.pickedMyths[2], 'soja');
    });
  });
}
