import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/helper.dart';
import 'package:vegan_app/models/scan_result.dart';
import 'package:vegan_app/themes/app_shapes.dart';

class NoResultCard extends StatelessWidget {
  const NoResultCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      height: 1000.h,
      padding: const EdgeInsets.all(16.0),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(radius: 20),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            spreadRadius: 5,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 60.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              children: [
                const TextSpan(text: 'Scannez un produit '),
                TextSpan(
                  text: 'alimentaire',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 60.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: ' pour savoir s\'il est vegan !'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Image.asset(
            'lib/assets/app_icon.png',
            height: 300.h,
            fit: BoxFit.cover,
          ),
          const SizedBox(height: 16),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(fontSize: 40.sp, color: Colors.black),
              children: [
                const TextSpan(text: 'Le scan est prévu pour les produits '),
                TextSpan(
                  text: 'alimentaires',
                  style: TextStyle(color: Colors.green.shade700),
                ),
                const TextSpan(
                    text:
                        ' uniquement. \nPour l\'instant nous ne pouvont pas traiter les produits '),
                TextSpan(
                  text: 'cosmétiques',
                  style: TextStyle(color: Colors.red.shade700),
                ),
                const TextSpan(text: ', merci de ne pas en envoyer !'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RejectedProductInfoCard extends StatelessWidget {
  final ScanResult productInfo;

  const RejectedProductInfoCard({
    super.key,
    required this.productInfo,
  });

  @override
  Widget build(BuildContext context) {
    final reason = productInfo.problem;
    final brand = productInfo.brand;

    return Container(
      height: 740.h,
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade200],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        shape: squircleBorder(
          radius: 30,
          side: const BorderSide(
            color: Colors.red,
            width: 3,
          ),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            spreadRadius: 5,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Helper.truncate(
                productInfo.name.isNotEmpty
                    ? productInfo.name
                    : 'Unnamed Product',
                45,
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 70.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              (() {
                if (brand.isNotEmpty) {
                  // Capitalize the first letter and keep the rest
                  String formattedBrand =
                      '${brand[0].toUpperCase()}${brand.substring(1)}';
                  if (formattedBrand.length > 30) {
                    // Truncate and add ellipsis
                    formattedBrand = '${formattedBrand.substring(0, 30)}...';
                  }
                  return formattedBrand;
                }
                // Default text
                return 'Marque inconnue';
              })(),
              style: TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            // Add a text for the reason
            const SizedBox(height: 16),
            Text(
              "Pas Vegan !",
              style: TextStyle(
                fontSize: 80.sp,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            if (reason != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
