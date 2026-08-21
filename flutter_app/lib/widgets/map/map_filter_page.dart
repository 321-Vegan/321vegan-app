import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/models/product_category.dart';
import 'package:vegan_app/models/product_of_interest.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/services/products_of_interest_cache.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_spacing.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/shared/app_background.dart';

/// Full-screen page to filter map shops by the products they carry.
/// Pushed from the map's filter button; pops after "Appliquer".
class MapFilterPage extends StatefulWidget {
  final Set<String> selectedEans;
  final ValueChanged<Set<String>> onApply;

  const MapFilterPage({
    super.key,
    required this.selectedEans,
    required this.onApply,
  });

  @override
  State<MapFilterPage> createState() => _MapFilterPageState();
}

class _MapFilterPageState extends State<MapFilterPage> {
  late Set<String> _selected;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<ProductOfInterest> _products = [];
  List<ProductCategory> _categories = [];
  ProductCategory? _selectedCategory;
  bool _isLoading = true;
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedEans);
    _loadProducts();
    _searchFocusNode.addListener(_handleSearchFocusChange);
  }

  void _handleSearchFocusChange() {
    if (_isSearchFocused != _searchFocusNode.hasFocus) {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    }
  }

  Future<void> _loadProducts() async {
    final results = await Future.wait([
      ProductsOfInterestCache.loadProductsOfInterest(),
      ApiService.getProductCategories(),
    ]);
    if (mounted) {
      setState(() {
        _products = (results[0] as List<ProductOfInterest>)..shuffle();
        _categories = results[1] as List<ProductCategory>;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_handleSearchFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<ProductOfInterest> get _sponsored =>
      _products.where((p) => p.type == 'sponsored').toList();

  bool _matches(ProductOfInterest p) {
    if (_selectedCategory != null && p.categoryId != _selectedCategory!.id) {
      return false;
    }
    final q = _search.toLowerCase();
    return q.isEmpty ||
        p.name.toLowerCase().contains(q) ||
        p.brandName.toLowerCase().contains(q);
  }

  List<ProductOfInterest> get _regular =>
      _products.where((p) => p.type != 'sponsored').where(_matches).toList();

  List<ProductOfInterest> get _sponsoredFiltered =>
      _sponsored.where(_matches).toList();

  void _toggle(ProductOfInterest product) {
    setState(() {
      if (_selected.contains(product.ean)) {
        _selected.remove(product.ean);
      } else {
        _selected.add(product.ean);
      }
    });
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    String? image,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 39.w, vertical: 33.h),
        decoration: ShapeDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.08)
              : Colors.white,
          shape: squircleBorder(
            radius: 42.r,
            side: BorderSide(
              color: isSelected ? primaryColor : kBorderDefault,
              width: isSelected ? 1.5 : 1,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image != null && image.isNotEmpty) ...[
              CachedNetworkImage(
                imageUrl: '${dotenv.env['API_BASE_URL']}/$image',
                width: 56.sp,
                height: 56.sp,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
              SizedBox(width: 16.w),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 39.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? primaryColor : kTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(ProductOfInterest product) {
    return Container(
      padding: EdgeInsets.all(30.w),
      decoration: ShapeDecoration(
        color: kSecondaryTag,
        shape: squircleBorder(
          radius: 36.r,
          side: const BorderSide(color: kAccentYellow),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipSmoothRect(
            radius: squircleRadius(24.r),
            child: Container(
              width: 81.sp,
              height: 81.sp,
              color: Colors.white,
              child: product.image.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl:
                          '${dotenv.env['API_BASE_URL']}/${product.image}',
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(
                        Icons.shopping_bag_outlined,
                        size: 36.sp,
                        color: Colors.grey[300],
                      ),
                    )
                  : Icon(
                      Icons.shopping_bag_outlined,
                      size: 36.sp,
                      color: Colors.grey[300],
                    ),
            ),
          ),
          SizedBox(width: 16.w),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyBold13.copyWith(height: 1.1),
              ),
              Text(
                product.brandName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyRegular10
                    .copyWith(color: Colors.grey[600], height: 1.1),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          GestureDetector(
            onTap: () => setState(() => _selected.remove(product.ean)),
            child: Icon(Icons.close, size: 64.sp, color: kAccentYellow),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductOfInterest product,
      {bool sponsored = false}) {
    final isSelected = _selected.contains(product.ean);

    return GestureDetector(
      onTap: () => _toggle(product),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(30.w),
        decoration: ShapeDecoration(
          color: isSelected ? kSecondaryTag : Colors.white,
          shape: squircleBorder(
            radius: 36.r,
            side: BorderSide(
              color: isSelected ? kAccentYellow : kBorderDefault,
              width: isSelected ? 2 : 1,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipSmoothRect(
              radius: squircleRadius(24.r),
              child: SizedBox(
                width: 270.w,
                height: 270.w,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    product.image.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl:
                                '${dotenv.env['API_BASE_URL']}/${product.image}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.grey[400],
                              ),
                            ),
                            errorWidget: (_, __, ___) => Icon(
                              Icons.shopping_bag_outlined,
                              size: 64.w,
                              color: Colors.grey[300],
                            ),
                          )
                        : Icon(
                            Icons.shopping_bag_outlined,
                            size: 64.w,
                            color: Colors.grey[300],
                          ),
                    if (sponsored)
                      Positioned(
                        top: 8.h,
                        right: 8.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 4.h),
                          decoration: ShapeDecoration(
                            color: Colors.amber[600],
                            shape: squircleBorder(radius: 12.r),
                          ),
                          child: Text(
                            '★',
                            style: TextStyle(
                              fontSize: 40.sp,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              product.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium15.copyWith(height: 1.2),
            ),
            Text(
              product.brandName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyRegular13
                  .copyWith(color: Colors.grey[500], height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  // Card content is a fixed 270.w image box + 30.w padding on every side +
  // two lines of text (no longer an Expanded image stretched to fill the
  // cell), so the aspect ratio only needs to be tall enough to fit that
  // fixed height under a ~1/3-of-width column — unlike a stretched image,
  // it doesn't need to track the column width exactly.
  SliverGridDelegate get _gridDelegate =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 30.w,
        mainAxisSpacing: 30.h,
        childAspectRatio: 0.7,
      );

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final sponsored = _sponsoredFiltered;
    final regular = _regular;
    final hasResults = sponsored.isNotEmpty || regular.isNotEmpty;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Filtrer par produit',
            style: AppTextStyles.baloo22.copyWith(fontWeight: const FontWeight(500)),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kTextPrimary,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              SizedBox(height: 12.h),
              // Search field
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 48.w),
                child: Container(
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
                    onChanged: (v) => setState(() => _search = v),
                    style: AppTextStyles.bodyRegular15,
                    decoration: InputDecoration(
                      hintText: 'Nom du produit ou marque…',
                      hintStyle: AppTextStyles.bodyRegular15
                          .copyWith(color: Colors.grey[500]),
                      prefixIcon: Image.asset(
                        'lib/assets/images/icons/search-line.webp',
                        width: 60.sp,
                        height: 60.sp,
                        color: Colors.grey[600],
                        colorBlendMode: BlendMode.srcIn,
                      ),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 36.sp),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                            )
                          : null,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 39.w, vertical: 33.h),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              // Category chips — search applies within the selected category
              if (_categories.isNotEmpty) ...[
                SizedBox(height: 30.h),
                SizedBox(
                  height: 130.h,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 48.w),
                    itemCount: _categories.length + 1,
                    separatorBuilder: (_, __) => SizedBox(width: 24.w),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return _buildCategoryChip(
                          label: 'Tout',
                          isSelected: _selectedCategory == null,
                          onTap: () =>
                              setState(() => _selectedCategory = null),
                        );
                      }
                      final category = _categories[i - 1];
                      return _buildCategoryChip(
                        label: category.name,
                        image: category.image,
                        isSelected: _selectedCategory == category,
                        onTap: () => setState(() => _selectedCategory =
                            _selectedCategory == category ? null : category),
                      );
                    },
                  ),
                ),
              ],
              // Selection status + clear-all, only shown when a selection
              // exists — clearer than a lone "Effacer" in the app bar.
              if (_selected.isNotEmpty) ...[
                SizedBox(height: AppSpacing.section),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 48.w),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Filtres (${_selected.length})',
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.baloo22,
                        ),
                      ),
                      SizedBox(width: 24.w),
                      GestureDetector(
                        onTap: () => setState(() => _selected.clear()),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 32.w, vertical: 16.h),
                          decoration: ShapeDecoration(
                            color: kAccentYellow,
                            shape: squircleBorder(radius: 42.r),
                          ),
                          child: Text(
                            'Tout supprimer',
                            style: AppTextStyles.bodyBold11
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                Builder(builder: (_) {
                  final chips = _selected
                      .map((ean) => _products
                          .cast<ProductOfInterest?>()
                          .firstWhere((p) => p!.ean == ean, orElse: () => null))
                      .whereType<ProductOfInterest>()
                      .toList();
                  return SizedBox(
                    height: 150.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 48.w),
                      itemCount: chips.length,
                      separatorBuilder: (_, __) => SizedBox(width: 24.w),
                      itemBuilder: (_, i) => _buildFilterChip(chips[i]),
                    ),
                  );
                }),
              ],
              SizedBox(height: AppSpacing.section),
              // Product grid
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: 48.w),
                  children: [
                    if (_isLoading)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.w),
                          child: CircularProgressIndicator(
                              color: Colors.grey[400]),
                        ),
                      )
                    else if (!hasResults)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.w),
                          child: Text(
                            'Aucun produit trouvé',
                            style: TextStyle(
                              fontSize: 38.sp,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ),
                    if (sponsored.isNotEmpty) ...[
                      Text(
                        'Produits mis en avant',
                        style: TextStyle(
                          fontSize: 40.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber[700],
                        ),
                      ),
                      SizedBox(height: 24.h),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: _gridDelegate,
                        itemCount: sponsored.length,
                        itemBuilder: (_, i) =>
                            _buildProductCard(sponsored[i], sponsored: true),
                      ),
                      SizedBox(height: 36.h),
                    ],
                    if (regular.isNotEmpty) ...[
                      if (sponsored.isNotEmpty) ...[
                        Text(
                          'Tous les produits',
                          style: TextStyle(
                            fontSize: 40.sp,
                            fontWeight: FontWeight.w600,
                            color: kTextPrimary,
                          ),
                        ),
                        SizedBox(height: 24.h),
                      ],
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: _gridDelegate,
                        itemCount: regular.length,
                        itemBuilder: (_, i) => _buildProductCard(regular[i]),
                      ),
                    ],
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
              // Apply button
              Padding(
                padding: EdgeInsets.fromLTRB(48.w, 24.h, 48.w, 24.h),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(Set.from(_selected));
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      shape: squircleBorder(radius: 42.r),
                      elevation: 0,
                    ),
                    child: Text(
                      _selected.isEmpty
                          ? 'Voir tous les commerces'
                          : 'Appliquer · ${_selected.length} produit${_selected.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 42.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
