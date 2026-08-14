import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/helper.dart';
import 'package:vegan_app/models/scan_result.dart';
import 'package:vegan_app/services/subscription_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/widgets/scaner/product_scores_section.dart';
import 'package:vegan_app/widgets/scaner/scan_result_card.dart';

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
  final bool showScores;

  const RejectedProductInfoCard({
    super.key,
    required this.productInfo,
    this.showScores = true,
  });

  @override
  Widget build(BuildContext context) {
    final reason = productInfo.problem;
    final brand = productInfo.brand;

    return ScanResultCard(
      name: Helper.truncate(
        productInfo.name.isNotEmpty ? productInfo.name : 'Produit inconnu',
        45,
      ),
      brand: (() {
        if (brand.isEmpty) return 'Marque inconnue';
        var formatted = '${brand[0].toUpperCase()}${brand.substring(1)}';
        if (formatted.length > 30) formatted = '${formatted.substring(0, 30)}...';
        return formatted;
      })(),
      accentColor: kSemanticError,
      statusIcon: Image.asset(
        'lib/assets/images/icons/solid-close.webp',
        width: 64.w,
        height: 64.w,
        color: kSemanticError,
        colorBlendMode: BlendMode.srcIn,
      ),
      statusLabel: reason != null ? 'Non-végan : $reason' : 'Non-végan',
      // Nothing to gate on a "not vegan" result, so scores show unlocked.
      scores: ProductScoresSection(
        barcode: productInfo.code,
        isSubscribed: SubscriptionService.isSubscribed,
        paywalled: false,
        enabled: showScores,
      ),
    );
  }
}
