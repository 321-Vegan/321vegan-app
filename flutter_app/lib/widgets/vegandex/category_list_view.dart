import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/product_category.dart';
import '../../models/product_of_interest.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_card.dart';
import '../shared/empty_state_view.dart';

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
      return const EmptyStateView(
        title: 'Aucune catégorie disponible',
        subtitle: 'Revenez plus tard, de nouvelles catégories arrivent !',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 48.w, vertical: 24.h),
      itemCount: categories.length,
      separatorBuilder: (_, __) => SizedBox(height: AppSpacing.item),
      itemBuilder: (context, index) {
        final category = categories[index];
        final scannedCount = _getScannedCountForCategory(category.id);
        final totalCount = _getTotalCountForCategory(category.id);

        return _buildCategoryRow(context, category, scannedCount, totalCount);
      },
    );
  }

  Widget _buildCategoryRow(
    BuildContext context,
    ProductCategory category,
    int scannedCount,
    int totalCount,
  ) {
    return GestureDetector(
      onTap: () => onCategoryTap(category),
      child: AppCard(
        padding: EdgeInsets.all(20.w),
        child: Row(
          children: [
            Container(
              width: 124.w,
              height: 124.w,
              padding: EdgeInsets.all(20.w),
              decoration: ShapeDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: squircleBorder(radius: 24.r),
              ),
              child: Image.asset('lib/assets/white_icon.png'),
            ),
            SizedBox(width: 24.w),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.baloo17,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                    decoration: const ShapeDecoration(
                      color: kSecondaryTag,
                      shape: StadiumBorder(),
                    ),
                    child: Text(
                      '$scannedCount/$totalCount',
                      style:
                          AppTextStyles.bodyBold11.copyWith(color: kAccentYellow),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Icon(Icons.arrow_forward, size: 64.sp, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }
}
