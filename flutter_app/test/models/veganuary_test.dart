import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vegan_app/models/veganuary/veganuary_content.dart';
import 'package:vegan_app/models/veganuary/veganuary_progress.dart';
import 'package:vegan_app/services/veganuary_service.dart';

void main() {
  group('VeganuaryProgress.stateOf', () {
    final monday = DateTime(2026, 1, 5, 10);
    final tuesday = DateTime(2026, 1, 6, 9);
    final thursday = DateTime(2026, 1, 8, 20);

    test('day 1 is open right away, the others are locked', () {
      const progress = VeganuaryProgress();
      expect(progress.stateOf(1, now: monday), VeganuaryDayState.available);
      expect(progress.stateOf(2, now: monday), VeganuaryDayState.locked);
    });

    test('the next day opens the day after, not the same day', () {
      final progress = const VeganuaryProgress().withCompleted(1, now: monday);
      expect(progress.stateOf(1, now: monday), VeganuaryDayState.completed);
      expect(progress.stateOf(2, now: monday), VeganuaryDayState.tomorrow);
      expect(progress.stateOf(2, now: tuesday), VeganuaryDayState.available);
    });

    test('missed days are caught up, in order', () {
      var progress = const VeganuaryProgress().withCompleted(1, now: monday);
      // Back on day 4: day 2 first...
      expect(progress.stateOf(2, now: thursday), VeganuaryDayState.available);
      expect(progress.stateOf(3, now: thursday), VeganuaryDayState.locked);
      // ...then days 3 and 4 the same day, but not day 5
      progress = progress.withCompleted(2, now: thursday);
      expect(progress.stateOf(3, now: thursday), VeganuaryDayState.available);
      progress = progress.withCompleted(3, now: thursday);
      expect(progress.stateOf(4, now: thursday), VeganuaryDayState.available);
      progress = progress.withCompleted(4, now: thursday);
      expect(progress.stateOf(5, now: thursday), VeganuaryDayState.tomorrow);
    });

    test('days open from the start, across a month end', () {
      final progress = const VeganuaryProgress()
          .withCompleted(1, now: DateTime(2026, 1, 30));
      expect(progress.unlockDate(4), DateTime(2026, 2, 2));
    });

    test('a day left halfway shows how far, until done', () {
      final started = const VeganuaryProgress().withStarted(
        const VeganuaryStartedDay(
          day: 1,
          screen: 2,
          screens: 4,
          quizAnswers: {0: 2},
          openedCards: {'Conserves'},
        ),
        mythId: 'soja',
      );
      expect(started.dayProgress(1), 0.5);
      expect(started.pickedMyths, {1: 'soja'});
      final restored = VeganuaryProgress.fromJson(
          jsonDecode(jsonEncode(started.toJson())) as Map<String, dynamic>);
      expect(restored.started?.screen, 2);
      // With what was done on its pages
      expect(restored.started?.quizAnswers, {0: 2});
      expect(restored.started?.openedCards, {'Conserves'});
      // Done: no longer started
      final done = started.withCompleted(1, mythId: 'soja', now: monday);
      expect(done.started, isNull);
      expect(done.dayProgress(1), 1);
    });

    test('survives a JSON round trip', () {
      final progress = const VeganuaryProgress()
          .withCompleted(1, mythId: 'soja', now: monday);
      final restored = VeganuaryProgress.fromJson(
          jsonDecode(jsonEncode(progress.toJson())) as Map<String, dynamic>);
      expect(restored.completedAt, {1: DateTime(2026, 1, 5)});
      expect(restored.pickedMyths, {1: 'soja'});
    });
  });

  // A mistake in a week's JSON would leave the whole tab on "Le contenu
  // n'a pas pu être chargé": caught here instead.
  group('Recipe', () {
    RecipeStep parse(Object? servings, List<Object> ingredients) =>
        VeganuaryStep.fromJson({
          'type': 'recipe',
          'title': 'Tarte',
          'servings': servings,
          'ingredients': ingredients,
          'steps': <String>[],
        }) as RecipeStep;

    test('servings: people or a text', () {
      expect(parse(1, []).servings, '1 personne');
      expect(parse(4, []).servings, '4 personnes');
      expect(parse('une tarte', []).servings, 'une tarte');
      expect(parse(null, []).servings, isNull);
    });

    test('ingredients: lines in a row make an untitled group', () {
      final recipe = parse(2, [
        'Sel',
        'Poivre',
        {
          'title': 'Pour la pâte',
          'items': ['Farine']
        },
        'Graines',
      ]);
      expect([for (final g in recipe.ingredients) g.title],
          [null, 'Pour la pâte', null]);
      expect([
        for (final g in recipe.ingredients) g.items
      ], [
        ['Sel', 'Poivre'],
        ['Farine'],
        ['Graines'],
      ]);
    });
  });

  group('Bundled content', () {
    test('every week file is listed in the service and in pubspec.yaml', () {
      final files = Directory('lib/assets/veganuary')
          .listSync()
          .map((file) => file.path.replaceAll(r'\', '/'))
          .where((path) => path.endsWith('.json'))
          .toSet();
      expect(VeganuaryService.weekAssets.toSet(), files);
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final asset in VeganuaryService.weekAssets) {
        expect(pubspec, contains('- $asset'), reason: asset);
      }
    });

    final weeks = [
      for (final asset in VeganuaryService.weekAssets)
        VeganuaryWeek.fromJson(
            jsonDecode(File(asset).readAsStringSync()) as Map<String, dynamic>),
    ];

    test('weeks and days follow each other from 1', () {
      final days = [for (final week in weeks) ...week.days];
      expect([for (final week in weeks) week.number],
          [for (int i = 1; i <= weeks.length; i++) i]);
      expect([for (final day in days) day.number],
          [for (int i = 1; i <= days.length; i++) i]);
      expect(days.length, lessThanOrEqualTo(VeganuaryService.totalDays));
    });

    test('every image of the content exists and is in pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      Iterable<String> assetsIn(Object? json) sync* {
        if (json is String && json.startsWith('lib/assets/')) yield json;
        if (json is List) {
          for (final value in json) {
            yield* assetsIn(value);
          }
        }
        if (json is Map) {
          for (final value in json.values) {
            yield* assetsIn(value);
          }
        }
      }

      for (final file in VeganuaryService.weekAssets) {
        for (final asset
            in assetsIn(jsonDecode(File(file).readAsStringSync()))) {
          expect(File(asset).existsSync(), isTrue, reason: '$file : $asset');
          final folder = asset.substring(0, asset.lastIndexOf('/') + 1);
          expect(
            pubspec.contains('- $asset') || pubspec.contains('- $folder\n'),
            isTrue,
            reason: '$asset absent de pubspec.yaml',
          );
        }
      }
    });

    for (final week in weeks) {
      test('week ${week.number}: one idée reçue per day, all with a recap', () {
        final mythDays = week.days
            .where((day) => day.steps.any((step) => step is MythStep))
            .length;
        expect(week.myths.length, greaterThanOrEqualTo(mythDays));
        expect(
            week.myths.map((m) => m.id).toSet(), hasLength(week.myths.length));
        expect(week.days.every((day) => day.recap.isNotEmpty), isTrue);
        expect(week.myths.every((myth) => myth.recap != null), isTrue);
      });

      test('week ${week.number}: every [n] has its source on the page', () {
        // With the details of their grid cards, which have their own sources
        Iterable<VeganuaryInfo> withDetails(VeganuaryInfo page) sync* {
          yield page;
          for (final grid in page.blocks.whereType<GridBlock>()) {
            for (final item in grid.items) {
              if (item.details != null) yield* withDetails(item.details!);
            }
          }
        }

        final pages = [
          for (final day in week.days)
            for (final step in day.steps.whereType<InfoStep>())
              ...withDetails(step.info),
          for (final myth in week.myths) ...withDetails(myth.answer),
        ];
        for (final page in pages) {
          final texts = [
            for (final block in page.blocks)
              ...switch (block) {
                TextBlock(:final text) => [text],
                BulletsBlock(:final items) => items,
                _ => <String>[],
              },
          ];
          for (final match in RegExp(r'\[(\d+)\]').allMatches(texts.join())) {
            final n = int.parse(match[1]!);
            expect(n, inInclusiveRange(1, page.sources.length),
                reason: '${page.title} : [$n]');
          }
          for (final source in page.sources) {
            expect(Uri.parse(source.url).host, isNotEmpty,
                reason: '${page.title} : ${source.url}');
          }
        }
      });

      test('week ${week.number}: every quiz has a right answer', () {
        for (final day in week.days) {
          for (final quiz in day.steps.whereType<QuizStep>()) {
            expect(
              quiz.choices.any((choice) => choice.result == QuizResult.right),
              isTrue,
              reason: 'Jour ${day.number} : ${quiz.question}',
            );
          }
        }
      });
    }
  });
}
