import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/seasonal_theme.dart';
import '../../helpers/theme_helper.dart';
import '../../main.dart';
import '../../services/subscription_service.dart';
import '../../pages/app_pages/Profile/subscription_page.dart';
import 'snow_globe_overlay.dart';

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
          backgroundColor: Colors.green,
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

  // Per-season icon animation values
  _IconAnimValues _getIconAnim(Season season, double t) {
    // t goes 0→1→0 (reverse repeat)
    final sinT = math.sin(t * math.pi);
    switch (season) {
      case Season.defaultTheme:
        // Gentle pulse
        return _IconAnimValues(
          rotation: 0,
          scale: 1.0 + sinT * 0.06,
        );
      case Season.spring:
        return _IconAnimValues(
          rotation: math.sin(t * math.pi * 2) * 0.12,
          scale: 1.0 + sinT * 0.1,
        );
      case Season.summer:
        return _IconAnimValues(
          rotation: math.sin(t * math.pi * 1.5) * 0.25,
          scale: 1.0 + math.sin(t * math.pi * 0.7) * 0.04,
        );
      case Season.autumn:
        return _IconAnimValues(
          rotation: math.sin(t * math.pi * 1.5) * 0.25,
          scale: 1.0 + math.sin(t * math.pi * 0.7) * 0.04,
        );
      case Season.winter:
        return _IconAnimValues(
          rotation: t * math.pi,
          scale: 1.0 + sinT * 0.08,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background gradient
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

              // Theme name + description above carousel
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey(_currentPage),
                  children: [
                    Text(
                      currentTheme.name,
                      style: TextStyle(
                        fontSize: 64.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // Carousel
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

              // Page indicator
              _buildPageIndicator(allThemes),

              // Info text for non-subscribers
              if (!isSubscribed)
                Padding(
                  padding: EdgeInsets.all(8.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline,
                          size: 64.sp, color: Colors.grey[400]),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          'L\'abonnement soutien débloque tous les thèmes. Y souscrire permet au projet 321 Vegan de continuer d\'exister et de se développer. Merci !',
                          style: TextStyle(
                            fontSize: 45.sp,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Bottom button
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
                style: TextStyle(
                  fontSize: 60.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
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
          // Turning auto ON: animate first, then lock
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
          // Turning auto OFF
          setState(() => _isAutoTheme = false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: _isAutoTheme ? currentTheme.primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(50.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64.sp,
              color: _isAutoTheme ? Colors.white : Colors.grey[500],
            ),
            SizedBox(width: 10.w),
            Text(
              _isAutoTheme
                  ? 'Mode automatique · ${ThemeHelper.getThemeBySeason(currentSeason).name}'
                  : 'Activer le mode automatique',
              style: TextStyle(
                fontSize: 46.sp,
                fontWeight: FontWeight.w600,
                color: _isAutoTheme ? Colors.white : Colors.grey[600],
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
    // Scale down non-centered cards
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28.r),
              gradient: LinearGradient(
                colors: [theme.waveColor, theme.primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28.r),
              child: _buildCardSnowGlobe(
                theme: theme,
                child: Stack(
                  children: [
                    // Content overlay
                    Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top badges
                          Row(
                            children: [
                              if (_isAutoTheme && isCurrentSeason)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10.w, vertical: 5.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome,
                                          size: 28.sp, color: Colors.white),
                                      SizedBox(width: 4.w),
                                      Text(
                                        'Saison actuelle',
                                        style: TextStyle(
                                          fontSize: 28.sp,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const Spacer(),
                              if (isLocked)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10.w, vertical: 5.h),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock,
                                          size: 28.sp, color: Colors.white),
                                      SizedBox(width: 4.w),
                                      Text(
                                        'Premium',
                                        style: TextStyle(
                                          fontSize: 28.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),

                          const Spacer(),

                          // Central animated icon
                          Center(
                            child: AnimatedBuilder(
                              animation: _iconAnimController,
                              builder: (context, child) {
                                final anim = _getIconAnim(
                                    theme.season, _iconAnimController.value);
                                return Transform.scale(
                                  scale: anim.scale,
                                  child: Transform.rotate(
                                    angle: anim.rotation,
                                    child: Container(
                                      padding: EdgeInsets.all(24.w),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.18),
                                        shape: BoxShape.circle,
                                      ),
                                      child: theme.seasonalAsset != null
                                          ? Image.asset(
                                              theme.seasonalAsset!,
                                              width: 150.sp,
                                              height: 150.sp,
                                            )
                                          : Icon(
                                              theme.seasonalIcon,
                                              size: 130.sp,
                                              color: Colors.white,
                                            ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const Spacer(),

                          // Bottom: theme name
                          Text(
                            theme.name,
                            style: TextStyle(
                              fontSize: 60.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 4.h),
                          // Color dots
                          Row(
                            children: [
                              _buildCardColorDot(theme.primaryColor),
                              SizedBox(width: 8.w),
                              _buildCardColorDot(theme.secondaryColor),
                              SizedBox(width: 8.w),
                              _buildCardColorDot(theme.accentColor),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Lock overlay
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
                                  decoration: BoxDecoration(
                                    color: Colors.amber[700],
                                    borderRadius: BorderRadius.circular(14.r),
                                  ),
                                  child: Text(
                                    'Débloqué avec l\'abonnement soutien',
                                    style: TextStyle(
                                      fontSize: 34.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
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
    if (theme.snowGlobeParticleAsset == null &&
        theme.snowGlobeParticleIcon == null &&
        theme.particleType != ParticleType.snowflakes) {
      return child;
    }
    final br = BorderRadius.circular(28.r);
    return SnowGlobeOverlay(
      particleAsset: theme.snowGlobeParticleAsset,
      particleIcon: theme.snowGlobeParticleIcon,
      particleCount: theme.particleType == ParticleType.snowflakes ? 15 : 10,
      borderRadius: br,
      child: child,
    );
  }

  Widget _buildCardColorDot(Color color) {
    return Container(
      width: 22.w,
      height: 22.w,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }

  Widget _buildPageIndicator(List<SeasonalTheme> themes) {
    final activeColor = _lerpThemeColor((t) => t.primaryColor);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(themes.length, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          width: isActive ? 32.w : 10.w,
          height: 10.w,
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.grey[300],
            borderRadius: BorderRadius.circular(5.r),
          ),
        );
      }),
    );
  }

  Widget _buildBottomButton(SeasonalTheme currentTheme, bool isLocked) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 4.h, 24.w, 8.h),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isLocked ? _openSubscriptionPage : _saveThemeSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isLocked ? Colors.amber[700] : currentTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 20.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18.r),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isLocked ? Icons.lock_open : Icons.check_circle_outline,
                size: 46.sp,
              ),
              SizedBox(width: 10.w),
              Text(
                isLocked ? 'Débloquer' : 'Appliquer',
                style: TextStyle(
                  fontSize: 48.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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
