import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../../widgets/shared/app_background.dart';
import '../../widgets/shared/page_dots_indicator.dart';
import 'account_setup_page.dart';

class _IntroSlide {
  final String imagePath;
  final String headline;
  final String accentHeadline;
  final String subtitle;

  const _IntroSlide({
    required this.imagePath,
    required this.headline,
    required this.accentHeadline,
    required this.subtitle,
  });
}

const List<_IntroSlide> _slides = [
  _IntroSlide(
    imagePath: 'lib/assets/intro/p1-phone.webp',
    headline: 'Faites vos courses en toute ',
    accentHeadline: 'confiance',
    subtitle: "Découvrez instantanément si un produit est végane, son "
        "Nutri-Score, son Green Score et l'impact de sa marque.",
  ),
  _IntroSlide(
    imagePath: 'lib/assets/intro/p2-phone.webp',
    headline: 'Trouvez vos produits véganes ',
    accentHeadline: 'partout',
    subtitle: "Recherchez un produit et découvrez dans quels magasins vous "
        "pouvez le trouver près de chez vous, où que vous soyez en France.",
  ),
  _IntroSlide(
    imagePath: 'lib/assets/intro/p3-phone.webp',
    headline: 'Voyez concrètement ',
    accentHeadline: "l'impact de vos choix",
    subtitle: "Découvrez ce que votre alimentation permet d'épargner aux "
        "animaux, à la planète et aux ressources.",
  ),
];

/// Total page count: the 3 intro slides plus the [AccountSetupPage] login/
/// register step, all swiped through in the same [PageView] so the account
/// step reads as this carousel's 4th step rather than a separate screen.
final int _pageCount = _slides.length + 1;

/// First-launch welcome screens: a 4-page swipeable carousel — 3 slides
/// pitching the app's core features, each full-bleed screenshot padded to
/// blend into [AppBackground] — followed by the skippable [AccountSetupPage].
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: _pageCount,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) => index < _slides.length
                  ? _IntroPage(slide: _slides[index])
                  : const AccountSetupPage(),
            ),
            if (_page < _slides.length)
              Positioned(
                left: 0,
                right: 0,
                bottom: 64.h,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageHorizontal,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        PageDotsIndicator(
                          count: _pageCount,
                          currentIndex: _page,
                          activeColor: kSemanticSuccess,
                        ),
                        _NextButton(onTap: _next),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  final _IntroSlide slide;

  const _IntroPage({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            slide.imagePath,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 24.h),
                Center(
                  child: Image.asset('lib/assets/app_icon.png', width: 160.w),
                ),
                const Spacer(),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppTextStyles.baloo36,
                    children: [
                      TextSpan(text: slide.headline),
                      TextSpan(
                        text: slide.accentHeadline,
                        style: const TextStyle(color: kAccentYellow),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  slide.subtitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyRegular15.copyWith(
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 360.h),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NextButton extends StatelessWidget {
  final VoidCallback onTap;

  const _NextButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120.w,
        height: 120.w,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: kSemanticSuccess,
          shape: squircleBorder(radius: 32.r),
        ),
        child: Icon(Icons.arrow_forward, color: Colors.white, size: 65.sp),
      ),
    );
  }
}
