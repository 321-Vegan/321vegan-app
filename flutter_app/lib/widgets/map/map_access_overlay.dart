import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/widgets/auth/auth_bottom_sheet.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';

/// Blurred lock shown over the map for logged-out users: the shop endpoints
/// require an account.
class MapAccessOverlay extends StatelessWidget {
  final VoidCallback onLoginSuccess;

  const MapAccessOverlay({super.key, required this.onLoginSuccess});

  void _showAuthSheet(BuildContext context, {required bool showRegister}) {
    showAuthBottomSheet(
      context,
      initialShowRegister: showRegister,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      onSuccess: onLoginSuccess,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: Colors.white.withValues(alpha: 0.6),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'lib/assets/images/characters/cow-mby.webp',
                        width: 220.w,
                        height: 220.w,
                      ),
                      SizedBox(height: 24.h),
                      Text(
                        'Trouvez les produits et lieux véganes près de vous',
                        style: TextStyle(
                          fontSize: 52.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'Créez un compte gratuit pour accéder à la carte. C\'est gratuit !',
                        style: TextStyle(
                          fontSize: 40.sp,
                          color: Colors.grey[500],
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 32.h),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: 'Créer un compte',
                          backgroundColor: primaryColor,
                          onPressed: () =>
                              _showAuthSheet(context, showRegister: true),
                        ),
                      ),
                      SizedBox(height: 32.h),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: 'Se connecter',
                          backgroundColor: kAccentYellow,
                          onPressed: () =>
                              _showAuthSheet(context, showRegister: false),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
