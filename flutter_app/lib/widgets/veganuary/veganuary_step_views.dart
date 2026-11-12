import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/veganuary/veganuary_content.dart';
import '../../services/veganuary_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/info_box.dart';

/// Pages of a Veganuary day: one view per kind of step, shown by
/// VeganuaryDayPage between its progress bar and its button.

TextStyle get _bodyStyle => AppTextStyles.bodyRegular15.copyWith(
      color: Colors.grey[700],
      height: 1.4,
    );

/// [text] with its `**…**` parts in bold.
class VeganuaryRichText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  const VeganuaryRichText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final base = style ?? _bodyStyle;
    final parts = text.split('**');
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          // Odd parts were between two `**`
          for (int i = 0; i < parts.length; i++)
            if (parts[i].isNotEmpty)
              TextSpan(
                text: parts[i],
                style: i.isOdd
                    ? const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: kTextPrimary,
                      )
                    : null,
              ),
        ],
      ),
      textAlign: textAlign,
    );
  }
}

/// Image of the content: an asset path, or a URL.
class VeganuaryImage extends StatelessWidget {
  final String src;
  final double? height;
  final BoxFit fit;

  const VeganuaryImage(
    this.src, {
    super.key,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (src.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: src,
        height: height,
        width: double.infinity,
        fit: fit,
        placeholder: (context, url) =>
            Container(height: height ?? 450.h, color: kBorderDefault),
        errorWidget: (context, url, error) => const SizedBox.shrink(),
      );
    }
    return Image.asset(
      src,
      height: height,
      width: double.infinity,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

/// Scrolls when longer than the screen, centered vertically otherwise.
class _CenteredScroll extends StatelessWidget {
  final Widget child;

  const _CenteredScroll({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal, vertical: 48.h),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 96.h),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class VeganuaryInfoView extends StatelessWidget {
  final VeganuaryInfo info;

  const VeganuaryInfoView({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return _CenteredScroll(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            info.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.baloo36,
          ),
          for (final block in info.blocks) ...[
            SizedBox(height: AppSpacing.section),
            _VeganuaryBlockView(block: block),
          ],
        ],
      ),
    );
  }
}

class _VeganuaryBlockView extends StatelessWidget {
  final VeganuaryBlock block;

  const _VeganuaryBlockView({required this.block});

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      TextBlock(:final text) => VeganuaryRichText(text),
      BulletsBlock(:final items) => Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(height: AppSpacing.section),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•', style: _bodyStyle),
                  SizedBox(width: 30.w),
                  Expanded(child: VeganuaryRichText(items[i])),
                ],
              ),
            ],
          ],
        ),
      ImageBlock(:final src, :final caption) => Column(
          children: [
            ClipSmoothRect(
              radius: squircleRadius(48.r),
              child: VeganuaryImage(src),
            ),
            if (caption != null) ...[
              SizedBox(height: 18.h),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyItalic12
                    .copyWith(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      CalloutBlock(:final text) => InfoBox(text: text),
    };
  }
}

/// The idées reçues to pick from.
class VeganuaryMythPicker extends StatelessWidget {
  final String title;
  final List<VeganuaryMyth> myths;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  const VeganuaryMythPicker({
    super.key,
    required this.title,
    required this.myths,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal, vertical: 48.h),
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.baloo26
              .copyWith(fontWeight: FontWeight.w700, height: 1.15),
        ),
        SizedBox(height: AppSpacing.section),
        for (final myth in myths) ...[
          _MythOption(
            label: myth.label,
            selected: myth.id == selectedId,
            onTap: () => onSelected(myth.id),
          ),
          SizedBox(height: AppSpacing.item),
        ],
      ],
    );
  }
}

