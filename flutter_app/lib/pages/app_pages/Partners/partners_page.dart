import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vegan_app/models/partners/partners.dart';
import 'package:vegan_app/models/partners/partners_category.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_spacing.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/shared/app_background.dart';
import 'package:vegan_app/widgets/shared/app_card.dart';
import 'package:vegan_app/widgets/shared/empty_state_view.dart';

/// Sentinel category id for the synthetic "Tout" tab (real category ids
/// from the API start at 1), so it can slot into the same chip/PageView
/// machinery as a regular [PartnersCategory] instead of needing its own.
const int _kAllCategoryId = -1;

/// Full partner-shops list (Figma redesign), reached from
/// [SolidarityShopsSection]'s "Voir plus": a "Tout" tab (all partners,
/// searchable by name) plus one chip per category, same visual language as
/// [ProductSearchPage] (search field, chips, "Résultats (N)", [AppCard]
/// rows).
class PartnersPage extends StatefulWidget {
  const PartnersPage({super.key});

  @override
  State<PartnersPage> createState() => _PartnersPageState();
}

class _PartnersPageState extends State<PartnersPage> {
  List<Partners> _partners = [];
  bool _isLoading = false;
  int? _selectedCategoryId;
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _isSearchFocused = false;
  // Guards against triggering the back-navigation more than once per drag
  // while the user keeps overscrolling past the first category.
  bool _hasPoppedForOverscroll = false;
  // One key per category chip, so the selected one can be scrolled into
  // view with Scrollable.ensureVisible when it changes off-screen (swipe).
  final Map<int, GlobalKey> _chipKeys = {};
  String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://api.321vegan.fr';

  @override
  void initState() {
    super.initState();
    _loadPartnersInfo();
    _searchFocusNode.addListener(_handleSearchFocusChange);
  }

