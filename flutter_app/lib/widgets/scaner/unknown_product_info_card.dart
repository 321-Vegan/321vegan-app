import 'package:flutter/material.dart';
import 'package:vegan_app/models/scan_result.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/scaner/scan_result_card.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';

/// Inline result card for a scanned product missing from the database
/// ([ScanStatus.unknown]) or submitted before but still unidentified
/// ([ScanStatus.notFound]). Shown alongside the live camera feed just like
/// the vegan/non-vegan/pending cards, instead of popping
/// [UnknownProductModal] automatically the moment the status resolves —
/// that used to block the scanner on every misread, with only a short timer
/// to let a follow-up read save the user. The submission sheet now only
/// opens once the user taps in, so a misread has as long as it takes to
/// notice instead of a fixed grace period.
class UnknownProductInfoCard extends StatelessWidget {
  final ScanResult productInfo;
  final VoidCallback onSendInfo;

  const UnknownProductInfoCard({
    super.key,
    required this.productInfo,
    required this.onSendInfo,
  });

  bool get _alreadySubmitted => productInfo.status == ScanStatus.notFound;

  @override
  Widget build(BuildContext context) {
    return ScanResultCard(
      name: productInfo.name.isNotEmpty ? productInfo.name : 'Produit inconnu',
      brand:
          productInfo.brand.isNotEmpty ? productInfo.brand : 'Marque inconnue',
      accentColor: kAccentYellow,
      statusIcon: ScanResultCard.circleIcon(
        Icons.send,
        kAccentYellow,
      ),
      statusLabel:
          _alreadySubmitted ? 'Informations manquantes' : 'Produit non-référencé',
      extraRows: [
        Text(
          _alreadySubmitted
              ? "Ce produit nous a déjà été envoyé mais il nous manque des "
                  "informations pour le traiter."
              : "Ce produit n'est pas encore dans notre base de données.",
          style: AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[600]),
        ),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label:
                _alreadySubmitted ? 'Envoyer des infos' : 'Envoyer le produit',
            backgroundColor: kAccentYellow,
            onPressed: onSendInfo,
          ),
        ),
      ],
    );
  }
}
