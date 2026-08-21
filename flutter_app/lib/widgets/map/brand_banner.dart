import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vegan_app/models/product_of_interest.dart';
import 'package:vegan_app/themes/app_shapes.dart';

class BrandBanner extends StatelessWidget {
  final List<ProductOfInterest> products;
  final String brandName;
  final Color color;
  final Color? gradientEnd;
  final Widget? logo;

  const BrandBanner({
    super.key,
    required this.products,
    required this.brandName,
    this.color = Colors.lightBlue,
    this.gradientEnd,
    this.logo,
  });

  String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://api.321vegan.fr';

  void _showProductsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: squircleBorderOnly(topLeft: 16, topRight: 16),
      builder: (_) => Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 12.h),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Text(
              'Produits $brandName disponibles',
              style: TextStyle(
                fontSize: 54.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            ...products.map((product) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  child: Row(
                    children: [
                      ClipSmoothRect(
                        radius: squircleRadius(8.r),
                        child: SizedBox(
                          width: 160.w,
                          height: 160.w,
                          child: product.image.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: '$_baseUrl/${product.image}',
                                  fit: BoxFit.contain,
                                )
                              : Container(
                                  color: Colors.grey[200],
                                  child: Icon(Icons.image,
                                      color: Colors.grey[400]),
                                ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 44.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    final endColor = gradientEnd ?? color.withValues(alpha: 0.7);

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: GestureDetector(
        onTap: () => _showProductsModal(context),
        child: Container(
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, endColor],
            ),
            shape: squircleBorder(radius: 16.r),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  children: [
                    // Logo
                    if (logo != null)
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: squircleBorder(radius: 12.r),
                        ),
                        child: logo,
                      )
                    else
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: ShapeDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: squircleBorder(radius: 12.r),
                        ),
                        child: Icon(Icons.storefront,
                            color: Colors.white, size: 32.r),
                      ),
                    SizedBox(width: 14.w),
                    // Text + CTA
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Disponible ici',
                            style: TextStyle(
                              fontSize: 34.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '${products.length} produit${products.length > 1 ? 's' : ''} $brandName',
                            style: TextStyle(
                              fontSize: 48.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Arrow
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 100.r,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
