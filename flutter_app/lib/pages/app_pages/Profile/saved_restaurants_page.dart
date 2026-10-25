import 'package:flutter/material.dart';
import 'package:vegan_app/models/restaurants/restaurant.dart';
import 'package:vegan_app/services/restaurant_api_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_detail_page.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_labels.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_list_card.dart';
import 'package:vegan_app/widgets/shared/app_background.dart';
import 'package:vegan_app/widgets/shared/paginated_list_view.dart';
import 'package:vegan_app/widgets/shared/tag_chip.dart';

/// Places the user saved from their page, last saved first. Pushed from
/// Settings, or from the map with [pickOnTap].
class SavedRestaurantsPage extends StatelessWidget {
  /// Tapping a place pops with it (the map flies there) instead of opening
  /// its page.
  final bool pickOnTap;

  const SavedRestaurantsPage({super.key, this.pickOnTap = false});

  Future<void> _open(
      BuildContext context, Restaurant restaurant, VoidCallback reload) async {
    if (pickOnTap) {
      Navigator.of(context).pop(restaurant);
      return;
    }
    await RestaurantDetailPage.open(context, restaurant);
    // It may have been removed from the saved ones on its page
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Lieux sauvegardés', style: AppTextStyles.baloo22),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kTextPrimary,
        ),
        body: SafeArea(
          top: false,
          child: PaginatedListView<Restaurant>(
            loadPage: (page) =>
                RestaurantApiService.getSavedRestaurants(page: page),
            emptyTitle: 'Aucun lieu sauvegardé',
            emptySubtitle: 'Sauvegardez un lieu depuis sa fiche sur la carte '
                'pour le retrouver ici.',
            errorTitle: 'Impossible de charger vos lieux sauvegardés',
            itemBuilder: (context, restaurant, reload) => RestaurantListCard(
              restaurant: restaurant,
              onTap: () => _open(context, restaurant, reload),
              badges: [
                if (restaurant.isPermanentlyClosed)
                  const TagChip(
                    label: 'Fermé définitivement',
                    color: kSemanticError,
                  ),
                VeganStatusChip(isFullyVegan: restaurant.isFullyVegan),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
