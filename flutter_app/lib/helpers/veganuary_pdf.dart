import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart' show Color, Colors;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/veganuary/veganuary_content.dart';
import 'veganuary_images.dart';
import '../themes/app_colors.dart';

/// The Veganuary kept as PDF files (offered on the last day): the answers
/// to all the idées reçues, and the recipes. Built from the content itself,
/// so the text can be selected and the links opened.

/// Emojis aren't in the PDF's fonts: they'd come out as empty boxes.
final _emoji = RegExp(
  '[\u{1F000}-\u{1FAFF}\u{2300}-\u{23FF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]',
  unicode: true,
);

String _plain(String text) =>
    text.replaceAll(_emoji, '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();

PdfColor _pdfColor(Color color) => PdfColor.fromInt(color.toARGB32());

final _yellow = _pdfColor(kAccentYellow);
final _green = _pdfColor(kSemanticSuccess);
final _text = _pdfColor(kTextPrimary);

/// The grey of the app's secondary texts.
final _grey = _pdfColor(Colors.grey.shade600);

/// The fonts of the app: Baloo 2 for titles, Karla for the text (static
/// files: a PDF can't use the app's variable Karla), Baloo 2 as a fallback
/// for the few characters Karla lacks (CO₂).
class _Fonts {
  final pw.Font title;
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font fallback;
  final pw.MemoryImage logo;

  _Fonts(this.title, this.regular, this.bold, this.fallback, this.logo);

  static Future<_Fonts> load() async {
    Future<pw.Font> font(String asset) async =>
        pw.Font.ttf(await rootBundle.load(asset));
    final logo = await rootBundle.load('lib/assets/app_icon.png');
    return _Fonts(
      await font('fonts/Baloo2-SemiBold.ttf'),
      await font('fonts/pdf/Karla-Regular.ttf'),
      await font('fonts/pdf/Karla-Bold.ttf'),
      await font('fonts/Baloo2-Regular.ttf'),
      pw.MemoryImage(logo.buffer.asUint8List()),
    );
  }

  pw.TextStyle get body =>
      pw.TextStyle(fontSize: 10.5, color: _text, lineSpacing: 2.5);

  pw.TextStyle heading(double size, {PdfColor? color}) => pw.TextStyle(
        font: title,
        fontSize: size,
        color: color ?? _text,
        fontFallback: [fallback],
      );
}

const double _sideMargin = 48;

/// Between the margins.
final double _contentWidth = PdfPageFormat.a4.width - 2 * _sideMargin;

/// Every page: the course's name and the page number at the bottom; the
/// first one opens with the logo and [title].
Future<Uint8List> _document(
  String title,
  List<pw.Widget> Function(_Fonts fonts) content,
) async {
  final fonts = await _Fonts.load();
  final doc = pw.Document(title: 'Veganuary · $title', author: '321 Vegan');
  doc.addPage(pw.MultiPage(
    // The answers fill dozens of pages
    maxPages: 200,
    pageTheme: pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(_sideMargin, 44, _sideMargin, 40),
      theme: pw.ThemeData.withFont(
        base: fonts.regular,
        bold: fonts.bold,
        fontFallback: [fonts.fallback],
      ),
    ),
    footer: (context) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('31 premiers jours véganes · 321 Vegan',
              style: pw.TextStyle(fontSize: 8.5, color: _grey)),
          pw.Text('${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8.5, color: _grey)),
        ],
      ),
    ),
    build: (context) => [
      pw.Row(
        children: [
          pw.ClipRRect(
            horizontalRadius: 10,
            verticalRadius: 10,
            child: pw.Image(fonts.logo, width: 44, height: 44),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('31 premiers jours véganes', style: fonts.heading(12, color: _grey)),
                pw.Text(title, style: fonts.heading(24)),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 18),
      ...content(fonts),
    ],
  ));
  return doc.save();
}

/// "Semaine 2 · Alimentation & Social", with a green line under it.
pw.Widget _weekTitle(_Fonts fonts, VeganuaryWeek week) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 14, bottom: 10),
    padding: const pw.EdgeInsets.only(bottom: 4),
    decoration: pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _green, width: 2)),
    ),
    child: pw.Text('Semaine ${week.number} · ${_plain(week.title)}',
        style: fonts.heading(17)),
  );
}

/// [text] with its `**…**` parts in bold, as in the app.
pw.Widget _richText(_Fonts fonts, String text, {pw.TextStyle? style}) {
  final parts = _plain(text).split('**');
  return pw.RichText(
    text: pw.TextSpan(
      style: style ?? fonts.body,
      children: [
        for (int i = 0; i < parts.length; i++)
          if (parts[i].isNotEmpty)
            pw.TextSpan(
              text: parts[i],
              style: i.isOdd ? pw.TextStyle(font: fonts.bold) : null,
            ),
      ],
    ),
  );
}

