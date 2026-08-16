import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/helper.dart';
import 'package:vegan_app/models/scan_result.dart';
import 'package:vegan_app/services/subscription_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/widgets/scaner/product_scores_section.dart';
import 'package:vegan_app/widgets/scaner/scan_result_card.dart';

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
      statusLabel: reason != null ? 'Non-végane : $reason' : 'Non-végane',
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
