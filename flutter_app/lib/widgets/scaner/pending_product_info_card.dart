import 'package:flutter/material.dart';
import 'package:vegan_app/models/scan_result.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/scaner/scan_result_card.dart';

class PendingProductInfoCard extends StatelessWidget {
  final ScanResult productInfo;

  const PendingProductInfoCard({
    super.key,
    required this.productInfo,
  });

  @override
  Widget build(BuildContext context) {
    return ScanResultCard(
      name: productInfo.name.isNotEmpty ? productInfo.name : 'Produit inconnu',
      brand: productInfo.brand.isNotEmpty ? productInfo.brand : 'Marque inconnue',
      accentColor: kAccentYellow,
      statusIcon: ScanResultCard.circleIcon(
        Icons.hourglass_top_rounded,
        kAccentYellow,
      ),
      statusLabel: 'En cours de validation',
      extraRows: [
        Text(
          "Certains ingrédients de ce produit ne sont pas clairs. Nous "
          "vérifions ce produit avant de l'ajouter à la base de données.",
          style: AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class AlreadyScannedProductInfoCard extends StatelessWidget {
  final ScanResult productInfo;

  const AlreadyScannedProductInfoCard({
    super.key,
    required this.productInfo,
  });

  @override
  Widget build(BuildContext context) {
    return ScanResultCard(
      name: productInfo.name.isNotEmpty ? productInfo.name : 'Produit inconnu',
      brand: productInfo.brand.isNotEmpty ? productInfo.brand : 'Marque inconnue',
      accentColor: kAccentYellow,
      statusIcon: ScanResultCard.circleIcon(
        Icons.hourglass_top_rounded,
        kAccentYellow,
      ),
      statusLabel: 'Déjà envoyé, en cours de validation',
      extraRows: [
        Text(
          "Vous avez déjà soumis ce produit. Nous allons vérifier et "
          "l'ajouter à la base de données. Merci !",
          style: AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}
