import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:vegan_app/helpers/restaurant_drafts.dart';
import 'package:vegan_app/widgets/restaurants/create_restaurant_page.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_drafts_list.dart';
import 'package:vegan_app/models/product_rating.dart';
import 'package:vegan_app/models/restaurants/restaurant.dart';
import 'package:vegan_app/models/restaurants/restaurant_review.dart';
import 'package:vegan_app/models/restaurants/restaurant_suggestion.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/services/restaurant_api_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_detail_page.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_labels.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_list_card.dart';
import 'package:vegan_app/widgets/reviews/product_ratings_sheet.dart';
import 'package:vegan_app/widgets/reviews/rating_status_chip.dart';
import 'package:vegan_app/widgets/reviews/review_card.dart';
import 'package:vegan_app/widgets/shared/app_background.dart';
import 'package:vegan_app/widgets/shared/app_dialog.dart';
import 'package:vegan_app/widgets/shared/app_card.dart';
import 'package:vegan_app/widgets/shared/paginated_list_view.dart';
import 'package:vegan_app/widgets/shared/tag_chip.dart';

const _pageSize = 20;

/// Full-screen page gathering what the current user contributed, one tab
/// per kind: product ratings, restaurant reviews, restaurants created and
/// restaurant changes proposed, each with its moderation status. Pushed
/// from Settings.
class MyContributionsPage extends StatelessWidget {
  const MyContributionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('Mes contributions', style: AppTextStyles.baloo22),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: kTextPrimary,
            bottom: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              tabs: [
                Tab(text: 'Notes'),
                Tab(text: 'Avis'),
                Tab(text: 'Lieux'),
                Tab(text: 'Propositions'),
              ],
            ),
          ),
          body: const SafeArea(
            top: false,
            child: TabBarView(
              children: [
                _ProductRatingsTab(),
                _RestaurantReviewsTab(),
                _RestaurantsTab(),
                _SuggestionsTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Name (and city) of the rated item above a review card, with a chevron.
Widget _itemHeader(String title, String? subtitle) {
  return Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.baloo17),
            if (subtitle != null) ...[
              SizedBox(height: 4.h),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLight15),
            ],
          ],
        ),
      ),
      SizedBox(width: 16.w),
      Icon(Icons.arrow_forward_ios, size: 32.sp, color: Colors.grey[400]),
    ],
  );
}

/// Opens a restaurant's page from its id (the lists only carry part of
/// it), then [onClosed] (e.g. to reload a review edited there).
Future<void> _openRestaurant(
  BuildContext context,
  int restaurantId,
  VoidCallback onClosed,
) async {
  final restaurant = await RestaurantApiService.getRestaurant(restaurantId);
  if (!context.mounted) return;
  if (restaurant == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Ce restaurant n\'est plus disponible.'),
      backgroundColor: kSemanticError,
    ));
    return;
  }
  await RestaurantDetailPage.open(context, restaurant);
  onClosed();
}

// ── Product ratings ─────────────────────────────────────────────────────────

class _ProductRatingsTab extends StatelessWidget {
  const _ProductRatingsTab();

  @override
  Widget build(BuildContext context) {
    return PaginatedListView<ProductRating>(
      loadPage: (page) async {
        final result = await ApiService.getMyProductRatings(
            page: page, pageSize: _pageSize);
        return result == null
            ? null
            : (items: result.items, pages: result.pages);
      },
      emptyTitle: 'Aucune note',
      emptySubtitle:
          'Notez un produit vegan depuis le scan ou le Vegandex pour le retrouver ici.',
      errorTitle: 'Impossible de charger vos notes',
      itemBuilder: (context, rating, reload) => ReviewCard(
        nickname: rating.userNickname,
        showAuthor: false,
        rating: rating.rating,
        comment: rating.comment,
        date: rating.createdAt,
        badge: RatingStatusChip(status: rating.status),
        header: _itemHeader(rating.productName ?? rating.ean, rating.brandName),
        onTap: () async {
          await showProductRatingsSheet(
            context,
            ean: rating.ean,
            productName: rating.productName,
            brandName: rating.brandName,
          );
          // The rating may have been edited in the sheet
          reload();
        },
      ),
    );
  }
}

// ── Restaurant reviews ──────────────────────────────────────────────────────

class _RestaurantReviewsTab extends StatelessWidget {
  const _RestaurantReviewsTab();

