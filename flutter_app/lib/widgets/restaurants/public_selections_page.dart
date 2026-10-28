import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/restaurants/restaurant_selection.dart';
import '../../services/restaurant_api_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_background.dart';
import '../shared/paginated_list_view.dart';
import '../shared/search_field.dart';
import 'selection_card.dart';
import 'selection_page.dart';

const _pageSize = 20;

/// The public selections of every user, found by title, the most added or
/// the last published first. Each opens its page, where the user can
/// subscribe to it.
class PublicSelectionsPage extends StatefulWidget {
  const PublicSelectionsPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const PublicSelectionsPage(),
    ));
  }

  @override
  State<PublicSelectionsPage> createState() => _PublicSelectionsPageState();
}

class _PublicSelectionsPageState extends State<PublicSelectionsPage> {
  final _query = TextEditingController();
  Timer? _debounce;
  String _sort = SelectionSort.popular;

  /// The searched title, once typing paused.
  String _search = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _search = value.trim());
    });
  }

  Widget _sortChip(String sort, String label) {
    final selected = _sort == sort;
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? primary : Colors.white,
      shape: squircleBorder(
        radius: 30.r,
        side: BorderSide(color: selected ? primary : kBorderDefault),
      ),
      child: InkWell(
        customBorder: squircleBorder(radius: 30.r),
        onTap: selected ? null : () => setState(() => _sort = sort),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 15.h),
          child: Text(
            label,
            style: AppTextStyles.bodyBold13
                .copyWith(color: selected ? Colors.white : kTextPrimary),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Coups de 🖤 de la communauté', style: AppTextStyles.baloo22),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kTextPrimary,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 12.h,
                    AppSpacing.pageHorizontal, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SearchField(
                      controller: _query,
                      hintText: 'Rechercher par titre',
                      onChanged: _onQueryChanged,
                      textInputAction: TextInputAction.search,
                    ),
                    SizedBox(height: 24.h),
                    Row(
                      children: [
                        _sortChip(SelectionSort.popular, 'Populaires'),
                        SizedBox(width: 18.w),
                        _sortChip(SelectionSort.recent, 'Récentes'),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PaginatedListView<RestaurantSelection>(
                  // A new search or order starts over
                  key: ValueKey('$_sort|$_search'),
                  loadPage: (page) => RestaurantApiService.getPublicSelections(
                      sort: _sort,
                      search: _search,
                      page: page,
                      pageSize: _pageSize),
                  emptyTitle: _search.isEmpty
                      ? 'Aucune sélection publique'
                      : 'Aucune sélection trouvée',
                  emptySubtitle: _search.isEmpty
                      ? 'Rendez une de vos sélections publique pour la '
                          'partager avec tout le monde.'
                      : 'Aucune sélection publique ne s\'appelle '
                          '« $_search ».',
                  errorTitle: 'Impossible de charger les sélections',
                  itemBuilder: (context, selection, reload) => SelectionCard(
                    selection: selection,
                    showAdded: true,
                    onTap: () async {
                      await SelectionPage.open(context, selection);
                      // The user may have subscribed or unsubscribed
                      reload();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
