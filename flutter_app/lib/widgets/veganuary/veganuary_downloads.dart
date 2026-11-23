import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../helpers/image_capture.dart';
import '../../helpers/veganuary_pdf.dart';
import '../../models/veganuary/veganuary_content.dart';
import '../../services/veganuary_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_spacing.dart';
import '../shared/sheet_option_tile.dart';

/// What the Veganuary can be kept as, at its end.
enum VeganuaryDownload {
  /// A PDF of the answers to all the idées reçues.
  answers,

  /// A PDF of the recipes unlocked.
  recipes,
}

/// The recipes, in a PDF (one per page), through the share sheet. Each
/// recipe's own button gives an image instead, to share.
Future<void> shareVeganuaryRecipes(
  BuildContext buttonContext,
  List<RecipeStep> recipes,
) async {
  if (recipes.isEmpty) return;
  final file = await buildVeganuaryRecipesPdf(recipes);
  if (!buttonContext.mounted) return;
  await shareFiles(buttonContext, [file], mimeType: 'application/pdf');
}

/// A card keeping part of the course as a PDF, through the share sheet. Reads the content and progress itself.
class VeganuaryDownloadCard extends StatefulWidget {
  final VeganuaryDownload download;

  /// Its title; a default one for [download] when null.
  final String? label;

  const VeganuaryDownloadCard({super.key, required this.download, this.label});

  @override
  State<VeganuaryDownloadCard> createState() => _VeganuaryDownloadCardState();
}

class _VeganuaryDownloadCardState extends State<VeganuaryDownloadCard> {
  bool _preparing = false;

  String get _title =>
      widget.label ??
      switch (widget.download) {
        VeganuaryDownload.answers => 'Les réponses aux idées reçues',
        VeganuaryDownload.recipes => 'Les recettes',
      };

  String get _detail => switch (widget.download) {
        _ when _preparing => 'Préparation…',
        VeganuaryDownload.answers =>
          'Toutes les idées reçues et leurs sources, en PDF',
        VeganuaryDownload.recipes => 'Les recettes du parcours, en PDF',
      };

  IconData get _icon => switch (widget.download) {
        VeganuaryDownload.answers => FontAwesomeIcons.comments,
        VeganuaryDownload.recipes => FontAwesomeIcons.bowlFood,
      };

  Future<void> _download(BuildContext buttonContext) async {
    if (_preparing) return;
    setState(() => _preparing = true);
    try {
      final weeks = await VeganuaryService.loadWeeks();
      final progress = await VeganuaryService.loadProgress();
      if (widget.download == VeganuaryDownload.recipes) {
        if (!mounted || !buttonContext.mounted) return;
        await shareVeganuaryRecipes(buttonContext, [
          for (final week in weeks)
            for (final day in week.days)
              if (progress.isCompleted(day.number))
                ...day.steps.whereType<RecipeStep>(),
        ]);
        return;
      }
      final file = await buildVeganuaryAnswersPdf(weeks);
      if (!buttonContext.mounted) return;
      await shareFiles(buttonContext, [file], mimeType: 'application/pdf');
    } catch (e) {
      debugPrint('Veganuary download failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Le téléchargement n'a pas pu être préparé, "
              'réessayez.'),
          backgroundColor: kSemanticError,
        ));
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Own context: the share popover (iPad) points at the card
    return Builder(
      builder: (buttonContext) => SheetOptionTile(
        card: true,
        icon: _icon,
        color: kAccentYellow,
        title: _title,
        detail: _detail,
        onTap: () => _download(buttonContext),
      ),
    );
  }
}

/// The three downloads one under the other (under the finish line, once
/// the course is done).
class VeganuaryDownloads extends StatelessWidget {
  const VeganuaryDownloads({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final download in VeganuaryDownload.values) ...[
          if (download != VeganuaryDownload.values.first)
            SizedBox(height: AppSpacing.item),
          VeganuaryDownloadCard(download: download),
        ],
      ],
    );
  }
}