  void _handleSearchFocusChange() {
    if (_isSearchFocused != _searchFocusNode.hasFocus) {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.removeListener(_handleSearchFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }

  GlobalKey _chipKeyFor(int categoryId) =>
      _chipKeys.putIfAbsent(categoryId, () => GlobalKey());

  /// Scrolls the chips row so the selected category's chip is visible.
  /// Deferred to the next frame since this runs right after a setState
  /// (onPageChanged) — the chip's context needs the new frame's layout.
  void _ensureChipVisible(int categoryId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _chipKeys[categoryId]?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadPartnersInfo() async {
    setState(() {
      _isLoading = true;
    });

    final result = await ApiService.getPartners();
    if (!mounted) return;
    setState(() {
      _partners = result;
      _isLoading = false;
      // Always land on "Tout" regardless of what categories exist.
      _selectedCategoryId = _kAllCategoryId;
    });
  }

  List<PartnersCategory> _categoriesFrom(List<Partners> partners) {
    final byId = <int, PartnersCategory>{};
    for (final partner in partners) {
      byId[partner.category.id] = partner.category;
    }
    final categories = byId.values.toList()
      ..sort((a, b) => a.displayOrder - b.displayOrder);
    return categories;
  }

  List<PartnersCategory> get _categories => _categoriesFrom(_partners);

  /// Chips/pages shown to the user: the synthetic "Tout" tab first, then
  /// every real category in [_categories]'s order.
  List<PartnersCategory> get _tabs => [
        PartnersCategory(id: _kAllCategoryId, name: 'Tout'),
        ..._categories,
      ];

  List<Partners> _partnersForCategory(int categoryId) {
    if (categoryId == _kAllCategoryId) {
      if (_searchQuery.isEmpty) return _partners;
      final query = _searchQuery.trim().toLowerCase();
      return _partners
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
    }
    return _partners.where((p) => p.category.id == categoryId).toList();
  }

  /// Chip tap: animates the PageView instead of jumping straight to the
  /// category, so the transition always matches a swipe. [onPageChanged]
  /// is what actually updates [_selectedCategoryId] once the animation
  /// lands, keeping both entry points in sync through one code path.
  void _goToCategory(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// Swiping past the first category (dragging further "left" than there is
  /// content) falls through to the same pop the system back-swipe would do,
  /// instead of just bouncing uselessly at the PageView's edge.
  bool _handleScrollNotification(ScrollNotification notification) {
    // The per-category ListView bubbles its own (vertical) overscroll
    // through here too — restrict to the PageView's horizontal axis so
    // pulling down at the top of the list doesn't also pop the page.
    if (notification is OverscrollNotification &&
        notification.metrics.axis == Axis.horizontal &&
        notification.overscroll < 0 &&
        notification.dragDetails != null &&
        !_hasPoppedForOverscroll) {
      _hasPoppedForOverscroll = true;
      Navigator.of(context).maybePop();
    } else if (notification is ScrollEndNotification) {
      _hasPoppedForOverscroll = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Boutiques solidaires',
            style: AppTextStyles.baloo22,
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kTextPrimary,
        ),
        body: SafeArea(
          top: false,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _partners.isEmpty
                  ? const EmptyStateView(
                      title: 'Aucun partenaire disponible',
                      subtitle: 'Revenez plus tard pour découvrir nos offres.',
                    )
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final tabs = _tabs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 12.h),
        SizedBox(
          height: 120.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 48.w),
            // Tab counts are small — keep every chip laid out (not just
            // the ones currently on-screen) so its key always has a
            // context ready for _ensureChipVisible to scroll to.
            cacheExtent: 5000,
            itemCount: tabs.length,
            separatorBuilder: (_, __) => SizedBox(width: 24.w),
            itemBuilder: (context, index) =>
                _buildCategoryChip(tabs[index], index),
          ),
        ),
        SizedBox(height: AppSpacing.section),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 48.w),
          child: _buildLegendBanner(),
        ),
        SizedBox(height: AppSpacing.section),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: PageView.builder(
              controller: _pageController,
              itemCount: tabs.length,
              onPageChanged: (index) {
                final categoryId = tabs[index].id;
                setState(() => _selectedCategoryId = categoryId);
                _ensureChipVisible(categoryId);
              },
              itemBuilder: (context, index) =>
                  _buildCategoryResults(tabs[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryResults(PartnersCategory category) {
    final isAllTab = category.id == _kAllCategoryId;
    final results = _partnersForCategory(category.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isAllTab) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 48.w),
            child: _buildSearchField(),
          ),
          SizedBox(height: AppSpacing.item),
        ],
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 48.w),
          child: Text(
            'Résultats (${results.length})',
            style: AppTextStyles.baloo22,
          ),
        ),
        SizedBox(height: AppSpacing.afterTitle),
        Expanded(
          child: results.isEmpty
              ? EmptyStateView(
                  title: 'Rien trouvé !',
                  subtitle: isAllTab && _searchQuery.isNotEmpty
                      ? 'Aucune boutique ne correspond à votre recherche.'
                      : 'Aucune boutique dans cette catégorie pour le moment.',
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 48.w, vertical: 8.h),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => SizedBox(height: AppSpacing.item),
                  itemBuilder: (context, index) =>
                      _buildPartnerCard(results[index]),
                ),
        ),
      ],
    );
  }

  /// Same styling as [ProductSearchPage]'s search field: filled white pill,
  /// leading search icon, clear button once there's a query.
  Widget _buildSearchField() {
    return Container(
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 42.r,
          side: BorderSide(
            color: _isSearchFocused ? kAccentYellow : kBorderDefault,
            width: _isSearchFocused ? 1.5 : 1,
          ),
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(fontSize: 42.sp),
        decoration: InputDecoration(
          hintText: 'Rechercher une boutique...',
          hintStyle: TextStyle(fontSize: 42.sp, color: Colors.grey[500]),
          prefixIcon: Image.asset(
            'lib/assets/images/icons/search-line.webp',
            width: 60.sp,
            height: 60.sp,
            color: Colors.grey[600],
            colorBlendMode: BlendMode.srcIn,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 36.sp),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          contentPadding: EdgeInsets.symmetric(horizontal: 39.w, vertical: 33.h),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildCategoryChip(PartnersCategory category, int index) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isSelected = category.id == _selectedCategoryId;
    return GestureDetector(
      key: _chipKeyFor(category.id),
      onTap: () => _goToCategory(index),
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: 39.w, vertical: 33.h),
        decoration: ShapeDecoration(
          color: isSelected ? kPrimaryTag : Colors.white,
          shape: squircleBorder(
            radius: 36.r,
            side: BorderSide(
              color: isSelected ? primaryColor : kBorderDefault,
              width: isSelected ? 1.5 : 1,
            ),
          ),
        ),
        child: Text(
          category.name,
          style: TextStyle(
            fontSize: 39.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? primaryColor : kTextPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendBanner() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              'Les codes promos avec une étoile sont des codes affiliés qui '
              'me donnent une commission. Les utiliser permet de soutenir '
              '321Vegan !',
              style: AppTextStyles.bodyMedium15
                  .copyWith(color: kAccentYellow, height: 1.3),
            ),
          ),
          SizedBox(width: 16.w),
          Icon(Icons.star, color: kAccentYellow, size: 56.w),
        ],
      ),
    );
  }

  Widget _buildPartnerCard(Partners partner) {
    final logoUrl = '$_baseUrl/${partner.logoPath}';
    return GestureDetector(
      onTap: () => _launchWebsite(context, partner.url),
      child: AppCard(
        radius: 60.r,
        padding: EdgeInsets.all(45.w),
        child: Row(
          children: [
            ClipSmoothRect(
              radius: squircleRadius(33.r),
              child: Container(
                width: 240.w,
                height: 240.w,
                color: Colors.grey[100],
                padding: EdgeInsets.all(12.w),
                child: CachedNetworkImage(
                  imageUrl: logoUrl,
                  // Logos come in all sorts of aspect ratios (wide
                  // wordmarks, square icons…) — contain shows the whole
                  // logo instead of cover cropping it to fill the square.
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey[400],
                    ),
                  ),
                  errorWidget: (context, url, error) => Icon(
                    Icons.storefront_outlined,
                    size: 48.sp,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ),
            SizedBox(width: 60.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    partner.discountText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.baloo26,
                  ),
                  Text(
                    partner.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium13
                        .copyWith(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                    decoration: ShapeDecoration(
                      color: kAccentYellow.withValues(alpha: 0.15),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      'Code : ${partner.discountCode}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium13
                          .copyWith(color: kAccentYellow),
                    ),
                  ),
                ],
              ),
            ),
            if (partner.isAffiliate) ...[
              SizedBox(width: 12.w),
              Icon(Icons.star, color: kAccentYellow, size: 64.sp),
            ],
          ],
        ),
      ),
    );
  }

  void _launchWebsite(BuildContext context, String url) async {
    try {
      final Uri uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir le lien'),
          backgroundColor: kSemanticError,
        ),
      );
    }
  }
}