  @override
  Widget build(BuildContext context) {
    return PaginatedListView<RestaurantReview>(
      loadPage: (page) =>
          RestaurantApiService.getMyReviews(page: page, pageSize: _pageSize),
      emptyTitle: 'Aucun avis',
      emptySubtitle:
          'Donnez votre avis sur un restaurant depuis la carte pour le retrouver ici.',
      errorTitle: 'Impossible de charger vos avis',
      itemBuilder: (context, review, reload) => ReviewCard(
        nickname: review.userNickname,
        showAuthor: false,
        rating: review.rating,
        comment: review.comment,
        date: review.createdAt,
        badge: RatingStatusChip(status: review.status),
        header: _itemHeader(
            review.restaurantName ?? 'Restaurant', review.restaurantCity),
        onTap: () => _openRestaurant(context, review.restaurantId, reload),
      ),
    );
  }
}

// ── Restaurants created ─────────────────────────────────────────────────────

class _RestaurantsTab extends StatefulWidget {
  const _RestaurantsTab();

  @override
  State<_RestaurantsTab> createState() => _RestaurantsTabState();
}

/// The restaurants created, with the drafts saved on this device above.
class _RestaurantsTabState extends State<_RestaurantsTab> {
  List<RestaurantDraft> _drafts = [];

  /// Changed to reload the list once a draft is sent.
  int _listVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    final drafts = await RestaurantDrafts.all();
    if (mounted) setState(() => _drafts = drafts);
  }

  Future<void> _openDraft(RestaurantDraft draft) async {
    final lat = (draft.fields['latitude'] as num?)?.toDouble();
    final lng = (draft.fields['longitude'] as num?)?.toDouble();
    final created = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => CreateRestaurantPage(
          // Where the pin picker starts without a position: France
          mapCenter: lat != null && lng != null
              ? LatLng(lat, lng)
              : const LatLng(46.2276, 2.2137),
          draft: draft,
        ),
      ),
    );
    if (!mounted) return;
    await _loadDrafts();
    if (created != true || !mounted) return;
    setState(() => _listVersion++);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Merci ! Le lieu sera visible après validation.'),
        backgroundColor: kSemanticSuccess,
      ),
    );
  }

  Future<void> _deleteDraft(RestaurantDraft draft) async {
    if (await confirmDeleteRestaurantDraft(context, draft)) _loadDrafts();
  }

  Widget? _buildDrafts() {
    if (_drafts.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Brouillons sur ce téléphone', style: AppTextStyles.bodyBold15),
        SizedBox(height: 18.h),
        for (final draft in _drafts) ...[
          RestaurantDraftCard(
            draft: draft,
            onTap: () => _openDraft(draft),
            onDelete: () => _deleteDraft(draft),
          ),
          SizedBox(height: 18.h),
        ],
        SizedBox(height: 18.h),
        Text('Envoyés', style: AppTextStyles.bodyBold15),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PaginatedListView<Restaurant>(
      key: ValueKey(_listVersion),
      header: _buildDrafts(),
      loadPage: (page) => RestaurantApiService.getMyRestaurants(
          page: page, pageSize: _pageSize),
      emptyTitle: 'Aucun restaurant',
      emptySubtitle:
          'Ajoutez un restaurant depuis la carte (couche Restos, bouton +) pour le retrouver ici.',
      errorTitle: 'Impossible de charger vos restaurants',
      itemBuilder: (context, restaurant, reload) => RestaurantListCard(
        restaurant: restaurant,
        // A refused restaurant is no longer available to open
        onTap: restaurant.isRejected
            ? null
            : () => _openRestaurant(context, restaurant.id, reload),
        badges: [
          if (restaurant.isRejected)
            const TagChip(label: 'Refusé', color: kSemanticError)
          else if (restaurant.validated)
            const TagChip(
              label: 'Validé',
              color: kSemanticSuccess,
              backgroundColor: kPrimaryTag,
            )
          else
            const TagChip(
              label: 'En attente',
              color: kAccentYellow,
              backgroundColor: kSecondaryTag,
            ),
          VeganStatusChip(isFullyVegan: restaurant.isFullyVegan),
        ],
        footer: restaurant.rejectionReason == null
            ? null
            : Text('Motif : ${restaurant.rejectionReason}',
                style: AppTextStyles.bodyRegular13
                    .copyWith(color: kSemanticError)),
      ),
    );
  }
}

// ── Suggestions ─────────────────────────────────────────────────────────────

