import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../themes/app_colors.dart';

/// One slide of the Dashboard news carousel.
class PromoSlide {
  final String title;
  final String subtitle;

  /// Opened by the "Voir plus" button; hides the button when null.
  final String? url;

  const PromoSlide({
    required this.title,
    required this.subtitle,
    this.url,
  });
}

/// Dummy static content until the real news source is wired
/// (edit freely — titles/subtitles/links only live here).
const List<PromoSlide> _dummySlides = [
  PromoSlide(
    title: '-10% !',
    subtitle: 'Sur la boutique Comme Avant',
    url: 'https://321vegan.fr',
  ),
  PromoSlide(
    title: 'Nouveau !',
    subtitle: 'Collectionnez les produits du Vegandex',
  ),
  PromoSlide(
    title: 'Rappel B12',
    subtitle: 'Activez vos rappels dans les paramètres',
  ),
  PromoSlide(
    title: 'Merci !',
    subtitle: 'Vous êtes de plus en plus nombreux·ses',
  ),
];

/// Swipeable news carousel at the top of the Dashboard (static content).
/// The illustration area is a placeholder until the Figma assets land —
/// swap the `Icon` in [_PromoCard] for an `Image.asset` at that point.
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
        // Figma spec: fill width, hug height (~132), radius 20,
        // padding 20 (v) / 15 (h) — all ×3 for ScreenUtil units.
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
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.symmetric(horizontal: 45.w, vertical: 60.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withAlpha(190)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(60.r),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.r),
                      ),
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
  }
}
