import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/helper.dart';
import 'package:vegan_app/models/boycott_data.dart';
import 'package:vegan_app/models/scan_result.dart';
import 'package:vegan_app/services/subscription_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/scaner/info_modal.dart';
import 'package:vegan_app/widgets/scaner/product_scores_section.dart';
import 'package:vegan_app/widgets/scaner/scan_result_card.dart';

class VeganProductInfoCard extends StatelessWidget {
  final ScanResult productInfo;
  final bool showBoycott;
  final bool showScores;
  final VoidCallback? onScoresDisable;

  const VeganProductInfoCard({
    super.key,
    required this.productInfo,
    this.showBoycott = true,
    this.showScores = true,
    this.onScoresDisable,
  });

  BoycottMatch? getBoycottMatch() {
    final brand = productInfo.brand;
    if (brand.isNotEmpty) {
      return BoycottData.findBrand(brand);
    }
    return null;
  }

  Widget _buildWarningChip(
    BuildContext context, {
    required String label,
    required String description,
    String? body,
    BoycottMatch? boycottMatch,
  }) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => InfoModal(
            description: description,
            body: body,
            boycottMatch: boycottMatch,
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
        decoration: ShapeDecoration(
          color: kSemanticError.withValues(alpha: 0.12),
          shape: squircleBorder(radius: 30.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.thumb_down, color: kSemanticError, size: 36.sp),
            SizedBox(width: 8.w),
            Text(
              label,
              style: AppTextStyles.bodyMedium13.copyWith(color: kSemanticError),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final BoycottMatch? boycottMatch = getBoycottMatch();
    final bool isBoycotted = boycottMatch != null;

    return ScanResultCard(
      name: Helper.truncate(
        productInfo.name.isNotEmpty ? productInfo.name : 'Produit inconnu',
        45,
      ),
      brand: (() {
        final brand = productInfo.brand;
        if (brand.isEmpty) return 'Marque inconnue';
        var formatted = '${brand[0].toUpperCase()}${brand.substring(1)}';
        if (formatted.length > 30) formatted = '${formatted.substring(0, 30)}...';
        return formatted;
      })(),
      accentColor: kSemanticSuccess,
      statusIcon: Image.asset(
        'lib/assets/images/icons/solid-check.webp',
        width: 64.w,
        height: 64.w,
        color: kSemanticSuccess,
        colorBlendMode: BlendMode.srcIn,
      ),
      statusLabel: 'Végane',
      scores: ProductScoresSection(
        barcode: productInfo.code,
        isSubscribed: SubscriptionService.isSubscribed,
        enabled: showScores,
        onDisable: onScoresDisable,
      ),
      extraRows: [
        if (isBoycotted && showBoycott)
          _buildWarningChip(
            context,
            label: 'À éviter',
            description:
                "Les produits notés 'À éviter' sont des produits de marques qui ont des actions néfastes pour l'environnement, la santé, les droits des animaux ou les droits humains. Nous vous encourageons à boycotter ces marques pour soutenir des pratiques éthiques et responsables.",
            boycottMatch: boycottMatch,
          )
        else if (productInfo.biodynamic)
          _buildWarningChip(
            context,
            label: 'Biodynamie',
            body:
                "La biodynamie est une méthode agricole qui utilise des préparations d'origine animale, telles que des cornes de vache ou des organes d'animaux, dans ses pratiques de culture. Cette approche est issue de l'anthroposophie, un courant ésotérique aux dérives parfois considérées comme sectaires.",
            description:
                "En raison de l'utilisation d'éléments animaux et de son ancrage idéologique, nous ne considérons pas les produits issus de la biodynamie comme compatibles avec les principes du véganisme.",
          ),
      ],
    );
  }
}