/// Restaurant fields in words, for the list of changes.
const _fieldLabels = {
  'name': 'nom',
  'address': 'adresse',
  'city': 'ville',
  'country': 'pays',
  'latitude': 'position',
  'longitude': 'position',
  'description': 'description',
  'vegan_status': 'statut végane',
  'vegan_options_details': 'options véganes',
  'has_gluten_free_options': 'sans gluten',
  'tags': 'type',
  'service_options': 'possibilités',
  'plant_milk_surcharge': 'lait végétal',
  'serves_hot_drinks': 'lait végétal',
  'has_storefront': 'boutique',
  'service_area': 'zone servie',
  'opening_hours': 'horaires',
  'opening_hours_note': 'horaires',
  'stops': 'emplacements',
  'phone': 'téléphone',
  'website': 'site',
  'facebook': 'Facebook',
  'instagram': 'Instagram',
  'menu_url': 'menu',
  'operating_status': 'ouverture',
  'closed_from': 'fermeture',
  'closed_until': 'fermeture',
  'closure_note': 'fermeture',
  'remove_photo_ids': 'photos',
  'featured_photo_id': 'photo principale',
};

class _SuggestionsTab extends StatelessWidget {
  const _SuggestionsTab();

  @override
  Widget build(BuildContext context) {
    return PaginatedListView<RestaurantSuggestion>(
      loadPage: (page) => RestaurantApiService.getMySuggestions(
          page: page, pageSize: _pageSize),
      emptyTitle: 'Aucune proposition',
      emptySubtitle: 'Depuis la fiche d\'un restaurant, menu « … », proposez '
          'une correction pour la retrouver ici.',
      errorTitle: 'Impossible de charger vos propositions',
      itemBuilder: (context, suggestion, reload) =>
          _SuggestionCard(suggestion: suggestion, onWithdrawn: reload),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final RestaurantSuggestion suggestion;
  final VoidCallback onWithdrawn;

  const _SuggestionCard({required this.suggestion, required this.onWithdrawn});

  Future<void> _withdraw(BuildContext context) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Retirer la proposition ?',
      message: 'Elle ne sera pas vérifiée par l\'équipe. Vous pourrez en '
          'faire une nouvelle depuis la fiche du lieu.',
      confirmLabel: 'Retirer',
      destructive: true,
    );
    if (!confirmed) return;
    final ok = await RestaurantApiService.withdrawSuggestion(suggestion.id);
    if (!context.mounted) return;
    if (ok) {
      onWithdrawn();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Impossible de retirer la proposition, réessayez.'),
        backgroundColor: kSemanticError,
      ));
    }
  }

  Widget _statusChip() {
    return switch (suggestion.status) {
      RestaurantSuggestion.statusApproved => const TagChip(
          label: 'Appliquée',
          color: kSemanticSuccess,
          backgroundColor: kPrimaryTag,
        ),
      RestaurantSuggestion.statusPartiallyApproved => const TagChip(
          label: 'Appliquée en partie',
          color: kSemanticSuccess,
          backgroundColor: kPrimaryTag,
        ),
      RestaurantSuggestion.statusRejected => const TagChip(
          label: 'Refusée',
          color: kSemanticError,
        ),
      _ => const TagChip(
          label: 'En attente',
          color: kAccentYellow,
          backgroundColor: kSecondaryTag,
        ),
    };
  }

  String get _summary => switch (suggestion.kind) {
        RestaurantSuggestion.kindDuplicate =>
          'Doublon de ${suggestion.duplicateOfName ?? 'un autre lieu'}',
        RestaurantSuggestion.kindNoVeganOption => 'Fin des options véganes',
        _ => 'Modifié : ${{
            for (final field in suggestion.changes.keys)
              _fieldLabels[field] ?? field,
          }.join(', ')}',
      };

  @override
  Widget build(BuildContext context) {
    final isPending = suggestion.status == RestaurantSuggestion.statusPending;
    return AppCard(
      radius: 36.r,
      padding: EdgeInsets.all(30.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  suggestion.restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.baloo17,
                ),
              ),
              SizedBox(width: 16.w),
              _statusChip(),
            ],
          ),
          SizedBox(height: 8.h),
          Text(_summary, style: AppTextStyles.bodyRegular15),
          if (suggestion.comment != null) ...[
            SizedBox(height: 8.h),
            Text('« ${suggestion.comment} »',
                style: AppTextStyles.bodyRegular13
                    .copyWith(color: Colors.grey[600])),
          ],
          if (suggestion.rejectionReason != null) ...[
            SizedBox(height: 8.h),
            Text('Motif : ${suggestion.rejectionReason}',
                style: AppTextStyles.bodyRegular13
                    .copyWith(color: kSemanticError)),
          ],
          SizedBox(height: 12.h),
          Row(
            children: [
              if (suggestion.createdAt != null)
                Text(
                  DateFormat.yMMMd('fr_FR').format(suggestion.createdAt!),
                  style: AppTextStyles.bodyRegular13
                      .copyWith(color: Colors.grey[500]),
                ),
              const Spacer(),
              if (isPending)
                TextButton(
                  onPressed: () => _withdraw(context),
                  child: const Text('Retirer'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
