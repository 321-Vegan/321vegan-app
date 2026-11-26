import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/veganuary/veganuary_content.dart';
import '../../models/veganuary/veganuary_progress.dart';
import '../../pages/app_pages/Veganuary/veganuary_recipe_page.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/icon_snack_bar.dart';
import 'saturation_filter.dart';
import 'veganuary_downloads.dart';
import 'veganuary_step_views.dart';

/// A recipe of the course and the day it comes with.
typedef _DayRecipe = ({int day, RecipeStep recipe});

/// All the recipes of the course, in the list of weeks: the ones of the days
/// done open again, the others are greyed out until then. "Tout télécharger"
/// downloads the ones unlocked in a PDF.
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

  /// The unlocked recipes, in a PDF.
  Future<void> _downloadAll(BuildContext buttonContext) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    await runVeganuaryDownload(
      context,
      () => downloadVeganuaryRecipes(
          buttonContext, widget.progress.unlockedRecipes(widget.weeks)),
    );
    if (mounted) setState(() => _downloading = false);
  }

  void _open(_DayRecipe item) {
    if (_unlocked(item)) {
      VeganuaryRecipePage.open(context, item.recipe);
      return;
    }
    showInfoSnackBar(
        context, 'Cette recette se débloque au jour ${item.day}.');
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
