import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/models/product_category.dart';
import 'package:vegan_app/models/product_of_interest.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/services/products_of_interest_cache.dart';
import 'package:vegan_app/themes/app_colors.dart';
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
  List<ProductOfInterest> _products = [];
  List<ProductCategory> _categories = [];
  ProductCategory? _selectedCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedEans);
    _loadProducts();
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
        padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 20.h),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(42.r),
          border: Border.all(
            color: isSelected ? primaryColor : kBorderDefault,
            width: isSelected ? 1.5 : 1,
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
                fontSize: 40.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? primaryColor : kTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductOfInterest product,
      {bool sponsored = false}) {
    final isSelected = _selected.contains(product.ean);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () => _toggle(product),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(48.r),
                border: Border.all(
                  color: isSelected ? primaryColor : kBorderDefault,
                  width: isSelected ? 2 : 1,
                ),
              ),
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
                        decoration: BoxDecoration(
                          color: Colors.amber[600],
                          borderRadius: BorderRadius.circular(12.r),
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
            style: TextStyle(
              fontSize: 40.sp,
              fontWeight: FontWeight.w600,
              color: isSelected ? primaryColor : kTextPrimary,
              height: 1.2,
            ),
          ),
          Text(
            product.brandName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 36.sp,
              color: Colors.grey[500],
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  SliverGridDelegate get _gridDelegate =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 30.w,
        mainAxisSpacing: 36.h,
        childAspectRatio: 0.68,
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
          title: const Text(
            'Filtrer par produit',
            style: TextStyle(
            fontFamily: 'Baloo2',
            fontWeight: FontWeight.bold
            ),
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
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v),
                  style: TextStyle(fontSize: 42.sp),
                  decoration: InputDecoration(
                    hintText: 'Nom du produit ou marque…',
                    hintStyle:
                        TextStyle(fontSize: 42.sp, color: Colors.grey[500]),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 60.sp,
                      color: Colors.grey[600],
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
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 30.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(42.r),
                      borderSide: BorderSide.none,
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
                SizedBox(height: 24.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 48.w),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selected.length} produit${_selected.length > 1 ? 's' : ''} sélectionné${_selected.length > 1 ? 's' : ''}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 38.sp,
                            fontWeight: FontWeight.w600,
                            color: kTextPrimary,
                          ),
                        ),
                      ),
                      SizedBox(width: 24.w),
                      GestureDetector(
                        onTap: () => setState(() => _selected.clear()),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 28.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(42.r),
                            border: Border.all(color: kBorderDefault),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close,
                                  size: 40.sp, color: Colors.grey[600]),
                              SizedBox(width: 8.w),
                              Text(
                                'Tout effacer',
                                style: TextStyle(
                                  fontSize: 36.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 24.h),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(42.r),
                      ),
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
