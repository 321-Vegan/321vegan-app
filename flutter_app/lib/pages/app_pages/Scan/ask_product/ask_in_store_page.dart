import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/data/askable_products.dart';
import 'package:vegan_app/models/askable_product.dart';
import 'package:vegan_app/pages/app_pages/Scan/ask_product/brand_products_page.dart';

/// Tutorial page explaining how to ask a store to add a missing product, with
/// per-brand entry buttons (e.g. "Produits Happyvore") leading to the list of
/// scannable barcodes.
class AskInStorePage extends StatelessWidget {
  const AskInStorePage({super.key});

  static const Color _primary = Color(0xFF1A722E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: Text(
          'Demander en magasin',
          style: TextStyle(
            fontSize: 50.sp,
            fontWeight: FontWeight.bold,
            fontFamily: 'Baloo',
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(40.w, 32.h, 40.w, 80.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 32.h),
            _buildIntro(),
            SizedBox(height: 32.h),
            ..._buildSteps(),
            SizedBox(height: 40.h),
            Text(
              'Choisissez une marque',
              style: TextStyle(
                fontSize: 46.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                fontFamily: 'Baloo',
              ),
            ),
            SizedBox(height: 16.h),
            ...askableBrands.map((brand) => _buildBrandButton(context, brand)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.storefront, color: _primary, size: 70.sp),
        ),
        SizedBox(width: 20.w),
        Expanded(
          child: Text(
            'Un produit manque en magasin ?',
            style: TextStyle(
              fontSize: 52.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[850],
              fontFamily: 'Baloo',
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntro() {
    return Text(
      'Vous pouvez demander au responsable du magasin d\'ajouter ce produit '
      'à sa liste d\'achats. Le plus simple : montrez-lui le code-barres, '
      'il pourra le scanner directement avec sa douchette.',
      style: TextStyle(
        fontSize: 40.sp,
        color: Colors.grey[700],
        height: 1.5,
      ),
    );
  }

  List<Widget> _buildSteps() {
    const steps = [
      'Repérez le responsable ou un employé du rayon.',
      'Demandez-lui s\'il peut ajouter le produit à sa liste de commande.',
      'Montrez-lui le code-barres',
      'Le produit pourra ainsi être référencé et mis en rayon !',
    ];
    return [
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: 20.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64.w,
                height: 64.w,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 20.w),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 6.h),
                  child: Text(
                    steps[i],
                    style: TextStyle(
                      fontSize: 40.sp,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _buildBrandButton(BuildContext context, AskableBrand brand) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: InkWell(
        borderRadius: BorderRadius.circular(20.r),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BrandProductsPage(brand: brand),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
          child: Center(
            // A big tappable brand logo. The logo is a wordmark, so it
            // stands in for the "Produits <marque>" label; if it fails to
            // load we fall back to that text.
            child: brand.logoAsset != null
                ? Image.asset(
                    brand.logoAsset!,
                    height: 240.h,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _brandLabel(brand),
                  )
                : _brandLabel(brand),
          ),
        ),
      ),
    );
  }

  Widget _brandLabel(AskableBrand brand) {
    return Text(
      'Produits ${brand.name}',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 46.sp,
        fontWeight: FontWeight.bold,
        color: Colors.grey[850],
        fontFamily: 'Baloo',
      ),
    );
  }
}
