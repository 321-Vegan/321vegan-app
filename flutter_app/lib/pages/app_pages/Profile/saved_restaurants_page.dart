import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/models/restaurants/restaurant.dart';
import 'package:vegan_app/models/restaurants/restaurant_selection.dart';
import 'package:vegan_app/services/restaurant_api_service.dart';
import 'package:vegan_app/services/selection_badge_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_spacing.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_detail_page.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_labels.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_list_card.dart';
import 'package:vegan_app/widgets/restaurants/selection_card.dart';
import 'package:vegan_app/widgets/restaurants/selection_editor_page.dart';
import 'package:vegan_app/widgets/restaurants/selection_page.dart';
import 'package:vegan_app/widgets/restaurants/selection_sheets.dart';
import 'package:vegan_app/widgets/shared/app_background.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';
import 'package:vegan_app/widgets/shared/empty_state_view.dart';
import 'package:vegan_app/widgets/shared/paginated_list_view.dart';
import 'package:vegan_app/widgets/shared/tag_chip.dart';

/// Places the user saved from their page, last saved first, and the
/// selections: their own and the ones sent to them. Pushed from Settings
/// or the bell, or from the map with [pickOnTap].
class SavedRestaurantsPage extends StatelessWidget {
  /// Tapping a saved place pops with it (the map flies there) instead of
  /// opening its page. The places of a selection always open their page,
  /// so going back returns to the selection.
  final bool pickOnTap;

  /// Opens on the selections tab (e.g. from the bell). By default it does
  /// when a selection sent to the user is unread.
  final bool? showSelections;

