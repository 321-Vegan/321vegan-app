import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vegan_app/widgets/b12/b12_reminder_settings_modal.dart';
import '../../models/seasonal_theme.dart';
import '../../pages/app_pages/Partners/partners_page.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../shared/page_dots_indicator.dart';

/// One slide of the Dashboard news carousel.
class PromoSlide {
  final String title;
  final String subtitle;

  /// Opened by the "Voir plus" button; hides the button when null and
  /// [page] is also null. Ignored when [page] is set.
  final String? url;

  /// Builds the page pushed by the "Voir plus" button for in-app
  /// navigation — takes precedence over [url]. Hides the button when null
  /// and [url] is also null.
  final Widget Function()? page;

  /// When true, [page] is presented with `showModalBottomSheet` instead of
  /// being pushed as a full route — set this for widgets designed as
  /// bottom sheets (e.g. [B12ReminderSettingsModal]).
  final bool pageIsBottomSheet;

  /// Label of the "Voir plus" button; ignored when the button is hidden
  /// (both [url] and [page] are null).
  final String buttonLabel;

  /// Asset path of the slide illustration; falls back to a generic
  /// icon-in-circle placeholder when null.
  final String? image;

  const PromoSlide({
    required this.title,
    required this.subtitle,
    this.url,
    this.page,
    this.pageIsBottomSheet = false,
    this.buttonLabel = 'Voir plus',
    this.image,
  });
}

/// Static content until the real news source is wired
final List<PromoSlide> _promoSlides = [
  const PromoSlide(
    title: 'Nouvelle interface !',
    subtitle: 'Un tout nouveau design pour plus de clarté.',
    image: 'lib/assets/images/characters/lemon-vgn.webp',
  ),
  PromoSlide(
    title: 'Boutiques partenaire',
    subtitle:
        'Profitez de nouvelles réductions !',
    image: 'lib/assets/images/buy-premium/bee.webp',
    page: () => const PartnersPage(),
    buttonLabel: "Je veux voir !"
  ),
  PromoSlide(
    title: 'Rappel B12',
    subtitle: 'Configurez un rappel pour votre B12.',
    page: () => const B12ReminderSettingsModal(),
    pageIsBottomSheet: true,
    image: 'lib/assets/images/characters/lemon-mby.webp',
    buttonLabel: "Configurer maintenant"
  ),
  const PromoSlide(
    title: 'Merci !',
    subtitle: 'L\'appli grandit et vous êtes de plus en plus nombreux·ses.',
    image: 'lib/assets/images/buy-premium/bee.webp',
  ),
];

/// Swipeable news carousel at the top of the Dashboard (static content).
class PromoCarousel extends StatefulWidget {
  /// Defaults to [_promoSlides] when null.
  final List<PromoSlide>? slides;

  const PromoCarousel({super.key, this.slides});

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  static const _autoScrollInterval = Duration(seconds: 5);

  final PageController _controller = PageController();
  Timer? _autoScrollTimer;
  int _page = 0;
  bool _isWrappingToStart = false;

  List<PromoSlide> get _slides => widget.slides ?? _promoSlides;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (_slides.length <= 1) return;
    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      // This widget can be disposed between ticks — animateToPage would
      // otherwise hit the controller with no attached PageView and throw.
      if (!mounted || !_controller.hasClients) return;
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
    if (_slides.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 396.h,
          child: _buildPageView(),
        ),
        SizedBox(height: 20.h),
        PageDotsIndicator(
          count: _slides.length,
          currentIndex: _page,
          activeColor: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildPageView() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final isLastPage = _page == _slides.length - 1;
        if (!isLastPage || _isWrappingToStart) return false;

        // OverscrollNotification.overscroll only fires under
        // ClampingScrollPhysics (Android): the drag is blocked at the
        // boundary and reports how far it was blocked. Under iOS's
        // BouncingScrollPhysics, applyBoundaryConditions always
        // returns 0, so no OverscrollNotification is ever dispatched;
        // instead pixels legitimately exceeds maxScrollExtent while
        // rubber-banding, which we detect via the metrics diff.
        final metrics = notification.metrics;
        final overscroll = notification is OverscrollNotification
            ? notification.overscroll
            : metrics.pixels - metrics.maxScrollExtent;

        if (overscroll > 8) {
          _isWrappingToStart = true;
          _controller
              .animateToPage(
                0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              )
              .then((_) => _isWrappingToStart = false);
        }
        return false;
      },
      child: PageView.builder(
        controller: _controller,
        itemCount: _slides.length,
        onPageChanged: (page) {
          setState(() => _page = page);
          _startAutoScroll();
        },
        itemBuilder: (context, index) => _PromoCard(slide: _slides[index]),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final PromoSlide slide;

  const _PromoCard({required this.slide});

  Future<void> _handleButtonTap(BuildContext context) async {
    final page = slide.page;
    if (page != null) {
      if (slide.pageIsBottomSheet) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => page(),
        );
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => page()));
      }
      return;
    }
    final url = slide.url;
    if (url == null) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir le lien'),
          backgroundColor: kSemanticError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final season = Theme.of(context).extension<SeasonalTheme>()?.season;
    final isWinter = season == Season.winter;
    final isAutumn = season == Season.autumn;
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
                if (slide.url != null || slide.page != null) ...[
                  SizedBox(height: 20.h),
                  ElevatedButton(
                    onPressed: () => _handleButtonTap(context),
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
                      slide.buttonLabel,
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

    if (isWinter) {
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

    return card;
  }
}
