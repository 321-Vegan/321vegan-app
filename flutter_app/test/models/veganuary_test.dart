import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vegan_app/models/veganuary/veganuary_content.dart';
import 'package:vegan_app/models/veganuary/veganuary_progress.dart';
import 'package:vegan_app/services/veganuary_service.dart';

import '../veganuary_week_files.dart';

void main() {
  group('VeganuaryProgress.stateOf', () {
    // Out of January: the January calendar rule is tested below.
    final monday = DateTime(2026, 2, 2, 10);
    final tuesday = DateTime(2026, 2, 3, 9);
    final thursday = DateTime(2026, 2, 5, 20);

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
          .withCompleted(1, now: DateTime(2026, 3, 30));
      expect(progress.unlockDate(4), DateTime(2026, 4, 2));
    });

    test('started in January, day N opens on January N', () {
      final jan5 = DateTime(2026, 1, 5, 10);
      var progress = const VeganuaryProgress().withCompleted(1, now: jan5);
      // Days 2 to 5 right away, one after the other...
      for (var day = 2; day <= 5; day++) {
        expect(progress.stateOf(day, now: jan5), VeganuaryDayState.available);
        expect(progress.stateOf(day + 1, now: jan5), VeganuaryDayState.locked);
        progress = progress.withCompleted(day, now: jan5);
      }
      // ...then one a day, by the calendar
      expect(progress.stateOf(6, now: jan5), VeganuaryDayState.tomorrow);
      expect(progress.unlockDate(6), DateTime(2026, 1, 6));
      expect(progress.unlockDate(31), DateTime(2026, 1, 31));
    });

    test('started on December 31, days open from the start', () {
      final progress = const VeganuaryProgress()
          .withCompleted(1, now: DateTime(2026, 12, 31));
      expect(progress.unlockDate(2), DateTime(2027, 1, 1));
      expect(progress.unlockDate(5), DateTime(2027, 1, 4));
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
      expect(restored.completedAt, {1: DateTime(2026, 2, 2)});
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

    test('credit: links written out for the downloaded image', () {
      final credit = RecipeCredit.fromJson({
        'name': 'Aude · The Greenquest',
        'blog': 'https://www.thegreenquest.org/fr/sauce/',
        'instagram': 'https://www.instagram.com/the_greenquest/',
      });
      expect(credit.blogLabel, 'thegreenquest.org');
      expect(credit.instagramLabel, '@the_greenquest');
      expect(parse(2, []).credit, isNull);
    });
  });

  group('Recipe file name', () {
    RecipeStep recipe(String title) =>
        RecipeStep(title: title, ingredients: const [], steps: const []);

    test('follows the title, without accents nor punctuation', () {
      expect(
          recipe('Tarte aux poireaux').fileName, 'recette-tarte-aux-poireaux');
      expect(
          recipe('Lentilles vertes, potiron rôti, noisettes et tofu fumé')
              .fileName,
          'recette-lentilles-vertes-potiron-roti-noisettes-et-tofu-fume');
      expect(recipe('Bœuf bourguignon végétal !').fileName,
          'recette-boeuf-bourguignon-vegetal');
    });

    test('has a name even without letters in the title', () {
      expect(recipe('🍰').fileName, 'recette');
    });
  });

  group('Content from the API', () {
    // A week written for a later version of the app: a block, a link and a
    // step of kinds this one doesn't know
    Map<String, dynamic> week() => {
          'number': 1,
          'title': 'API',
          'days': [
            {
              'number': 1,
              'icon': 'a-new-icon',
              'steps': [
                {
                  'type': 'info',
                  'title': 'Info',
                  'blocks': [
                    {'type': 'text', 'text': 'Kept'},
                    {'type': 'video', 'src': 'https://…'},
                    {'type': 'app_link', 'label': 'New', 'target': 'new'},
                  ],
                },
                {'type': 'game'},
              ],
            },
          ],
        };

    test('the local files refuse what the app doesn\'t know', () {
      expect(() => VeganuaryWeek.fromJson(week()),
          throwsA(isA<UnknownVeganuaryContent>()));
    });

    test('downloaded, it leaves it out and keeps the rest', () {
      final day = VeganuaryWeek.fromRemoteJson(week()).days.single;
      expect(day.icon, VeganuaryDayIcon.info);
      final info = (day.steps.single as InfoStep).info;
      expect(info.blocks.single, isA<TextBlock>());
      // Strict again afterwards
      expect(() => VeganuaryWeek.fromJson(week()), throwsFormatException);
    });
  });

  group('Grid card links', () {
    test('are read from the JSON, none when absent', () {
      final withLinks = GridItem.fromJson({
        'label': '321 Vegan',
        'links': [
          'https://www.instagram.com/321vegan.app/',
          'https://321vegan.fr',
        ],
      });
      expect([for (final link in withLinks.links) link.label],
          ['@321vegan.app', '321vegan.fr']);
      expect(withLinks.details, isNull);
      expect(GridItem.fromJson({'label': 'Sans lien'}).links, isEmpty);
    });

    test('can have their own label', () {
      final podcast = GridItem.fromJson({
        'label': 'Comme un poisson dans l\'eau',
        'links': [
          {'label': 'Écouter', 'url': 'https://linktr.ee/poissonpodcast'},
        ],
      });
      expect(podcast.links.single.label, 'Écouter');
      expect(podcast.links.single.url, 'https://linktr.ee/poissonpodcast');
    });

    test('are written out: @account on Instagram, the site otherwise', () {
      expect(linkLabel('https://www.instagram.com/the_greenquest/'),
          '@the_greenquest');
      expect(linkLabel('https://www.instagram.com/'), 'Instagram');
      expect(linkLabel('https://www.thegreenquest.org/fr/recette/'),
          'thegreenquest.org');
    });
  });

  // The course's JSON isn't in the repository (it's on the API): a local
  // copy of it, when there's one (git-ignored), is checked before being
  // imported, strictly (a typo fails here instead of being left out).
  final weekFiles = veganuaryWeekFiles();
  group('Local content files', skip: weekFiles.isEmpty, () {
    final weeks = [
      for (final file in weekFiles)
        VeganuaryWeek.fromJson(
            jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>),
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

      for (final file in weekFiles) {
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
        // But the last one, "Le mot de la fin"
        expect(
          week.days
              .where((day) => day.number < VeganuaryService.totalDays)
              .every((day) => day.recap.isNotEmpty),
          isTrue,
        );
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