  const SavedRestaurantsPage({
    super.key,
    this.pickOnTap = false,
    this.showSelections,
  });

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
    final selectionsFirst =
        showSelections ?? SelectionBadgeService.unreadCount.value > 0;
    return DefaultTabController(
      length: 2,
      initialIndex: selectionsFirst ? 1 : 0,
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('Lieux sauvegardés', style: AppTextStyles.baloo22),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: kTextPrimary,
            bottom: TabBar(
              tabs: [
                const Tab(text: 'Lieux'),
                Tab(
                  child: ValueListenableBuilder<int>(
                    valueListenable: SelectionBadgeService.unreadCount,
                    builder: (_, unread, __) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Sélections'),
                        if (unread > 0) ...[
                          SizedBox(width: 12.w),
                          Container(
                            width: 24.w,
                            height: 24.w,
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            top: false,
            child: TabBarView(
              children: [
                PaginatedListView<Restaurant>(
                  loadPage: (page) =>
                      RestaurantApiService.getSavedRestaurants(page: page),
                  emptyTitle: 'Aucun lieu sauvegardé',
                  emptySubtitle: 'Sauvegardez un lieu depuis sa fiche sur la '
                      'carte pour le retrouver ici.',
                  errorTitle: 'Impossible de charger vos lieux sauvegardés',
                  itemBuilder: (context, restaurant, reload) =>
                      RestaurantListCard(
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
                const _SelectionsTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The selections sent to the user and not answered yet, theirs, then the
/// ones they accepted. Opening it marks the received ones as seen.
class _SelectionsTab extends StatefulWidget {
  const _SelectionsTab();

  @override
  State<_SelectionsTab> createState() => _SelectionsTabState();
}

class _SelectionsTabState extends State<_SelectionsTab>
    with AutomaticKeepAliveClientMixin {
  List<RestaurantSelection>? _mine;
  List<RestaurantSelection>? _received;
  bool _hasError = false;

  /// Received selections being accepted or refused.
  final Set<int> _answering = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(showLoader: true);
  }

  Future<void> _load({bool showLoader = false}) async {
    if (showLoader) setState(() => _hasError = false);
    final results = await Future.wait([
      RestaurantApiService.getMySelections(),
      RestaurantApiService.getReceivedSelections(),
    ]);
    if (!mounted) return;
    setState(() {
      _hasError = results.any((r) => r == null);
      if (!_hasError) {
        _mine = results[0]!.items;
        _received = results[1]!.items;
      }
    });
    // From the list, not the badge: it may be stale (sent since its refresh)
    if (!_hasError && _received!.any((s) => !s.isSeen)) {
      SelectionBadgeService.markAllSeen();
    }
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: error ? kSemanticError : kSemanticSuccess,
      ));
  }

  Future<void> _open(RestaurantSelection selection) async {
    await SelectionPage.open(context, selection);
    if (!mounted) return;
    // It may have been edited, accepted, removed...
    _load();
  }

  Future<void> _create() async {
    final created = await SelectionEditorPage.open(context);
    if (created == null || !mounted) return;
    _load();
    _open(created);
  }

  Future<void> _accept(RestaurantSelection selection) async {
    setState(() => _answering.add(selection.id));
    final ok = await RestaurantApiService.acceptSelection(selection.id);
    if (!mounted) return;
    setState(() => _answering.remove(selection.id));
    if (!ok) {
      _snack('Impossible d\'accepter la sélection, réessayez.', error: true);
      return;
    }
    _snack('Sélection ajoutée à vos lieux sauvegardés');
    _load();
  }

  Future<void> _refuse(RestaurantSelection selection) async {
    final confirmed = await confirmSelectionAction(
      context,
      title: 'Refuser la sélection ?',
      message: 'Elle ne réapparaîtra pas, même si ${selection.ownerNickname} '
          'vous l\'envoie à nouveau.',
      confirmLabel: 'Refuser',
    );
    if (!confirmed || !mounted) return;
    setState(() => _answering.add(selection.id));
    final ok = await RestaurantApiService.removeReceivedSelection(selection.id);
    if (!mounted) return;
    setState(() => _answering.remove(selection.id));
    if (!ok) {
      _snack('La modification a échoué, réessayez.', error: true);
      return;
    }
    _load();
  }

  List<Widget> _section(String title, List<Widget> children) => [
        SizedBox(height: AppSpacing.section),
        Text(title, style: AppTextStyles.baloo22),
        SizedBox(height: AppSpacing.afterTitle),
        for (final child in children) ...[
          child,
          SizedBox(height: AppSpacing.item),
        ],
      ];

  Widget _card(RestaurantSelection selection) {
    final busy = _answering.contains(selection.id);
    return SelectionCard(
      selection: selection,
      onTap: () => _open(selection),
      // Kept while answering, so the buttons stay in place
      onAccept: () => busy ? null : _accept(selection),
      onRefuse: () => busy ? null : _refuse(selection),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final mine = _mine;
    final received = _received;
    if (mine == null || received == null) {
      if (_hasError) {
        return EmptyStateView(
          title: 'Impossible de charger vos sélections',
          subtitle: 'Vérifiez votre connexion et réessayez.',
          buttonLabel: 'Réessayer',
          onButtonTap: () => _load(showLoader: true),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    final pending = received.where((s) => s.isPending).toList();
    final accepted = received.where((s) => !s.isPending).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal, 0, AppSpacing.pageHorizontal, 32.h),
        children: [
          if (pending.isNotEmpty)
            ..._section(pending.length == 1 ? 'Reçue' : 'Reçues',
                [for (final s in pending) _card(s)]),
          ..._section('Mes sélections', [
            if (mine.isEmpty)
              Text(
                'Rassemblez vos adresses préférées dans une sélection pour '
                'les recommander à vos proches.',
                style: AppTextStyles.bodyRegular15
                    .copyWith(color: Colors.grey[600]),
              ),
            for (final s in mine) _card(s),
            AppButton(
              label: 'Nouvelle sélection',
              icon: Icons.add,
              backgroundColor: Theme.of(context).colorScheme.primary,
              onPressed: _create,
            ),
          ]),
          if (accepted.isNotEmpty)
            ..._section(
                'Recommandées pour vous', [for (final s in accepted) _card(s)]),
        ],
      ),
    );
  }
}
