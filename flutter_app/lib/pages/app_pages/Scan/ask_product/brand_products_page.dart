import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:vegan_app/models/askable_product.dart';

/// Lists a brand's askable products, each shown with its photo and a scannable
/// EAN-13 barcode the store owner can scan with their handheld scanner.
///
/// While this page is open the screen brightness is maxed out so a store's
/// handheld scanner can reliably read the barcode off the screen; it is
/// restored when the page is left.
class BrandProductsPage extends StatefulWidget {
  final AskableBrand brand;

  const BrandProductsPage({super.key, required this.brand});

  @override
  State<BrandProductsPage> createState() => _BrandProductsPageState();
}

class _BrandProductsPageState extends State<BrandProductsPage> {
  static const Color _primary = Color(0xFF1A722E);

  @override
  void initState() {
    super.initState();
    _maxBrightness();
  }

  Future<void> _maxBrightness() async {
    try {
      await ScreenBrightness().setApplicationScreenBrightness(1.0);
    } catch (_) {
      // Brightness control is best-effort; ignore platform failures.
    }
  }

  @override
  void dispose() {
    // Restore the user's original brightness when leaving the page.
    ScreenBrightness().resetApplicationScreenBrightness().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = widget.brand;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: Text(
          'Produits ${brand.name}',
          style: TextStyle(
            fontSize: 50.sp,
            fontWeight: FontWeight.bold,
            fontFamily: 'Baloo',
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(40.w, 24.h, 40.w, 80.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 24.h),
              child: Text(
                'Montrez un code-barres au responsable du magasin pour qu\'il '
                'le scanne avec sa douchette.',
                style: TextStyle(
                  fontSize: 38.sp,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ),
            ...brand.products.map(
              (p) => Padding(
                padding: EdgeInsets.only(bottom: 28.h),
                child: _ProductCard(product: p),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final AskableProduct product;

  const _ProductCard({required this.product});

  static const Color _primary = Color(0xFF1A722E);

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Photo on a soft tinted header.
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 16.h),
            color: _primary.withValues(alpha: 0.06),
            child: Image.asset(
              product.imageAsset,
              height: 520.h,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => SizedBox(
                height: 520.h,
                child: Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: _primary.withValues(alpha: 0.25),
                    size: 120.sp,
                  ),
                ),
              ),
            ),
          ),
          // Product name.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            child: Text(
              product.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 46.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[850],
                fontFamily: 'Baloo',
              ),
            ),
          ),
          // Scannable barcode footer — kept compact and centered.
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 20.h),
            child: BarcodeWidget(
              // EAN-8 for 8-digit codes, EAN-13 otherwise (matches the
              // formats the in-app scanner accepts).
              barcode: product.ean.length == 8
                  ? Barcode.ean8()
                  : Barcode.ean13(),
              data: product.ean,
              width: 600.w,
              height: 110.h,
              drawText: true,
              style: TextStyle(fontSize: 24.sp, color: Colors.black87),
              errorBuilder: (_, error) => Padding(
                padding: EdgeInsets.all(12.w),
                child: Text(
                  'Code invalide : ${product.ean}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24.sp, color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
