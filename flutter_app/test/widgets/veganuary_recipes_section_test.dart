import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vegan_app/models/veganuary/veganuary_content.dart';
import 'package:vegan_app/models/veganuary/veganuary_progress.dart';
import 'package:vegan_app/pages/app_pages/Veganuary/veganuary_recipe_page.dart';
import 'package:vegan_app/widgets/veganuary/veganuary_recipes_section.dart';

VeganuaryDay _day(int number, {String? recipe, String? author}) => VeganuaryDay(
      number: number,
      icon: VeganuaryDayIcon.info,
      steps: [
        if (recipe != null)
          RecipeStep(
            title: recipe,
            ingredients: const [],
            steps: const [],
            credit: author == null ? null : RecipeCredit(name: author),
          ),
      ],
    );

final _weeks = [
  VeganuaryWeek(
    number: 1,
    title: 'Semaine 1',
    myths: const [],
    days: [_day(1), _day(2), _day(3, recipe: 'Tarte aux poireaux')],
  ),
  VeganuaryWeek(
    number: 2,
    title: 'Semaine 2',
    myths: const [],
    days: [
      _day(8),
      _day(9, recipe: 'Sauce aux aubergines', author: 'Aude · The Greenquest'),
    ],
  ),
];

Future<void> _pump(WidgetTester tester, Set<int> completed) async {
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(1170, 2532),
    builder: (_, __) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: VeganuaryRecipesSection(
            weeks: _weeks,
            progress: VeganuaryProgress(completedAt: {
              for (final day in completed) day: DateTime(2027, 1, day),
            }),
          ),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('lists every recipe of the course with its day', (tester) async {
    await _pump(tester, {1, 2, 3});

    expect(find.text('Tarte aux poireaux'), findsOneWidget);
    expect(find.text('Jour 3'), findsOneWidget);
    expect(find.text('Sauce aux aubergines'), findsOneWidget);
    expect(find.text('Jour 9'), findsOneWidget);
    // Credited only when it comes from someone
    expect(find.text('par Aude · The Greenquest'), findsOneWidget);
    expect(find.textContaining('par '), findsOneWidget);
  });

  testWidgets('no download button before a recipe is unlocked', (tester) async {
    await _pump(tester, {1});
    expect(find.text('Tout télécharger'), findsNothing);

    await _pump(tester, {1, 2, 3});
    expect(find.text('Tout télécharger'), findsOneWidget);
  });

  testWidgets('a locked recipe says when it unlocks', (tester) async {
    await _pump(tester, {1, 2, 3});

    await tester.tap(find.text('Sauce aux aubergines'));
    await tester.pump();

    expect(find.text('Cette recette se débloque au jour 9.'), findsOneWidget);
    expect(find.byType(VeganuaryRecipePage), findsNothing);
  });

  testWidgets('an unlocked recipe opens its page', (tester) async {
    await _pump(tester, {1, 2, 3});

    await tester.tap(find.text('Tarte aux poireaux'));
    await tester.pumpAndSettle();

    expect(find.byType(VeganuaryRecipePage), findsOneWidget);
  });
}
