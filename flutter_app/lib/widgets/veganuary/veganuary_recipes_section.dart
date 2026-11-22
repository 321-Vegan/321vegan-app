import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../helpers/image_capture.dart';
import '../../models/veganuary/veganuary_content.dart';
import '../../models/veganuary/veganuary_progress.dart';
import '../../pages/app_pages/Veganuary/veganuary_recipe_page.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import 'saturation_filter.dart';
import 'veganuary_step_views.dart';

/// A recipe of the course and the day it comes with.
typedef _DayRecipe = ({int day, RecipeStep recipe});

/// All the recipes of the course, in the list of weeks: the ones of the days
/// done open again, the others are greyed out until then. "Tout télécharger"
/// shares the ones unlocked as images, like each recipe's own button.
class VeganuaryRecipesSection extends StatefulWidget {
  final List<VeganuaryWeek> weeks;
  final VeganuaryProgress progress;

  const VeganuaryRecipesSection({
    super.key,
    required this.weeks,
    required this.progress,
  });

  @override
  State<VeganuaryRecipesSection> createState() =>
      _VeganuaryRecipesSectionState();
}

class _VeganuaryRecipesSectionState extends State<VeganuaryRecipesSection> {
  bool _downloading = false;

  List<_DayRecipe> get _recipes => [
        for (final week in widget.weeks)
          for (final day in week.days)
            for (final step in day.steps.whereType<RecipeStep>())
              (day: day.number, recipe: step),
      ];

  bool _unlocked(_DayRecipe item) => widget.progress.isCompleted(item.day);

  /// The unlocked recipes, at the screen's width (as on their page),
  /// shared at once.
  Future<void> _downloadAll(BuildContext buttonContext) async {
    if (_downloading) return;
    final recipes = _recipes.where(_unlocked).toList();
    final sources = [
      for (final item in recipes)
        for (final src in [item.recipe.image, item.recipe.credit?.image])
          if (src != null) src,
    ];
    setState(() => _downloading = true);
    try {
      final files = await captureOffscreen(
        context,
        width: MediaQuery.sizeOf(context).width,
        images: {
          for (final item in recipes)
            item.recipe.fileName: VeganuaryRecipeSheet(recipe: item.recipe),
        },
        precache: [
          for (final src in sources)
            _isNetwork(src) ? CachedNetworkImageProvider(src) : AssetImage(src),
        ],
        // A network photo still fades in
        settle: sources.any(_isNetwork)
            ? const Duration(milliseconds: 700)
            : Duration.zero,
      );
      if (files.isEmpty || !buttonContext.mounted) return;

      await shareImageFiles(
        buttonContext,
        files,
        text: 'Les recettes du Veganuary de 321 Vegan 🌱 https://321vegan.fr',
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  static bool _isNetwork(String src) => src.startsWith('http');

  void _open(_DayRecipe item) {
    if (_unlocked(item)) {
      VeganuaryRecipePage.open(context, item.recipe);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Cette recette se débloque au jour ${item.day}.'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final recipes = _recipes;
    if (recipes.isEmpty) return const SizedBox.shrink();
    final anyUnlocked = recipes.any(_unlocked);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Les recettes', style: AppTextStyles.baloo22),
            ),
            if (anyUnlocked)
              // Own context: the share popover (iPad) points at the button
              Builder(
                builder: (buttonContext) => AppButton(
                  label: 'Tout télécharger',
                  icon: Icons.download_rounded,
                  compact: true,
                  isLoading: _downloading,
                  backgroundColor: kAccentYellow,
                  disabledBackgroundColor: kAccentYellow,
                  onPressed: () => _downloadAll(buttonContext),
                ),
              ),
          ],
        ),
        SizedBox(height: AppSpacing.afterTitle),
        // Two by two, the cards of a row as tall as each other
        for (var i = 0; i < recipes.length; i += 2) ...[
          if (i > 0) SizedBox(height: AppSpacing.item),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _card(recipes[i])),
                SizedBox(width: AppSpacing.item),
                Expanded(
                  child: i + 1 < recipes.length
                      ? _card(recipes[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _card(_DayRecipe item) => _RecipeCard(
      item: item, locked: !_unlocked(item), onTap: () => _open(item));
}

class _RecipeCard extends StatelessWidget {
  final _DayRecipe item;
  final bool locked;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.item,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final image = item.recipe.image;
    final shape = squircleBorder(
      radius: 60.r,
      side: const BorderSide(color: kBorderDefault, width: 1.5),
    );

    return Material(
      color: locked ? Colors.white.withValues(alpha: 0.5) : Colors.white,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1.25,
                child: ClipSmoothRect(
                  radius: squircleRadius(36.r),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (image == null)
                        const ColoredBox(color: kBorderDefault)
                      else if (locked)
                        Opacity(
                          opacity: 0.5,
                          child: ColorFiltered(
                            colorFilter: saturationFilter(0),
                            child: VeganuaryImage(image),
                          ),
                        )
                      else
                        VeganuaryImage(image),
                      if (locked)
                        Center(
                          child: Icon(Icons.lock_rounded,
                              color: Colors.grey[500], size: 72.sp),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'Jour ${item.day}',
                style: AppTextStyles.bodyRegular12
                    .copyWith(color: Colors.grey[500]),
              ),
              SizedBox(height: 6.h),
              Text(
                item.recipe.title,
                style: AppTextStyles.bodyBold15
                    .copyWith(color: locked ? Colors.grey[500] : kTextPrimary),
              ),
              if (item.recipe.credit != null) ...[
                SizedBox(height: 6.h),
                Text(
                  'par ${item.recipe.credit!.name}',
                  style: AppTextStyles.bodyRegular12
                      .copyWith(color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