pw.Widget _bullet(_Fonts fonts, String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 4,
          height: 4,
          margin: const pw.EdgeInsets.only(top: 5, right: 7),
          decoration:
              pw.BoxDecoration(color: _green, shape: pw.BoxShape.circle),
        ),
        pw.Expanded(child: _richText(fonts, text)),
      ],
    ),
  );
}

/// The answers to every idée reçue of the course, week by week, each with
/// its sources.
Future<File> buildVeganuaryAnswersPdf(List<VeganuaryWeek> weeks) async =>
    _save('Veganuary - Idées reçues', await veganuaryAnswersPdf(weeks));

@visibleForTesting
Future<Uint8List> veganuaryAnswersPdf(List<VeganuaryWeek> weeks) async {
  // A page number is only known once drawn: a first time to find them,
  // with the same contents (the numbers take the same room), then for good
  final pages = <String, int>{};
  List<pw.Widget> content(_Fonts fonts) => [
        ..._contents(fonts, weeks, pages),
        pw.NewPage(),
        for (final week in weeks)
          if (week.myths.isNotEmpty) ...[
            _weekTitle(fonts, week),
            for (final myth in week.myths)
              ..._answer(fonts, myth,
                  onPage: (page) => pages[myth.id] = page),
          ],
      ];
  await _document(_answersTitle, content);
  return _document(_answersTitle, content);
}

const _answersTitle = '31 réponses aux remarques';

/// "Sommaire": each answer's title and page, opening it.
List<pw.Widget> _contents(
    _Fonts fonts, List<VeganuaryWeek> weeks, Map<String, int> pages) {
  return [
    pw.Text('Sommaire', style: fonts.heading(17)),
    for (final week in weeks)
      if (week.myths.isNotEmpty) ...[
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: pw.Text('Semaine ${week.number} · ${_plain(week.title)}',
              style: fonts.body.copyWith(font: fonts.bold, color: _grey)),
        ),
        for (final myth in week.myths)
          pw.Link(
            destination: myth.id,
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(_plain(myth.label), style: fonts.body),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 3),
                      child: pw.Divider(
                          borderStyle: pw.BorderStyle.dotted,
                          thickness: 0.5,
                          color: _grey,
                          height: 1),
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.SizedBox(
                    width: 18,
                    child: pw.Text('${pages[myth.id] ?? ''}',
                        textAlign: pw.TextAlign.right,
                        style: fonts.body.copyWith(font: fonts.bold)),
                  ),
                ],
              ),
            ),
          ),
      ],
  ];
}

/// [child], reachable by a link to [name], telling the page it's drawn on.
class _PageMark extends pw.Anchor {
  final void Function(int page) onPage;

  _PageMark({required super.name, required this.onPage, super.child});

  @override
  void paint(pw.Context context) {
    super.paint(context);
    onPage(context.pageNumber);
  }
}

/// The idée reçue as people say it, then its answer, block by block (so a
/// long one can go on to the next page), then its sources.
List<pw.Widget> _answer(_Fonts fonts, VeganuaryMyth myth,
    {required void Function(int page) onPage}) {
  final answer = myth.answer;
  final blocks = [
    for (final block in answer.blocks)
      for (final widget in _block(fonts, block))
        pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6), child: widget),
  ];
  return [
    // The idée reçue never alone at the bottom of a page: kept with the
    // beginning of its answer
    pw.Inseparable(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 8),
          _PageMark(
            name: myth.id,
            onPage: onPage,
            child: pw.Text(_plain(myth.label), style: fonts.heading(15)),
          ),
          pw.SizedBox(height: 4),
          ...blocks.take(1),
        ],
      ),
    ),
    ...blocks.skip(1),
    if (answer.sources.isNotEmpty) ...[
      pw.Text('Sources', style: fonts.heading(11, color: _grey)),
      for (int i = 0; i < answer.sources.length; i++)
        pw.UrlLink(
          destination: answer.sources[i].url,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(
              '[${i + 1}] ${_plain(answer.sources[i].label)}',
              style: pw.TextStyle(fontSize: 8.5, color: _grey),
            ),
          ),
        ),
    ],
    pw.SizedBox(height: 10),
  ];
}

/// The blocks a written answer is made of; pictures and app links stay in
/// the app.
List<pw.Widget> _block(_Fonts fonts, VeganuaryBlock block) {
  return switch (block) {
    TextBlock(:final text) => [_richText(fonts, text)],
    BulletsBlock(:final items) => [
        for (final item in items) _bullet(fonts, item)
      ],
    CalloutBlock(:final text) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _pdfColor(kPrimaryTag),
            border: pw.Border.all(color: _green),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: _richText(fonts, text),
        ),
      ],
    GridBlock(:final items) => [
        for (final item in items)
          _bullet(
              fonts,
              item.text == null
                  ? '**${item.label}**'
                  : '**${item.label}** : ${item.text}'),
      ],
    ImageBlock() || AppLinkBlock() => const [],
  };
}

