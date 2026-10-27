import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/restaurants/restaurant_selection.dart';
import '../../services/restaurant_api_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_background.dart';
import '../shared/app_button.dart';
import '../shared/empty_state_view.dart';
import '../shared/tag_chip.dart';
import 'restaurant_detail_page.dart';
import 'restaurant_labels.dart';
import 'restaurant_list_card.dart';
import 'selection_author_review.dart';
import 'selection_card.dart';
import 'selection_editor_page.dart';
import 'selection_map_page.dart';
import 'selection_sheets.dart';

/// Page of a selection: its places in order, with their notes, each
/// opening its page over the selection (even from the map, so going back
/// returns to the selection). Its owner can edit, send or delete it; a user
/// it was sent to accepts or refuses it, or removes it once accepted; any
/// user can add a public one to their places.
class SelectionPage extends StatefulWidget {
  /// From a list: shown while the full selection loads.
  final RestaurantSelection selection;

  const SelectionPage({super.key, required this.selection});

  /// Completes when the page is closed.
  static Future<void> open(
      BuildContext context, RestaurantSelection selection) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SelectionPage(selection: selection),
    ));
  }

  @override
  State<SelectionPage> createState() => _SelectionPageState();
}

class _SelectionPageState extends State<SelectionPage> {
  late RestaurantSelection _selection = widget.selection;
  bool _isLoaded = false;
  bool _hasError = false;
  bool _isAnswering = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final selection =
        await RestaurantApiService.getSelection(widget.selection.id);
    if (!mounted) return;
    setState(() {
      _hasError = selection == null;
      if (selection != null) {
        _selection = selection;
        _isLoaded = true;
      }
    });
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: error ? kSemanticError : kSemanticSuccess,
      ));
  }

  /// With what the author wrote about it, if anything.
  Future<void> _openRestaurant(RestaurantSelectionItem item) =>
      RestaurantDetailPage.open(
        context,
        item.restaurant,
        selectionNote: item.note,
        selectionNoteAuthor:
            _selection.isOwner ? null : _selection.ownerNickname,
      );

  // ── Owner ──────────────────────────────────────────────────────────────────

  /// The editor saves as it goes: the selection is reloaded when it closes
  /// (a plain back doesn't carry the saved version).
  Future<void> _edit() async {
    final saved =
        await SelectionEditorPage.open(context, selection: _selection);
    if (!mounted) return;
    if (saved != null) {
      setState(() => _selection = saved);
    } else {
      _load();
    }
  }

  bool _isAddingPlaces = false;

  /// Adds places at the end, straight from the picker.
  Future<void> _addPlaces() async {
    final picked = await pickSelectionRestaurants(context, _selection.items);
    if (picked.isEmpty || !mounted) return;
    setState(() => _isAddingPlaces = true);
    final s = _selection;
    final result = await RestaurantApiService.updateSelection(
      id: s.id,
      title: s.title,
      description: s.description,
      items: [
        ...s.items,
        for (final r in picked) RestaurantSelectionItem(restaurant: r),
      ],
    );
    if (!mounted) return;
    setState(() {
      _isAddingPlaces = false;
      if (result.selection != null) _selection = result.selection!;
    });
    if (result.selection == null) {
      _snack('Impossible d\'ajouter les lieux, réessayez.', error: true);
    }
  }

  Future<void> _send() async {
    if (_selection.items.isEmpty) {
      _snack('Ajoutez au moins un lieu avant d\'envoyer la sélection.',
          error: true);
      return;
    }
    final confirmation = await showSendSelectionSheet(context, _selection);
    if (confirmation != null && mounted) _snack(confirmation);
  }

  Future<void> _delete() async {
    final confirmed = await confirmSelectionAction(
      context,
      title: 'Supprimer la sélection ?',
      message: _selection.isPublic
          ? 'Les personnes qui l\'ont ajoutée à leurs lieux ne la verront plus.'
          : 'Les personnes à qui vous l\'avez envoyée ne la verront plus.',
      confirmLabel: 'Supprimer',
    );
    if (!confirmed || !mounted) return;
    final ok = await RestaurantApiService.deleteSelection(_selection.id);
    if (!mounted) return;
    if (!ok) {
      _snack('La suppression a échoué, réessayez.', error: true);
      return;
    }
    Navigator.of(context).pop();
  }

  // ── Recipient, or any user for a public one ───────────────────────────────

  /// Accepts it, or takes a public one.
  Future<void> _accept() async {
    setState(() => _isAnswering = true);
    final ok = await RestaurantApiService.acceptSelection(_selection.id);
    if (!mounted) return;
    setState(() => _isAnswering = false);
    if (!ok) {
      _snack('Impossible d\'accepter la sélection, réessayez.', error: true);
      return;
    }
    _snack('Sélection ajoutée à vos lieux sauvegardés');
    _load();
  }

  /// Refuses it, or unsubscribes once accepted. The page closes, except
  /// for a public one: the user can subscribe again from it.
  Future<void> _remove() async {
    final pending = _selection.isPending;
    final isPublic = _selection.isPublic;
    final confirmed = await confirmSelectionAction(
      context,
      title: pending ? 'Refuser la sélection ?' : 'Se désabonner ?',
      message: isPublic
          ? 'Elle disparaîtra de vos lieux sauvegardés. Vous pourrez vous '
              'y abonner à nouveau depuis les sélections publiques.'
          : 'Elle ne réapparaîtra pas, même si ${_selection.ownerNickname} '
              'vous l\'envoie à nouveau.',
      confirmLabel: pending ? 'Refuser' : 'Se désabonner',
    );
    if (!confirmed || !mounted) return;
    setState(() => _isAnswering = true);
    final ok =
        await RestaurantApiService.removeReceivedSelection(_selection.id);
    if (!mounted) return;
    setState(() => _isAnswering = false);
    if (!ok) {
      _snack('La modification a échoué, réessayez.', error: true);
      return;
    }
    if (isPublic && !pending) {
      _snack('Vous êtes désabonné·e de cette sélection');
      _load();
      return;
    }
    Navigator.of(context).pop();
  }

  /// Edit and send, under the description.
  Widget _buildOwnerButtons() {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: 'Modifier',
            icon: Icons.edit_outlined,
            backgroundColor: kAccentYellow,
            compact: true,
            onPressed: _edit,
          ),
        ),
        SizedBox(width: 24.w),
        Expanded(
          child: AppButton(
            label: 'Envoyer',
            icon: Icons.send_rounded,
            backgroundColor: primary,
            compact: true,
            onPressed: _send,
          ),
        ),
      ],
    );
  }

  /// Add places and delete, after the places.
  List<Widget> _buildOwnerFooter() {
    return [
      if (_selection.items.length < kMaxSelectionRestaurants)
        AppButton(
          label: 'Ajouter des lieux',
          icon: Icons.add,
          backgroundColor: Theme.of(context).colorScheme.primary,
          isLoading: _isAddingPlaces,
          onPressed: _addPlaces,
        ),
      SizedBox(height: AppSpacing.section),
      // Same as "Supprimer mon compte" in the settings
      AppButton(
        label: 'Supprimer la sélection',
        backgroundColor: kAccentYellow,
        onPressed: _delete,
      ),
    ];
  }

  Widget _buildHeader() {
    final s = _selection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.coverUrl != null) ...[
          ClipSmoothRect(
            radius: squircleRadius(36.r),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: s.coverUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: Colors.grey[100]),
              ),
            ),
          ),
          SizedBox(height: 30.h),
        ],
        // Map button beside the title, as on a restaurant page
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: AppTextStyles.baloo26),
                  SizedBox(height: 6.h),
                  SelectionSubtitle(selection: s),
                ],
              ),
            ),
            if (s.items.isNotEmpty) ...[
              SizedBox(width: 24.w),
              // Height and corners of the square buttons of a restaurant page
              DecoratedBox(
                decoration: ShapeDecoration(
                  shape: squircleBorder(radius: 30.r),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Theme.of(context).colorScheme.primary,
                  shape: squircleBorder(radius: 30.r),
                  child: InkWell(
                    customBorder: squircleBorder(radius: 30.r),
                    onTap: () => SelectionMapPage.open(context, s),
                    child: SizedBox(
                      height: 102.w,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 30.w),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_outlined,
                                color: Colors.white, size: 48.sp),
                            SizedBox(width: 15.w),
                            Text('Voir la carte',
                                style: AppTextStyles.bodyBold13
                                    .copyWith(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (s.description != null) ...[
          SizedBox(height: 24.h),
          Text(s.description!,
              style: AppTextStyles.bodyRegular15.copyWith(height: 1.4)),
        ],
        if (s.isPending) ...[
          SizedBox(height: 24.h),
          Text(
            '${s.ownerNickname} vous recommande ces lieux. Acceptez la '
            'sélection pour la retrouver avec vos lieux sauvegardés.',
            style:
                AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[600]),
          ),
        ] else if (s.canTake) ...[
          SizedBox(height: 24.h),
          Text(
            'Sélection publique de ${s.ownerNickname}. Ajoutez-la pour la '
            'retrouver avec vos lieux sauvegardés.',
            style:
                AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[600]),
          ),
        ],
        if (s.isOwner) ...[
          SizedBox(height: 36.h),
          _buildOwnerButtons(),
        ],
        SizedBox(height: AppSpacing.section),
      ],
    );
  }

  Widget _buildItem(RestaurantSelectionItem item) {
    final r = item.restaurant;
    return RestaurantListCard(
      restaurant: r,
      onTap: () => _openRestaurant(item),
      badges: [
        if (r.isPermanentlyClosed)
          const TagChip(label: 'Fermé définitivement', color: kSemanticError)
        else if (!r.validated)
          const TagChip(
              label: 'En attente de validation', color: kVeganOptionsOrange),
        VeganStatusChip(isFullyVegan: r.isFullyVegan),
        if (item.authorRating != null)
          AuthorRatingPill(
            rating: item.authorRating!,
            onTap: item.authorReviewId == null
                ? null
                : () => showAuthorReviewSheet(
                      context,
                      reviewId: item.authorReviewId!,
                      restaurant: r,
                      authorNickname:
                          _selection.isOwner ? null : _selection.ownerNickname,
                    ),
          ),
      ],
      footer: item.note == null
          ? null
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded,
                    size: 48.sp, color: Theme.of(context).colorScheme.primary),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(item.note!,
                      style: AppTextStyles.bodyRegular15
                          .copyWith(fontStyle: FontStyle.italic, height: 1.4)),
                ),
              ],
            ),
    );
  }

  Widget _buildBody() {
    if (_hasError && !_isLoaded) {
      return EmptyStateView(
        title: 'Sélection indisponible',
        subtitle: 'Elle a peut-être été supprimée. Vérifiez votre connexion '
            'et réessayez.',
        buttonLabel: 'Réessayer',
        onButtonTap: _load,
      );
    }
    if (!_isLoaded) return const Center(child: CircularProgressIndicator());
    final items = _selection.items;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal, 24.h, AppSpacing.pageHorizontal, 32.h),
        children: [
          _buildHeader(),
          if (items.isEmpty) ...[
            EmptyStateView(
              title: 'Aucun lieu',
              subtitle: _selection.isOwner
                  ? 'Ajoutez les lieux que vous voulez recommander.'
                  : 'Cette sélection est vide pour le moment.',
            ),
            SizedBox(height: AppSpacing.section),
          ],
          for (final item in items) ...[
            _buildItem(item),
            SizedBox(height: AppSpacing.item),
          ],
          if (_selection.isOwner) ..._buildOwnerFooter(),
        ],
      ),
    );
  }

  /// Unsubscribe from a selection accepted or subscribed to, at the bottom.
  Widget _buildUnsubscribeButton() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal, 12.h, AppSpacing.pageHorizontal, 24.h),
      child: AppButton(
        label: 'Se désabonner',
        icon: Icons.bookmark_remove_outlined,
        backgroundColor: kAccentYellow,
        isLoading: _isAnswering,
        onPressed: _remove,
      ),
    );
  }

  /// Add a public selection to the user's places, at the bottom.
  Widget _buildTakeButton() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal, 12.h, AppSpacing.pageHorizontal, 24.h),
      child: AppButton(
        label: 'M\'abonner à cette sélection',
        icon: Icons.bookmark_add_outlined,
        backgroundColor: Theme.of(context).colorScheme.primary,
        isLoading: _isAnswering,
        onPressed: _accept,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final answer = _isLoaded && _selection.isPending;
    final take = _isLoaded && _selection.canTake;
    final unsubscribe =
        _isLoaded && _selection.isAccepted && !_selection.isOwner;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Sélection', style: AppTextStyles.baloo22),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kTextPrimary,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(child: _buildBody()),
              if (take) _buildTakeButton(),
              if (unsubscribe) _buildUnsubscribeButton(),
              if (answer)
                Padding(
                  padding: EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 12.h,
                      AppSpacing.pageHorizontal, 24.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Refuser',
                          backgroundColor: Colors.white,
                          foregroundColor: kTextPrimary,
                          borderColor: kBorderDefault,
                          onPressed: _isAnswering ? null : _remove,
                        ),
                      ),
                      SizedBox(width: 24.w),
                      Expanded(
                        child: AppButton(
                          label: 'Accepter',
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          isLoading: _isAnswering,
                          onPressed: _accept,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