class _MythOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MythOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 51.w, vertical: 54.h),
          decoration: ShapeDecoration(
            color:
                selected ? kSecondaryTag : Colors.white.withValues(alpha: 0.6),
            shape: squircleBorder(
              radius: 48.r,
              side: BorderSide(
                color: selected ? kAccentYellow : kBorderDefault,
                width: selected ? 2 : 1.5,
              ),
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 66.w,
                height: 66.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? kAccentYellow : Colors.transparent,
                  border: selected
                      ? null
                      : Border.all(color: kBorderDefault, width: 2),
                ),
                child: selected
                    ? Icon(Icons.check_rounded,
                        color: Colors.white, size: 46.sp)
                    : null,
              ),
              SizedBox(width: 39.w),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyRegular15
                      .copyWith(color: selected ? kAccentYellow : kTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The week's recipe. The user won't necessarily cook it right now, so
/// it's offered to download as an image (through the share sheet, which
/// can save it to the photos), like the vegan anniversary card.
class VeganuaryRecipeView extends StatefulWidget {
  final RecipeStep recipe;

  const VeganuaryRecipeView({super.key, required this.recipe});

  @override
  State<VeganuaryRecipeView> createState() => _VeganuaryRecipeViewState();
}

class _VeganuaryRecipeViewState extends State<VeganuaryRecipeView> {
  // Wraps the recipe (not the download invitation) so it can be captured
  // to an image identical to what's shown. In a SingleChildScrollView, not
  // a ListView, so the parts scrolled out are laid out and captured too.
  final GlobalKey _recipeKey = GlobalKey();
  bool _downloading = false;

  RecipeStep get recipe => widget.recipe;

  /// Render the recipe [RepaintBoundary] to a PNG file in the temp dir.
  Future<File?> _capturedRecipeFile() async {
    final boundary =
        _recipeKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) return null;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/recette-veganuary.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  Future<void> _download(BuildContext buttonContext) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final file = await _capturedRecipeFile();
      if (file == null || !buttonContext.mounted) return;

      // sharePositionOrigin is required for the iPad popover.
      final box = buttonContext.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '${recipe.title} : la recette du Veganuary de 321 Vegan 🌱 '
            'https://321vegan.fr',
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 24.h, bottom: 48.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
            child: _buildDownloadInvitation(),
          ),
          RepaintBoundary(
            key: _recipeKey,
            // Opaque, for the image not to come out transparent
            child: ColoredBox(
              color: kBackgroundGradientBottom,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.section),
                child: _buildRecipe(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadInvitation() {
    return Container(
      padding: EdgeInsets.all(45.w),
      decoration: ShapeDecoration(
        color: kSecondaryTag,
        shape: squircleBorder(
          radius: 48.r,
          side: const BorderSide(color: kAccentYellow),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Pas le temps de cuisiner aujourd’hui ? Gardez la recette '
              'pour plus tard.',
              style: AppTextStyles.bodyMedium13.copyWith(color: kTextPrimary),
            ),
          ),
          SizedBox(width: 30.w),
          // Own context: the share popover (iPad) points at the button
          Builder(
            builder: (buttonContext) => AppButton(
              label: 'Télécharger',
              icon: Icons.download_rounded,
              compact: true,
              isLoading: _downloading,
              backgroundColor: kAccentYellow,
              disabledBackgroundColor: kAccentYellow,
              onPressed: () => _download(buttonContext),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipe(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (recipe.image != null)
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
            child: ClipSmoothRect(
              radius: squircleRadius(48.r),
              child: VeganuaryImage(recipe.image!, height: 600.h),
            ),
          ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (recipe.image != null) SizedBox(height: AppSpacing.section),
              Text(
                'La recette végane de la semaine !',
                textAlign: TextAlign.center,
                style: AppTextStyles.baloo22.copyWith(color: Colors.grey[600]),
              ),
              SizedBox(height: AppSpacing.afterTitle),
              Text(
                recipe.title,
                textAlign: TextAlign.center,
                style: AppTextStyles.baloo36,
              ),
              SizedBox(height: AppSpacing.section),
              Text(
                'Ingrédients pour ${recipe.servings} personne'
                '${recipe.servings > 1 ? 's' : ''}',
                style: AppTextStyles.baloo22,
              ),
              SizedBox(height: AppSpacing.afterTitle),
              for (final ingredient in recipe.ingredients)
                Padding(
                  padding: EdgeInsets.only(bottom: 18.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•', style: _bodyStyle),
                      SizedBox(width: 30.w),
                      Expanded(child: VeganuaryRichText(ingredient)),
                    ],
                  ),
                ),
              SizedBox(height: AppSpacing.section),
              Text('Étapes', style: AppTextStyles.baloo22),
              SizedBox(height: AppSpacing.afterTitle),
              for (int i = 0; i < recipe.steps.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.item),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 60.w,
                        child: Text(
                          '${i + 1}.',
                          style: _bodyStyle.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      Expanded(child: VeganuaryRichText(recipe.steps[i])),
                    ],
                  ),
                ),
              // Where the downloaded image comes from
              SizedBox(height: AppSpacing.afterTitle),
              Text(
                'Recette du Veganuary · 321 Vegan',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyRegular12
                    .copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown once a day is done for the first time: its number, big, and the
/// days of the week ticked so far. Once the whole week is done, its badge
/// instead of the usual illustration.
class VeganuaryDoneView extends StatelessWidget {
  final int day;

  /// Numbers of the days of the week, in order.
  final List<int> weekDays;
  final Set<int> completedDays;

  /// The next day is already open (days missed to catch up).
  final bool nextAvailable;

  /// Illustration of the week's badge (a placeholder when null).
  final String? badgeImage;

  const VeganuaryDoneView({
    super.key,
    required this.day,
    required this.weekDays,
    required this.completedDays,
    required this.nextAvailable,
    this.badgeImage,
  });

  bool get _weekCompleted => weekDays.every(completedDays.contains);

  @override
  Widget build(BuildContext context) {
    final isLastDay = day >= VeganuaryService.totalDays;
    final message = isLastDay
        ? 'Bravo, vous avez parcouru les ${VeganuaryService.totalDays} '
            'jours du Veganuary !'
        : _weekCompleted
            ? 'Vous avez été là jour après jour, et ça paie : vous en savez '
                'maintenant beaucoup plus.\nContinuez comme ça !'
            : nextAvailable
                ? 'Leçon terminée, bien joué ! 🎉\nVous rattrapez votre '
                    'retard : le jour ${day + 1} vous attend déjà.'
                : 'Leçon terminée, bien joué ! 🎉\nVous êtes allé·e '
                    'jusqu’au bout aujourd’hui. Rendez-vous demain pour la '
                    'suite.';
    final yellowTitle =
        AppTextStyles.baloo30Bold.copyWith(color: kAccentYellow);
    return _CenteredScroll(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VeganuaryImage(
            _weekCompleted
                ? badgeImage ?? 'lib/assets/images/characters/tomatoes.webp'
                : 'lib/assets/images/characters/avocado.webp',
            height: 480.h,
            fit: BoxFit.contain,
          ),
          SizedBox(height: AppSpacing.section),
          Text(
            '$day',
            style: AppTextStyles.baloo90.copyWith(color: kAccentYellow),
          ),
          Text(day > 1 ? 'jours !' : 'jour !', style: yellowTitle),
          if (_weekCompleted) ...[
            SizedBox(height: AppSpacing.section),
            Text('Badge débloqué !',
                textAlign: TextAlign.center, style: yellowTitle),
          ],
          SizedBox(height: AppSpacing.section),
          Text(message, textAlign: TextAlign.center, style: _bodyStyle),
          SizedBox(height: AppSpacing.section * 1.5),
          // Shrinks rather than overflowing on a narrow screen
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                for (final weekDay in weekDays)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18.w),
                    child: _WeekDayDot(
                      day: weekDay,
                      done: completedDays.contains(weekDay),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekDayDot extends StatelessWidget {
  final int day;
  final bool done;

  const _WeekDayDot({required this.day, required this.done});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Jour $day${done ? ', terminé' : ''}',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            '$day',
            style: AppTextStyles.bodyBold13
                .copyWith(color: done ? kAccentYellow : Colors.grey[500]),
          ),
          SizedBox(height: 18.h),
          Container(
            width: 84.w,
            height: 84.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? kAccentYellow : kLockedFill,
            ),
            child: done
                ? Icon(Icons.check_rounded, color: Colors.white, size: 50.sp)
                : null,
          ),
        ],
      ),
    );
  }
}

/// "Ce que vous avez appris aujourd'hui", the last page of a day.
class VeganuaryRecapView extends StatelessWidget {
  final List<VeganuaryRecapCard> cards;

  const VeganuaryRecapView({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return _CenteredScroll(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Récapitulatif du jour',
            textAlign: TextAlign.center,
            // Figma: line-height 38
            style: AppTextStyles.baloo36.copyWith(height: 38 / 36),
          ),
          for (final card in cards) ...[
            SizedBox(height: AppSpacing.section),
            VeganuaryRecapCardView(card: card),
          ],
        ],
      ),
    );
  }
}

/// A card of "Ce que vous avez appris" (end of a day, fiches récap' of a
/// week).
class VeganuaryRecapCardView extends StatelessWidget {
  final VeganuaryRecapCard card;

  const VeganuaryRecapCardView({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final iconSize = 120.w;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 51.w, vertical: 60.h),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 60.r,
          side: const BorderSide(color: kBorderDefault, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          if (card.image != null)
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: VeganuaryImage(card.image!, fit: BoxFit.contain),
            )
          else if (card.emoji != null)
            SizedBox(
              width: iconSize,
              child: Text(
                card.emoji!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 96.sp),
              ),
            ),
          SizedBox(width: 51.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.title, style: AppTextStyles.baloo22),
                SizedBox(height: 30.h),
                for (final bullet in card.bullets)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: _bodyStyle),
                      Expanded(child: VeganuaryRichText(bullet)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