/// The recipes given, one per page, to keep or print: photo, author,
/// ingredients and steps. (Each recipe's own button gives an image, to
/// share.)
Future<File> buildVeganuaryRecipesPdf(List<RecipeStep> recipes) async =>
    _save('Veganuary - Recettes', await veganuaryRecipesPdf(recipes));

@visibleForTesting
Future<Uint8List> veganuaryRecipesPdf(List<RecipeStep> recipes) async {
  // Loaded before: building the pages can't wait
  final images = <String, pw.MemoryImage?>{
    for (final recipe in recipes)
      for (final src in [recipe.image, recipe.credit?.image])
        if (src != null) src: await _loadImage(src),
  };
  return _document(
    'Les recettes',
    (fonts) => [
      for (int i = 0; i < recipes.length; i++) ...[
        if (i > 0) pw.NewPage(),
        ..._recipe(fonts, recipes[i], images),
      ],
    ],
  );
}

/// From the app or the course's image cache; null when it can't be had
/// (offline, never shown): the recipe goes without.
Future<pw.MemoryImage?> _loadImage(String src) async {
  try {
    return pw.MemoryImage(await veganuaryImageBytes(src));
  } catch (_) {
    return null;
  }
}

/// Like the recipe's page in the app, one widget per line so a long recipe
/// can go on to the next page.
List<pw.Widget> _recipe(
  _Fonts fonts,
  RecipeStep recipe,
  Map<String, pw.MemoryImage?> images,
) {
  final photo = images[recipe.image];
  final credit = recipe.credit;
  final portrait = images[credit?.image];
  pw.Widget heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(text, style: fonts.heading(15)),
      );
  return [
    if (photo != null) _recipePhoto(photo),
    pw.SizedBox(height: 12),
    pw.Text(_plain(recipe.title), style: fonts.heading(20)),
    if (credit != null) ...[
      pw.SizedBox(height: 6),
      pw.Row(
        children: [
          if (portrait != null) ...[
            pw.ClipOval(child: pw.Image(portrait, width: 26, height: 26)),
            pw.SizedBox(width: 8),
          ],
          pw.Text('Une recette de ',
              style: fonts.body.copyWith(color: _grey)),
          pw.Text(_plain(credit.name),
              style: fonts.body.copyWith(font: fonts.bold)),
          for (final (label, url) in [
            (credit.blogLabel, credit.blog),
            (credit.instagramLabel, credit.instagram),
          ])
            if (label != null && url != null)
              pw.UrlLink(
                destination: url,
                child: pw.Text(' · $label',
                    style: fonts.body.copyWith(color: _grey)),
              ),
        ],
      ),
    ],
    ..._section(
      heading(recipe.servings == null
          ? 'Ingrédients'
          : 'Ingrédients pour ${_plain(recipe.servings!)}'),
      [
        for (final group in recipe.ingredients) ...[
          if (group.title != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4, bottom: 3),
              child: pw.Text(_plain(group.title!),
                  style: fonts.body.copyWith(font: fonts.bold)),
            ),
          for (final item in group.items) _bullet(fonts, item),
        ],
      ],
      // A group's title with its first ingredient
      keep: recipe.ingredients.firstOrNull?.title == null ? 1 : 2,
    ),
    ..._section(heading('Étapes'), [
      for (int i = 0; i < recipe.steps.length; i++)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 18,
                child: pw.Text('${i + 1}.',
                    style:
                        fonts.body.copyWith(font: fonts.bold, color: _yellow)),
              ),
              pw.Expanded(child: _richText(fonts, recipe.steps[i])),
            ],
          ),
        ),
    ]),
  ];
}

/// Whole, at its own proportions like in the app (a portrait photo isn't
/// cropped), no higher than a third of the page, and not enlarged past
/// about 110 dpi: the photos are small, they'd get blurry.
pw.Widget _recipePhoto(pw.MemoryImage photo) {
  const maxHeight = 260.0;
  const minDpi = 110;
  final pixelWidth = (photo.width ?? 1).toDouble();
  final pixelHeight = (photo.height ?? 1).toDouble();
  final width = [
    _contentWidth,
    maxHeight * pixelWidth / pixelHeight,
    pixelWidth * PdfPageFormat.inch / minDpi,
  ].reduce((a, b) => a < b ? a : b);
  return pw.Center(
    child: pw.ClipRRect(
      horizontalRadius: 12,
      verticalRadius: 12,
      child: pw.Image(photo,
          width: width, height: width * pixelHeight / pixelWidth),
    ),
  );
}

/// [heading] never alone at the bottom of a page: kept with the [keep]
/// first [lines].
List<pw.Widget> _section(pw.Widget heading, List<pw.Widget> lines,
    {int keep = 1}) {
  return [
    pw.Inseparable(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [heading, ...lines.take(keep)],
      ),
    ),
    ...lines.skip(keep),
  ];
}

Future<File> _save(String name, Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name.pdf');
  await file.writeAsBytes(bytes);
  return file;
}
