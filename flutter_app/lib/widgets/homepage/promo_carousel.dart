import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/seasonal_theme.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';

/// One slide of the Dashboard news carousel.
class PromoSlide {
  final String title;
  final String subtitle;

  /// Opened by the "Voir plus" button; hides the button when null.
  final String? url;

  /// Asset path of the slide illustration; falls back to a generic
  /// icon-in-circle placeholder when null.
  final String? image;

  const PromoSlide({
    required this.title,
    required this.subtitle,
    this.url,
    this.image,
  });
}

/// Dummy static content until the real news source is wired
/// (edit freely — titles/subtitles/links/images only live here).
const List<PromoSlide> _dummySlides = [
  PromoSlide(
    title: 'L\'appli fait peau neuve !',
    subtitle: 'Un tout nouveau design pour plus de clarté !',
    image: 'lib/assets/images/buy-premium/tree.webp',
  ),
  PromoSlide(
    title: 'Nouveau !',
    subtitle: 'Collectionnez les produits du Vegandex',
    image: 'lib/assets/images/buy-premium/bee.webp',
  ),
  PromoSlide(
    title: 'Rappel B12',
    subtitle: 'Activez vos rappels dans les paramètres',
    image: 'lib/assets/images/buy-premium/tree.webp',
  ),
  PromoSlide(
    title: 'Merci !',
    subtitle: 'Vous êtes de plus en plus nombreux·ses',
    image: 'lib/assets/images/buy-premium/bee.webp',
  ),
];

/// Swipeable news carousel at the top of the Dashboard (static content).
class PromoCarousel extends StatefulWidget {
  final List<PromoSlide> slides;

  const PromoCarousel({super.key, this.slides = _dummySlides});

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 396.h,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.slides.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) =>
                _PromoCard(slide: widget.slides[index]),
          ),
        ),
        SizedBox(height: 20.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.slides.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: 8.w),
              width: index == _page ? 66.w : 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                color: index == _page
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[400],
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PromoCard extends StatelessWidget {
  final PromoSlide slide;

  const _PromoCard({required this.slide});

  Future<void> _open(BuildContext context) async {
    final url = slide.url;
    if (url == null) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir le lien'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isWinter =
        Theme.of(context).extension<SeasonalTheme>()?.season == Season.winter;
    final card = Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.symmetric(horizontal: 45.w, vertical: 60.h),
      decoration: ShapeDecoration(
        color: primary,
        shape: squircleBorder(radius: 80.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slide.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 68.sp,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Baloo',
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  slide.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 40.sp,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                if (slide.url != null) ...[
                  SizedBox(height: 20.h),
                  ElevatedButton(
                    onPressed: () => _open(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentYellow,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                          horizontal: 36.w, vertical: 14.h),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: squircleBorder(radius: 30.r),
                    ),
                    child: Text(
                      'Voir plus',
                      style: TextStyle(
                          fontSize: 40.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 30.w),
          if (slide.image != null)
            Image.asset(
              slide.image!,
              width: 240.w,
              height: 240.w,
              fit: BoxFit.contain,
            )
          else
            Container(
              width: 200.w,
              height: 200.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.eco, color: Colors.white, size: 100.sp),
            ),
        ],
      ),
    );

    if (!isWinter) return card;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          top: -20.h,
          right: 18.w,
          child: IgnorePointer(
            child: ClipPath(
              clipper: ShapeBorderClipper(
                shape: squircleBorderOnly(topRight: 80.r),
              ),
              child: Image.asset(
                'lib/assets/themes/ice_2.webp',
                width: 900.w,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topRight,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
