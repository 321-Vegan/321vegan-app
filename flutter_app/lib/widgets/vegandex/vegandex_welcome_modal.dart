import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/bottom_sheet_shell.dart';

/// First-launch intro sheet for the Vegandex, shown once from
/// [VegandexModal]. Pops `true` when dismissed via "C'est parti !" so the
/// caller can mark it as seen for good — swiping the sheet away otherwise
/// leaves it eligible to show again next time. There is no separate "don't
/// show again" opt-out.
class VegandexWelcomeModal extends StatelessWidget {
  const VegandexWelcomeModal({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Trouvez-les tous !',
            style: AppTextStyles.baloo26,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 62.h),
          Image.asset(
            'lib/assets/images/vegandex.webp',
            height: 420.h,
          ),
          SizedBox(height: 32.h),
          Text(
            'Scannez ces produits pour les collectionner dans votre Vegandex.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyRegular15.copyWith(color: Colors.grey[600]),

          ),
          SizedBox(height: 24.h),
          Text(
            'Ces scans nous permettent de récolter des données géographiques. '
            'Elles sont utilisées pour vous aider à trouver ces produits sur '
            'la carte interactive !',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyRegular15.copyWith(color: Colors.grey[600]),

          ),
          SizedBox(height: 48.h),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: "C'est parti !",
              backgroundColor: Theme.of(context).colorScheme.primary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ),
        ],
      ),
    );
  }
}
