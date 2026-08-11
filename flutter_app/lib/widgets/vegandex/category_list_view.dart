import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import '../../models/product_category.dart';
import '../../models/product_of_interest.dart';
import '../../themes/app_shapes.dart';

class CategoryListView extends StatelessWidget {
  final List<ProductCategory> categories;
  final List<ProductOfInterest> products;
  final Map<String, dynamic> scannedProducts;
  final Function(ProductCategory) onCategoryTap;

  const CategoryListView({
    super.key,
    required this.categories,
    required this.products,
    required this.scannedProducts,
    required this.onCategoryTap,
  });

  String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'https://api.321vegan.fr';

  int _getScannedCountForCategory(int categoryId) {
    return products
        .where((p) =>
            p.categoryId == categoryId && scannedProducts.containsKey(p.ean))
        .length;
  }

  int _getTotalCountForCategory(int categoryId) {
    return products.where((p) => p.categoryId == categoryId).length;
  }

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 120.sp,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16.h),
            Text(
              'Aucune catégorie disponible',
              style: TextStyle(
                fontSize: 48.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(24.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16.w,
        mainAxisSpacing: 16.h,
        childAspectRatio: 1,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final scannedCount = _getScannedCountForCategory(category.id);
        final totalCount = _getTotalCountForCategory(category.id);

        return _buildCategoryCard(
          context,
          category,
          scannedCount,
          totalCount,
        );
      },
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    ProductCategory category,
    int scannedCount,
    int totalCount,
  ) {
    return GestureDetector(
      onTap: () => onCategoryTap(category),
      child: Container(
        decoration: ShapeDecoration(
          shape: squircleBorder(radius: 20.r),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipSmoothRect(
          radius: squircleRadius(20.r),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: '$baseUrl/${category.image}',
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
              // Progress indicator on top left
              Positioned(
                top: 12.h,
                left: 12.w,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: ShapeDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: squircleBorder(radius: 12.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 40.sp,
                        color: scannedCount == totalCount
                            ? const Color(0xFF1A722E)
                            : Colors.grey[600],
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        '$scannedCount / $totalCount',
                        style: TextStyle(
                          fontSize: 36.sp,
                          fontWeight: FontWeight.bold,
                          color: scannedCount == totalCount
                              ? const Color(0xFF1A722E)
                              : Colors.grey[800],
                        ),
                      ),
                    ],
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
