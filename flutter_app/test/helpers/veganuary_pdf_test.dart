import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vegan_app/helpers/veganuary_pdf.dart';
import 'package:vegan_app/models/veganuary/veganuary_content.dart';

import '../veganuary_week_files.dart';

/// The PDFs of the last day, built from the local copy of the content when
/// there's one (empty otherwise): a font missing from the assets or a block
/// not handled would show here.
/// `VEGANUARY_PDF_OUT=/some/folder flutter test test/helpers/veganuary_pdf_test.dart`
/// also writes it there, to look at.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final weeks = [
    for (final asset in veganuaryWeekFiles())
      VeganuaryWeek.fromJson(
          jsonDecode(File(asset).readAsStringSync()) as Map<String, dynamic>),
  ];

  void keep(String name, List<int> bytes) {
    final out = Platform.environment['VEGANUARY_PDF_OUT'];
    if (out != null) File('$out/$name.pdf').writeAsBytesSync(bytes);
  }

  test('the answers PDF', () async {
    final bytes = await veganuaryAnswersPdf(weeks);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    keep('Parcours 321 Vegan - Idées reçues', bytes);
  });

  test('the recipes PDF', () async {
    final bytes = await veganuaryRecipesPdf([
      for (final week in weeks)
        for (final day in week.days) ...day.steps.whereType<RecipeStep>(),
    ]);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    keep('Parcours 321 Vegan - Recettes', bytes);
  });
}
