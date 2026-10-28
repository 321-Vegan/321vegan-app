import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/models/restaurants/restaurant.dart';
import 'package:vegan_app/models/restaurants/restaurant_selection.dart';
import 'package:vegan_app/services/restaurant_api_service.dart';
import 'package:vegan_app/services/selection_badge_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_spacing.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_detail_page.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_labels.dart';
import 'package:vegan_app/widgets/restaurants/public_selections_page.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_list_card.dart';
import 'package:vegan_app/widgets/restaurants/saved_places_welcome_modal.dart';
import 'package:vegan_app/widgets/restaurants/selection_card.dart';
import 'package:vegan_app/widgets/restaurants/selection_editor_page.dart';
import 'package:vegan_app/widgets/restaurants/selection_page.dart';
import 'package:vegan_app/widgets/shared/app_background.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';
import 'package:vegan_app/widgets/shared/app_dialog.dart';
import 'package:vegan_app/widgets/shared/empty_state_view.dart';
import 'package:vegan_app/widgets/shared/icon_snack_bar.dart';
import 'package:vegan_app/widgets/shared/paginated_list_view.dart';
import 'package:vegan_app/widgets/shared/tag_chip.dart';

/// Places the user saved from their page, last saved first, and the
/// selections: their own and the ones sent to them. Pushed from Settings,
/// the bell or the map. A place opens its page over the list, so going
/// back returns to it. Opens on the tab last seen.
class SavedRestaurantsPage extends StatefulWidget {
  /// Called with a saved place as its page opens (e.g. the map moves to it
  /// behind, to be there once the list is left).
  final ValueChanged<Restaurant>? onOpenRestaurant;

  /// Opens on the selections tab (e.g. from the bell). By default it does
  /// when a selection sent to the user is unread, else on the tab last
  /// seen.
  final bool? showSelections;

  const SavedRestaurantsPage({
    super.key,
    this.onOpenRestaurant,
    this.showSelections,
  });

  @override
  State<SavedRestaurantsPage> createState() => _SavedRestaurantsPageState();
}

const _placesTab = 'places';
const _selectionsTab = 'selections';

class _SavedRestaurantsPageState extends State<SavedRestaurantsPage>
    with SingleTickerProviderStateMixin {
  /// Created once the tab to open on is known.
  TabController? _tabs;

  @override
  void initState() {
    super.initState();
    _initTabs();
    _showWelcomeOnFirstVisit();
  }

  /// The intro of the page's features, until closed with its last button.
  Future<void> _showWelcomeOnFirstVisit() async {
    if (await PreferencesHelper.getSavedPlacesWelcomeSeen() || !mounted) {
      return;
    }
    // Wait a bit for the page to be fully displayed
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    final seen = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SavedPlacesWelcomeModal(),
    );
    if (seen == true) await PreferencesHelper.setSavedPlacesWelcomeSeen();
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _initTabs() async {
    final bool selectionsFirst;
    if (widget.showSelections != null) {
      selectionsFirst = widget.showSelections!;
    } else if (SelectionBadgeService.unreadCount.value > 0) {
      selectionsFirst = true;
    } else {
      selectionsFirst =
          await PreferencesHelper.getLastSavedTabPref() == _selectionsTab;
    }
    if (!mounted) return;
    final tabs = TabController(
        length: 2, vsync: this, initialIndex: selectionsFirst ? 1 : 0);
    tabs.addListener(() {
      if (tabs.indexIsChanging) return;
      PreferencesHelper.setLastSavedTabPref(
          tabs.index == 1 ? _selectionsTab : _placesTab);
    });
    setState(() => _tabs = tabs);
  }

  /// Places removed from the saved ones from the list, hidden without
  /// reloading it (so an undo puts them back in place).
  final Set<int> _removedIds = {};

  void _snack(SnackBar snackBar) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  /// Removed right away, with an undo in the snack bar.
  Future<void> _unsave(Restaurant restaurant) async {
    setState(() => _removedIds.add(restaurant.id));
    final ok =
        await RestaurantApiService.setRestaurantSaved(restaurant.id, false);
    if (!mounted) return;
    if (!ok) {
      setState(() => _removedIds.remove(restaurant.id));
      _snack(const SnackBar(
        content: Text('Impossible de retirer ce lieu, réessayez.'),
        backgroundColor: kSemanticError,
      ));
      return;
    }
    _snack(iconSnackBar(
      icon: Icons.bookmark_border,
      message: '« ${restaurant.name} » retiré de vos lieux',
      color: kSemanticSuccess,
      actionLabel: 'Annuler',
      onAction: () => _undoUnsave(restaurant),
    ));
  }

  Future<void> _undoUnsave(Restaurant restaurant) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final ok =
        await RestaurantApiService.setRestaurantSaved(restaurant.id, true);
    if (!mounted) return;
    if (ok) {
      setState(() => _removedIds.remove(restaurant.id));
    } else {
      _snack(const SnackBar(
        content: Text('Impossible de remettre ce lieu, réessayez.'),
        backgroundColor: kSemanticError,
      ));
    }
  }

  Future<void> _open(
      BuildContext context, Restaurant restaurant, VoidCallback reload) async {
    widget.onOpenRestaurant?.call(restaurant);
    await RestaurantDetailPage.open(context, restaurant);
    // It may have been removed from the saved ones on its page
    reload();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final title = Text('Lieux sauvegardés', style: AppTextStyles.baloo22);
    if (tabs == null) {
      // The time to read the tab last seen
      return AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: title,
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: kTextPrimary,
          ),
        ),
      );
    }
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: title,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kTextPrimary,
          bottom: TabBar(
            controller: tabs,
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
            controller: tabs,
            children: [
              PaginatedListView<Restaurant>(
                loadPage: (page) =>
                    RestaurantApiService.getSavedRestaurants(page: page),
                emptyTitle: 'Aucun lieu sauvegardé',
                emptySubtitle: 'Sauvegardez un lieu depuis sa fiche sur la '
                    'carte pour le retrouver ici.',
                errorTitle: 'Impossible de charger vos lieux sauvegardés',
                isVisible: (restaurant) => !_removedIds.contains(restaurant.id),
                itemBuilder: (context, restaurant, reload) =>
                    RestaurantListCard(
                  restaurant: restaurant,
                  onTap: () => _open(context, restaurant, reload),
                  trailing: IconButton(
                    tooltip: 'Retirer de vos lieux',
                    icon: Icon(Icons.bookmark,
                        color: Theme.of(context).colorScheme.primary),
                    onPressed: () => _unsave(restaurant),
                  ),
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

  void _snack(String text, {bool error = false}) =>
      showResultSnackBar(context, text, error: error);

  Future<void> _open(RestaurantSelection selection) async {
    await SelectionPage.open(context, selection);
    if (!mounted) return;
    // It may have been edited, accepted, removed...
    _load();
  }

  Future<void> _discover() async {
    await PublicSelectionsPage.open(context);
    if (!mounted) return;
    // Some may have been added to the user's places
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
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Refuser la sélection ?',
      message:
          'Elle n\'apparaîtra plus, il faudra que ${selection.ownerNickname} '
          'vous l\'envoie à nouveau.',
      confirmLabel: 'Refuser',
      destructive: true,
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
            AppButton(
              label: 'Coups de 🤍 de la communauté',
              icon: Icons.search,
              backgroundColor: kAccentYellow,
              onPressed: _discover,
            ),
          ]),
          if (accepted.isNotEmpty)
            ..._section('Sélections sauvegardées',
                [for (final s in accepted) _card(s)]),
        ],
      ),
    );
  }
}
