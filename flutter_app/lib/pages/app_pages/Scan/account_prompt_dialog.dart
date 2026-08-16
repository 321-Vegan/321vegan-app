import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';
import 'package:vegan_app/widgets/shared/bottom_sheet_shell.dart';

/// Nudge shown every 5th scan for a logged-out user, prompting them to
/// create an account — not permanently dismissible, so it keeps resurfacing
/// every 5th scan even after "Plus tard". [BottomSheetShell] styling to
/// match the rest of the app's modals (e.g. [VegandexWelcomeModal]) instead
/// of a centered dialog.
class AccountPromptDialog extends StatelessWidget {
  final VoidCallback onCreateAccount;

  const AccountPromptDialog({super.key, required this.onCreateAccount});

  @override
  Widget build(BuildContext context) {
    return BottomSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'lib/assets/images/characters/lemon-vgn.webp',
            height: 260.h,
          ),
          SizedBox(height: 24.h),
          Text(
            'Créez votre compte !',
            style: AppTextStyles.baloo26,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          Text(
            "Accédez à toutes les fonctionnalités de l'application en "
            "créant gratuitement votre compte !",
            style: AppTextStyles.bodyRegular15.copyWith(
              color: Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32.h),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Plus tard',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.grey[700]!,
                  borderColor: kBorderDefault,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: AppButton(
                  label: 'Créer un compte',
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  onPressed: () {
                    Navigator.of(context).pop();
                    onCreateAccount();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
