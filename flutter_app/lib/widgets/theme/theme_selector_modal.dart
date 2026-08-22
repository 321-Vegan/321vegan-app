import 'dart:math' as math;
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/seasonal_theme.dart';
import '../../helpers/theme_helper.dart';
import '../../main.dart';
import '../../services/subscription_service.dart';
import '../../pages/app_pages/Profile/subscription_page.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/info_box.dart';
import '../shared/page_dots_indicator.dart';
import 'snow_globe_overlay.dart';

/// Central card illustration, keyed by season — reuses the leaf set from
/// the homepage "Forêt préservée" stat instead of the old mismatched
/// one-off illustrations (tulipe/ruche/pumpkin).
String _leafAssetForSeason(Season season) {
  final suffix = switch (season) {
    Season.spring => 'spring',
    Season.summer => 'summer',
    Season.autumn => 'autumn',
    Season.winter => 'winter',
    Season.defaultTheme => 'basic',
  };
  return 'lib/assets/themes/cards/leaf-$suffix.webp';
}

class ThemeSelectorModal extends StatefulWidget {
  const ThemeSelectorModal({super.key});

  @override
  State<ThemeSelectorModal> createState() => _ThemeSelectorModalState();
}

class _ThemeSelectorModalState extends State<ThemeSelectorModal>
    with TickerProviderStateMixin {
  bool _isAutoTheme = true;
  Season? _selectedSeason;
  bool _isLoading = true;
  late PageController _pageController;
  int _currentPage = 0;
  double _pageOffset = 0;
  late AnimationController _iconAnimController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.75);
    _pageController.addListener(_onPageScroll);
    _iconAnimController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _iconAnimController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    if (_pageController.page != null) {
      setState(() {
        _pageOffset = _pageController.page!;
      });
    }
  }

  Future<void> _loadCurrentSettings() async {
    final isAuto = await ThemeHelper.isAutoThemeEnabled();
    final savedSeason = await ThemeHelper.getSavedThemePreference();
    final allThemes = ThemeHelper.getAllThemes();

    final activeSeason = isAuto
        ? ThemeHelper.getCurrentSeason()
        : (savedSeason ?? Season.defaultTheme);

    final initialIndex = allThemes
        .indexWhere((t) => t.season == activeSeason)
        .clamp(0, allThemes.length - 1);

    setState(() {
      _isAutoTheme = isAuto;
      _selectedSeason = savedSeason ??
          (isAuto ? ThemeHelper.getCurrentSeason() : Season.defaultTheme);
      _currentPage = initialIndex;
      _pageOffset = initialIndex.toDouble();
      _isLoading = false;
    });

    // Recreate the PageController with the correct initial page
    // to avoid triggering onPageChanged (which disables auto theme)
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _pageController = PageController(
      viewportFraction: 0.75,
      initialPage: initialIndex,
    );
    _pageController.addListener(_onPageScroll);
  }

  Future<void> _saveThemeSettings() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await ThemeHelper.saveAutoThemePreference(_isAutoTheme);
    if (!_isAutoTheme && _selectedSeason != null) {
      await ThemeHelper.saveThemePreference(_selectedSeason);
    }

    if (!mounted) return;
    final myAppState = MyApp.of(context);
    if (myAppState != null) {
      await myAppState.updateTheme();
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    Navigator.of(context).pop(true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Thème mis à jour avec succès !',
          style: TextStyle(fontSize: 50.sp, fontFamily: 'Baloo'),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _applyThemeSilently() async {
    await ThemeHelper.saveAutoThemePreference(_isAutoTheme);
    if (!_isAutoTheme && _selectedSeason != null) {
      await ThemeHelper.saveThemePreference(_selectedSeason);
    }
    if (mounted) {
      final myAppState = MyApp.of(context);
      if (myAppState != null) {
        await myAppState.updateTheme();
      }
    }
  }

  void _openSubscriptionPage() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SubscriptionPage()),
    );
  }

  Color _lerpThemeColor(Color Function(SeasonalTheme) getter) {
    final allThemes = ThemeHelper.getAllThemes();
    final index = _pageOffset.floor().clamp(0, allThemes.length - 1);
    final nextIndex = (index + 1).clamp(0, allThemes.length - 1);
    final t = _pageOffset - index;
    return Color.lerp(
        getter(allThemes[index]), getter(allThemes[nextIndex]), t)!;
  }

  // Same gentle motion for every card: a slight breathing scale plus a
  // barely-there tilt so the icon feels alive without drawing attention.
  _IconAnimValues _getIconAnim(double t) {
    // t goes 0→1→0 (reverse repeat)
    final sinT = math.sin(t * math.pi);
    return _IconAnimValues(
      rotation: math.sin(t * math.pi * 2) * 0.03,
      scale: 1.0 + sinT * 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: squircleBorderOnly(topLeft: 28.r, topRight: 28.r),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final isSubscribed = SubscriptionService.isSubscribed;
    final currentSeason = ThemeHelper.getCurrentSeason();
    final allThemes = ThemeHelper.getAllThemes();
    final currentTheme = allThemes[_currentPage.clamp(0, allThemes.length - 1)];
    final isCurrentLocked = currentTheme.isPremium && !isSubscribed;

    return Container(
      decoration: ShapeDecoration(
        shape: squircleBorderOnly(topLeft: 28.r, topRight: 28.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
            ),
          ),

          Column(
            children: [
              _buildHeader(),

              if (isSubscribed)
                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 12.h),
                  child: _buildAutoThemeToggle(currentSeason),
                ),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey(_currentPage),
                  children: [
                    Text(
                      currentTheme.name,
                      style: AppTextStyles.baloo26,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              SizedBox(
                height: 680.h,
                child: PageView.builder(
                  controller: _pageController,
                  physics: null,
                  itemCount: allThemes.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                      if (_isAutoTheme) {
                        _isAutoTheme = false;
                      }
                      _selectedSeason = allThemes[index].season;
                    });
                  },
                  itemBuilder: (context, index) {
                    final theme = allThemes[index];
                    final isLocked = theme.isPremium && !isSubscribed;
                    final isCurrentSeason = theme.season == currentSeason;

                    return _buildThemeCard(
                      theme,
                      index: index,
                      isLocked: isLocked,
                      isCurrentSeason: isCurrentSeason,
                    );
                  },
                ),
              ),

              SizedBox(height: 16.h),

              _buildPageIndicator(allThemes),

              if (!isSubscribed) SizedBox(height: 30.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
                child: const InfoBox(
                  text:
                      'L\'abonnement soutien débloque tous les thèmes. Y souscrire permet au projet 321 Vegan de continuer d\'exister et de se développer. Merci !',
                ),
              ),
              SizedBox(height: 60.h),
              _buildBottomButton(currentTheme, isCurrentLocked),
              SizedBox(height: 60.h),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(top: 16.h),
          width: 60.w,
          height: 6.h,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(3.r),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(28.w, 20.h, 16.w, 16.h),
          child: Row(
            children: [
              Text(
                'Thèmes',
                style: AppTextStyles.baloo22,
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 44.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAutoThemeToggle(Season currentSeason) {
    final currentTheme = ThemeHelper.getThemeBySeason(currentSeason);

    return GestureDetector(
      onTap: () async {
        if (!_isAutoTheme) {
          // Animate to the current-season page first, then lock auto mode on.
          final allThemes = ThemeHelper.getAllThemes();
          final seasonIndex = allThemes
              .indexWhere((t) => t.season == ThemeHelper.getCurrentSeason())
              .clamp(0, allThemes.length - 1);
          await _pageController.animateToPage(
            seasonIndex,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
          if (mounted) {
            setState(() => _isAutoTheme = true);
            _applyThemeSilently();
          }
        } else {
          setState(() => _isAutoTheme = false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: ShapeDecoration(
          color: _isAutoTheme ? currentTheme.primaryColor : Colors.grey[200],
          shape: squircleBorder(radius: 50.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64.sp,
              color: _isAutoTheme ? Colors.white : kTextPrimary,
            ),
            SizedBox(width: 10.w),
            Text(
              _isAutoTheme
                  ? 'Mode automatique · ${ThemeHelper.getThemeBySeason(currentSeason).name}'
                  : 'Activer le mode automatique',
              style: AppTextStyles.bodyBold15.copyWith(
                color: _isAutoTheme ? Colors.white : kTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard(
    SeasonalTheme theme, {
    required int index,
    required bool isLocked,
    required bool isCurrentSeason,
  }) {
    final distance = _pageOffset - index;
    final absDistance = distance.abs().clamp(0.0, 1.0);
    final scale = 1.0 - (absDistance * 0.08);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: scale, end: scale),
      duration: const Duration(milliseconds: 50),
      builder: (context, scaleVal, child) {
        return Transform.scale(
          scale: scaleVal,
          child: child,
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        child: GestureDetector(
          onTap: isLocked ? _openSubscriptionPage : null,
          child: Container(
            decoration: ShapeDecoration(
              // Same gradient as the app's own background (see
              // AppBackground) so the card previews the real look;
              // theme.iconBackgroundColor isn't distinct enough per season.
              gradient: theme.backgroundGradient ??
                  LinearGradient(
                    colors: [theme.waveColor, theme.primaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
              shape: squircleBorder(
                radius: 28.r,
                side: BorderSide(
                  color: index == _currentPage
                      ? theme.primaryColor
                      : kBorderDefault,
                  width: index == _currentPage ? 2 : 1,
                ),
              ),
            ),
            child: ClipSmoothRect(
              radius: squircleRadius(28.r),
              child: _buildCardSnowGlobe(
                theme: theme,
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (_isAutoTheme && isCurrentSeason)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12.w, vertical: 6.h),
                                  decoration: ShapeDecoration(
                                    color: theme.primaryColor
                                        .withValues(alpha: 0.15),
                                    shape: squircleBorder(radius: 16.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome,
                                          size: 28.sp,
                                          color: theme.primaryColor),
                                      SizedBox(width: 4.w),
                                      Text(
                                        'Saison actuelle',
                                        style: AppTextStyles.bodyBold11
                                            .copyWith(
                                                color: theme.primaryColor),
                                      ),
                                    ],
                                  ),
                                ),
                              const Spacer(),
                              if (isLocked)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12.w, vertical: 6.h),
                                  decoration: ShapeDecoration(
                                    color: kAccentYellow,
                                    shape: squircleBorder(radius: 16.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_outline,
                                          size: 28.sp, color: Colors.white),
                                      SizedBox(width: 4.w),
                                      Text(
                                        'Premium',
                                        style: AppTextStyles.bodyBold11
                                            .copyWith(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),

                          const Spacer(),

                          Center(
                            child: AnimatedBuilder(
                              animation: _iconAnimController,
                              builder: (context, child) {
                                final anim =
                                    _getIconAnim(_iconAnimController.value);
                                return Transform.scale(
                                  scale: anim.scale,
                                  child: Transform.rotate(
                                    angle: anim.rotation,
                                    child: Image.asset(
                                      _leafAssetForSeason(theme.season),
                                      width: 280.sp,
                                      height: 280.sp,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const Spacer(),

                          Text(
                            theme.name,
                            style: AppTextStyles.baloo22,
                          ),
                        ],
                      ),
                    ),

                    if (isLocked)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(20.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.lock_outline,
                                    size: 100.sp,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 18.w, vertical: 8.h),
                                  decoration: ShapeDecoration(
                                    color: kAccentYellow,
                                    shape: squircleBorder(radius: 16.r),
                                  ),
                                  child: Text(
                                    'Débloqué avec l\'abonnement soutien',
                                    style: AppTextStyles.bodyBold11
                                        .copyWith(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardSnowGlobe({
    required SeasonalTheme theme,
    required Widget child,
  }) {
    if ((theme.snowGlobeParticleAssets?.isEmpty ?? true) &&
        theme.snowGlobeParticleIcon == null &&
        theme.particleType != ParticleType.snowflakes) {
      return child;
    }
    final br = squircleRadius(28.r);
    return SnowGlobeOverlay(
      particleAssets: theme.snowGlobeParticleAssets,
      particleIcon: theme.snowGlobeParticleIcon,
      particleCount: theme.particleType == ParticleType.snowflakes ? 15 : 10,
      particleOpacity: theme.particleOpacity,
      particleMinRadius: theme.particleMinRadius,
      particleMaxRadius: theme.particleMaxRadius,
      // Only affects icon/plain-circle particles — white read fine on the
      // old saturated card but disappears on the new pale fill.
      particleColor: theme.primaryColor,
      borderRadius: br,
      child: child,
    );
  }

  Widget _buildPageIndicator(List<SeasonalTheme> themes) {
    // Active dot picks up the swiped-to theme's own color rather than the
    // app's flat colorScheme.primary — each page here is a different theme.
    return PageDotsIndicator(
      count: themes.length,
      currentIndex: _currentPage,
      activeColor: _lerpThemeColor((t) => t.primaryColor),
    );
  }

  Widget _buildBottomButton(SeasonalTheme currentTheme, bool isLocked) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 4.h, 24.w, 8.h),
      child: SizedBox(
        width: double.infinity,
        child: AppButton(
          label: isLocked ? 'Débloquer' : 'Appliquer',
          icon: isLocked ? Icons.lock_open : Icons.check_circle_outline,
          backgroundColor: isLocked ? kAccentYellow : currentTheme.primaryColor,
          onPressed: isLocked ? _openSubscriptionPage : _saveThemeSettings,
        ),
      ),
    );
  }
}

class _IconAnimValues {
  final double rotation;
  final double scale;

  const _IconAnimValues({required this.rotation, required this.scale});
}
