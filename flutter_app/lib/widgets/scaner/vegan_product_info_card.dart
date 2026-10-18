import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/helper.dart';
import 'package:vegan_app/models/boycott_data.dart';
import 'package:vegan_app/models/scan_result.dart';
import 'package:vegan_app/services/subscription_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/widgets/scaner/info_modal.dart';
import 'package:vegan_app/widgets/scaner/product_rating_pill.dart';
import 'package:vegan_app/widgets/scaner/product_scores_section.dart';
import 'package:vegan_app/widgets/scaner/scan_result_card.dart';
import 'package:vegan_app/widgets/shared/tag_chip.dart';

class VeganProductInfoCard extends StatelessWidget {
  final ScanResult productInfo;
  final bool showBoycott;
  final bool showScores;
  final VoidCallback? onScoresDisable;

  /// Pause/resume the camera while the ratings sheet is open.
  final VoidCallback? onScannerStop;
  final VoidCallback? onScannerStart;

  /// Product rating, provided by the scan page (null while unknown).
  final double? ratingAverage;
  final int? ratingCount;
  final VoidCallback? onRatingSheetClosed;

  const VeganProductInfoCard({
    super.key,
    required this.productInfo,
    this.showBoycott = true,
    this.showScores = true,
    this.onScoresDisable,
    this.onScannerStop,
    this.onScannerStart,
    this.ratingAverage,
    this.ratingCount,
    this.onRatingSheetClosed,
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
    return TagChip(
      label: label,
      icon: Icons.thumb_down,
      color: kSemanticError,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final BoycottMatch? boycottMatch = getBoycottMatch();
    final bool isBoycotted = boycottMatch != null;
    final Color accentColor =
        productInfo.biodynamic ? kAccentYellow : kSemanticSuccess;

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
      accentColor: accentColor,
      statusIcon: Image.asset(
        'lib/assets/images/icons/solid-check.webp',
        width: 64.w,
        height: 64.w,
        color: accentColor,
        colorBlendMode: BlendMode.srcIn,
      ),
      statusLabel: productInfo.biodynamic ? 'Végétalien' : 'Végane',
      brandAnswer: productInfo.brandAnswer,
      scores: ProductScoresSection(
        barcode: productInfo.code,
        isSubscribed: SubscriptionService.isSubscribed,
        enabled: showScores,
        onDisable: onScoresDisable,
      ),
      extraRows: [
        Wrap(
          spacing: 16.w,
          runSpacing: 12.h,
          children: [
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
            // Biodynamic products aren't considered vegan: not rated.
            if (!productInfo.biodynamic)
              ProductRatingPill(
                barcode: productInfo.code,
                productName: productInfo.name,
                brandName: productInfo.brand,
                average: ratingAverage,
                count: ratingCount,
                onScannerStop: onScannerStop,
                onScannerStart: onScannerStart,
                onSheetClosed: onRatingSheetClosed,
              ),
          ],
        ),
      ],
    );
  }
}
