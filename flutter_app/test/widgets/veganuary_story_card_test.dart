import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vegan_app/widgets/veganuary/veganuary_story_share.dart';

/// The app's fonts, so the texts take their real width (the test font's
/// square glyphs are much wider).
Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(
        Future.value(ByteData.sublistView(File(file).readAsBytesSync())));
  }
  await loader.load();
}

Future<void> _pumpStory(WidgetTester tester, int day, {int? weekDone}) async {
  await tester.binding.setSurfaceSize(VeganuaryStoryCard.size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(1170, 2532),
    builder: (_, __) => MaterialApp(
      home: Material(
        child: VeganuaryStoryCard(
          day: day,
          totalDays: 31,
          completedDays: {for (var d = 1; d <= day; d++) d},
          image: 'lib/assets/images/characters/avocado.webp',
          weekDone: weekDone,
        ),
      ),
    ),
  ));
}

void main() {
  setUpAll(() async {
    await _loadFont('Baloo2', [
      'fonts/Baloo2-Bold.ttf',
      'fonts/Baloo2-ExtraBold.ttf',
    ]);
    await _loadFont('Karla', ['fonts/Karla-VariableFont.ttf']);
  });

  testWidgets('first day', (tester) async {
    await _pumpStory(tester, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('jour de Veganuary !'), findsOneWidget);
  });

  // The tallest one: with the line of the week done
  testWidgets('a week done fits in the story', (tester) async {
    await _pumpStory(tester, 14, weekDone: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('jours de Veganuary !'), findsOneWidget);
    expect(find.text('Semaine 2 terminée !'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
  });

  testWidgets('last day', (tester) async {
    await _pumpStory(tester, 31, weekDone: 5);
    expect(tester.takeException(), isNull);
    expect(find.text('jours : défi relevé !'), findsOneWidget);
    // The challenge is over: no "Semaine 5 terminée !"
    expect(find.textContaining('Semaine'), findsNothing);
  });

  testWidgets('says the app is on iOS and Android', (tester) async {
    await _pumpStory(tester, 3);
    expect(find.text('Disponible sur iOS et Android'), findsOneWidget);
  });
}
