import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../shared/page_dots_indicator.dart';

class _HeroSlide {
  final String headlinePrefix;
  final String headlineHighlight;
  final String subtitle;

  const _HeroSlide({
    required this.headlinePrefix,
    required this.headlineHighlight,
    required this.subtitle,
  });
}

const _slides = [
  _HeroSlide(
    headlinePrefix: 'Faites vos courses en toute ',
    headlineHighlight: 'confiance',
    subtitle:
        "Découvrez instantanément si un produit est végane, son Nutri-Score, "
        "son Green Score et l'impact de sa marque.",
  ),
  _HeroSlide(
    headlinePrefix: 'Configurer un rappel pour ',
    headlineHighlight: 'votre B12',
    subtitle:
        'N\'oubliez plus jamais aucune prise, qu\'elle soit '
        'quotidienne, par semaine ou toutes les deux semaines.',
  ),
  _HeroSlide(
    headlinePrefix: 'Progressez avec la ',
    headlineHighlight: 'communauté',
    subtitle:
        'Suivez votre vegandex, débloquez des badges et trouver les '
        'produits véganes près de chez vous.',
  ),
];

/// Auto-scrolling pitch carousel shown above the login/register form —
/// same auto-scroll pattern as [PromoCarousel] (Dashboard) but text-only,
/// no illustration per slide.
class AuthHeroCarousel extends StatefulWidget {
  const AuthHeroCarousel({super.key});

  @override
  State<AuthHeroCarousel> createState() => _AuthHeroCarouselState();
}

class _AuthHeroCarouselState extends State<AuthHeroCarousel> {
  static const _autoScrollInterval = Duration(seconds: 4);

  final PageController _controller = PageController();
  Timer? _autoScrollTimer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      final nextPage = (_page + 1) % _slides.length;
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 400.h,
          child: PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) => _HeroSlideView(slide: _slides[index]),
          ),
        ),
        SizedBox(height: 24.h),
        PageDotsIndicator(
          count: _slides.length,
          currentIndex: _page,
          activeColor: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}

class _HeroSlideView extends StatelessWidget {
  final _HeroSlide slide;

  const _HeroSlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: SingleChildScrollView(
        // Defensive: keeps larger accessibility text sizes scrolling
        // within the slide instead of overflowing it.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: AppTextStyles.baloo26,
                children: [
                  TextSpan(text: slide.headlinePrefix),
                  TextSpan(
                    text: slide.headlineHighlight,
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
          ],
        ),
      ),
    );
  }
}