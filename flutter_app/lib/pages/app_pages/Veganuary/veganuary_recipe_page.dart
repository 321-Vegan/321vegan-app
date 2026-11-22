import 'package:flutter/material.dart';
import '../../../models/veganuary/veganuary_content.dart';
import '../../../themes/app_text_styles.dart';
import '../../../widgets/shared/app_background.dart';
import '../../../widgets/veganuary/veganuary_step_views.dart';

/// A recipe unlocked, reopened from the list of the Veganuary's recipes.
class VeganuaryRecipePage extends StatelessWidget {
  final RecipeStep recipe;

  const VeganuaryRecipePage({super.key, required this.recipe});

  static Future<void> open(BuildContext context, RecipeStep recipe) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VeganuaryRecipePage(recipe: recipe),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Recette', style: AppTextStyles.baloo22),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: SafeArea(
          top: false,
          child: VeganuaryRecipeView(recipe: recipe),
        ),
      ),
    );
  }
}
