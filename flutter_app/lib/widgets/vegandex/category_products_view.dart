import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import '../../models/product_category.dart';
import '../../models/product_of_interest.dart';
import '../../themes/app_shapes.dart';

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
    final baseUrl = dotenv.env['API_BASE_URL'];

    return Column(
      children: [
        // Header with back button
        GestureDetector(
          onTap: onBack,
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: Icon(
                  Icons.arrow_back,
                  size: 80.sp,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 56.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      '${products.length} produit${products.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 40.sp,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Products grid
        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 120.sp,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Aucun produit dans cette catégorie',
                        style: TextStyle(
                          fontSize: 48.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.all(24.w),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16.w,
                    mainAxisSpacing: 16.h,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final isScanned = _isProductScanned(product.ean);
                    return _buildProductCard(product, isScanned, baseUrl);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductCard(
      ProductOfInterest product, bool isScanned, String? baseUrl) {
    return Container(
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 20.r,
          side: BorderSide(
            color: isScanned
                ? const Color(0xFF1A722E).withValues(alpha: 0.3)
                : Colors.grey[300]!,
            width: 2,
          ),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product image
          Expanded(
            flex: 3,
            child: ClipSmoothRect(
              radius: squircleRadius(18.r),
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
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.image_not_supported,
                        size: 80.sp,
                        color: Colors.grey[400],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Product info
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: ShapeDecoration(
                  color: isScanned ? Colors.grey.shade100 : Colors.grey.shade50,
                  shape: squircleBorder(radius: 16.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Product name
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 40.sp,
                        fontWeight: FontWeight.w700,
                        color: isScanned
                            ? Colors.grey.shade900
                            : Colors.grey.shade600,
                        height: 1.2,
                      ),
                    ),

                    SizedBox(height: 6.h),

                    // Brand
                    Text(
                      product.brandName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 40.sp,
                        fontWeight: FontWeight.w500,
                        color: isScanned
                            ? Colors.grey.shade700
                            : Colors.grey.shade400,
                      ),
                    ),

                    SizedBox(height: 14.h),

                    // Scan count
                    Row(
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 40.sp,
                          color: isScanned
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Scanné ${scannedProducts[product.ean]?.scanCount ?? 0} fois',
                          style: TextStyle(
                            fontSize: 40.sp,
                            color: isScanned
                                ? Colors.grey.shade600
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
