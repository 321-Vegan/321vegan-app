import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../helpers/pdf_download.dart';
import '../../helpers/veganuary_pdf.dart';
import '../../models/veganuary/veganuary_content.dart';
import '../../services/veganuary_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_spacing.dart';
import '../shared/icon_snack_bar.dart';
import '../shared/sheet_option_tile.dart';
import 'veganuary_certificate.dart';

/// What the Veganuary can be kept as, at its end.
enum VeganuaryDownload {
  /// A PDF of the answers to all the idées reçues.
  answers,

  /// A PDF of the recipes unlocked.
  recipes,
}

/// The recipes, in a PDF (one per page), downloaded (see [downloadPdf]).
/// Each recipe's own button gives an image instead, to share.
Future<void> downloadVeganuaryRecipes(
  BuildContext buttonContext,
  List<RecipeStep> recipes,
) async {
  if (recipes.isEmpty) return;
  final file = await buildVeganuaryRecipesPdf(recipes);
  if (!buttonContext.mounted) return;
  await downloadPdf(buttonContext, file);
}

/// Runs [prepare] (a file built, then downloaded), saying so if it fails.
Future<void> runVeganuaryDownload(
    BuildContext context, Future<void> Function() prepare) async {
  try {
    await prepare();
  } catch (e) {
    debugPrint('Veganuary download failed: $e');
    if (context.mounted) {
      showResultSnackBar(context,
          "Le téléchargement n'a pas pu être préparé, réessayez.",
          error: true);
    }
  }
}

/// A card keeping part of the course as a PDF (see [downloadPdf]). Reads the content and progress itself.
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
    await runVeganuaryDownload(context, () async {
      final weeks = await VeganuaryService.loadWeeks();
      if (widget.download == VeganuaryDownload.recipes) {
        final progress = await VeganuaryService.loadProgress();
        if (!buttonContext.mounted) return;
        await downloadVeganuaryRecipes(
            buttonContext, progress.unlockedRecipes(weeks));
        return;
      }
      final file = await buildVeganuaryAnswersPdf(weeks);
      if (!buttonContext.mounted) return;
      await downloadPdf(buttonContext, file);
    });
    if (mounted) setState(() => _preparing = false);
  }

  @override
  Widget build(BuildContext context) {
    // Own context: the share popover (iPad, fallback) points at the card
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

/// The certificate, then the downloads, one under the other (under the
/// finish line, once the course is done).
class VeganuaryDownloads extends StatelessWidget {
  const VeganuaryDownloads({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final download in VeganuaryDownload.values) ...[
          SizedBox(height: AppSpacing.item),
          VeganuaryDownloadCard(download: download),
        ],
        SheetOptionTile(
          card: true,
          icon: FontAwesomeIcons.trophy,
          color: kAccentYellow,
          title: 'Mon certificat',
          detail: 'À votre nom, à partager ou à garder',
          onTap: () => showVeganuaryCertificateSheet(context),
        ),
      ],
    );
  }
}
