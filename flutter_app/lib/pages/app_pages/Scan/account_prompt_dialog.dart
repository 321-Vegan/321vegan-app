import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/themes/app_shapes.dart';

class AccountPromptDialog extends StatelessWidget {
  final VoidCallback onCreateAccount;

  const AccountPromptDialog({super.key, required this.onCreateAccount});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: squircleBorder(radius: 28.r),
      child: Container(
        padding: EdgeInsets.all(32.w),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: squircleBorder(radius: 28.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 240.w,
              height: 240.w,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'lib/assets/avatars/chat.png',
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'Créez votre compte !',
              style: TextStyle(
                fontSize: 56.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            Text(
              'Accédez à toutes les fonctionnalités de l\'application en créant gratuitement votre compte !',
              style: TextStyle(
                fontSize: 42.sp,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await PreferencesHelper.markAccountPromptDismissed();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      side: BorderSide(color: Colors.grey[300]!, width: 2),
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      shape: squircleBorder(radius: 12.r),
                    ),
                    child: Text(
                      'Plus tard',
                      style: TextStyle(
                        fontSize: 44.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await PreferencesHelper.markAccountPromptDismissed();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        onCreateAccount();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      shape: squircleBorder(radius: 12.r),
                    ),
                    child: Text(
                      'Créer un compte',
                      style: TextStyle(
                        fontSize: 44.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
