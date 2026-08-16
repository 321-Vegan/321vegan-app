import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../widgets/shared/app_button.dart';
import 'account_setup_page.dart';

/// First-launch welcome screen: a single custom page (no carousel package —
/// with just one screen, `introduction_screen`'s multi-page machinery would
/// be dead weight) followed by the skippable [AccountSetupPage].
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kOnboardingGradientTop, kOnboardingGradientBottom],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: 700.h,
              right: 0.w,
              child: Image.asset('lib/assets/intro/blob1.webp', width: 400.w),
            ),
            Positioned(
              top: 0,
              left: 600.w,
              child: Center(
                child: Image.asset('lib/assets/intro/blob2.webp', width: 300.w),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 48.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 1400.h,
                      child: Stack(
                        children: [
                          Positioned(
                            top: 400.h,
                            left: 70.w,
                            child: Image.asset(
                              'lib/assets/images/stat-cards/co2.webp',
                              height: 300.h,
                            ),
                          ),
                          Positioned(
                            top: 300.h,
                            right: 200.w,
                            child: Image.asset(
                              'lib/assets/themes/cards/leaf-winter.webp',
                              height: 260.h,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Image.asset(
                                'lib/assets/images/characters/lemon-vgn.webp',
                                height: 600.h,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: AppTextStyles.baloo26.copyWith(color: Colors.white),
                        children: const [
                          TextSpan(text: 'Rejoignez une '),
                          TextSpan(
                            text: 'communauté',
                            style: TextStyle(color: kAccentYellow),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      "Simplifiez vous la vie en scannant les produits et "
                      "en cherchant les additifs et marques de cosmétiques ; "
                      "et bien plus encore !",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyRegular15.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 56.h),
                    AppButton(
                      label: 'C\'est parti !',
                      backgroundColor: Colors.white,
                      foregroundColor: kOnboardingGradientBottom,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AccountSetupPage(),
                        ),
                      ),
                    ),
                    SizedBox(height: 200.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
