import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/product_category.dart';
import '../../models/product_of_interest.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../shared/empty_state_view.dart';

class CategoryProductsView extends StatelessWidget {
  final ProductCategory category;
  final List<ProductOfInterest> allProducts;
  final Map<String, dynamic> scannedProducts;
  final VoidCallback onBack;

  const CategoryProductsView({
    super.key,
    required this.category,
    required this.allProducts,
    required this.scannedProducts,
    required this.onBack,
  });

  List<ProductOfInterest> _getProductsForCategory() {
    final filtered = allProducts
        .where((product) => product.categoryId == category.id)
        .toList();

    // Sort by brand name first, then by product name
    filtered.sort((a, b) {
      final brandComparison = a.brandName.compareTo(b.brandName);
      if (brandComparison != 0) return brandComparison;
      return a.name.compareTo(b.name);
    });

    return filtered;
  }

  bool _isProductScanned(String ean) {
    return scannedProducts.containsKey(ean);
  }

  @override
  Widget build(BuildContext context) {
    final products = _getProductsForCategory();
    final scannedCount = products.where((p) => _isProductScanned(p.ean)).length;
    final baseUrl = dotenv.env['API_BASE_URL'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with back button; name + count centered as a group, with a
        // trailing spacer matching the back button so the centering is
        // symmetric (same idea as AppBar's centerTitle).
        Row(
          children: [
            SizedBox(
              width: 96.w,
              child: IconButton(
                onPressed: onBack,
                icon: Icon(Icons.arrow_back, size: 64.sp, color: Colors.grey[700]),
              ),
            ),
            Expanded(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.baloo26.copyWith(fontWeight: const FontWeight(600)),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                      decoration: const ShapeDecoration(
                        color: kSecondaryTag,
                        shape: StadiumBorder(),
                      ),
                      child: Text(
                        '$scannedCount/${products.length}',
                        style: AppTextStyles.bodyBold11.copyWith(color: kAccentYellow),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 96.w),
          ],
        ),
        SizedBox(height: AppSpacing.afterTitle),

        // Products grid
        Expanded(
          child: products.isEmpty
              ? const EmptyStateView(
                  title: 'Aucun produit dans cette catégorie',
                  subtitle: 'Revenez plus tard, de nouveaux produits arrivent !',
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    const crossAxisCount = 3;
                    final spacing = 16.w;
                    final cellWidth = (constraints.maxWidth -
                            spacing * (crossAxisCount - 1)) /
                        crossAxisCount;
                    final cardHeight = cellWidth + 180.h;
                    return GridView.builder(
                      padding: EdgeInsets.only(bottom: AppSpacing.section),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: 16.h,
                        mainAxisExtent: cardHeight,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final isScanned = _isProductScanned(product.ean);
                        return _buildProductCard(product, isScanned, baseUrl);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductCard(
      ProductOfInterest product, bool isScanned, String? baseUrl) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(radius: 24.r, side: const BorderSide(color: kBorderDefault)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                ClipSmoothRect(
                  radius: squircleRadius(16.r),
                  child: ColorFiltered(
                    colorFilter: isScanned
                        ? const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.multiply,
                          )
                        : const ColorFilter.mode(
                            Colors.grey,
                            BlendMode.saturation,
                          ),
                    child: CachedNetworkImage(
                      imageUrl: '$baseUrl/${product.image}',
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.grey[400],
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        return Container(
                          color: Colors.grey[100],
                          child: Icon(
                            Icons.image_not_supported,
                            size: 48.sp,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (isScanned)
                  Positioned(
                    top: 6.w,
                    right: 6.w,
                    child: Container(
                      padding: EdgeInsets.all(6.w),
                      decoration:
                          const BoxDecoration(color: kSemanticSuccess, shape: BoxShape.circle),
                      child: Icon(Icons.check, size: 64.sp, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium15.copyWith(height: 1.1),
          ),
          Text(
            product.brandName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
