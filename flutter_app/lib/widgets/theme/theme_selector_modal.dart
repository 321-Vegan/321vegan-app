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

/// Card illustration, keyed by season — the "poule" mascot dressed for
/// each season.
String _pouleAssetForSeason(Season season) {
  final suffix = switch (season) {
    Season.spring => 'spring',
    Season.summer => 'summer',
    Season.autumn => 'autumn',
    Season.winter => 'winter',
    Season.defaultTheme => 'basic',
  };
  return 'lib/assets/themes/cards/poule-$suffix.webp';
}

class ThemeSelectorModal extends StatefulWidget {
  const ThemeSelectorModal({super.key});

  @override
  State<ThemeSelectorModal> createState() => _ThemeSelectorModalState();
}

class _ThemeSelectorModalState extends State<ThemeSelectorModal> {
  bool _isAutoTheme = true;
  Season? _selectedSeason;
  bool _isLoading = true;
  late PageController _pageController;
  int _currentPage = 0;
  double _pageOffset = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.72);
    _pageController.addListener(_onPageScroll);
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
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
      viewportFraction: 0.72,
      initialPage: initialIndex,
    );
    _pageController.addListener(_onPageScroll);
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

              SizedBox(height: 32.h),

              if (isSubscribed)
                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 0),
                  child: _buildAutoThemeToggle(currentSeason),
                ),

              SizedBox(height: 16.h),

              SizedBox(
                height: 620.h,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: allThemes.length,
                  onPageChanged: (index) {
                    final theme = allThemes[index];
                    final isLocked = theme.isPremium && !isSubscribed;
                    setState(() {
                      _currentPage = index;
                      if (_isAutoTheme) {
                        _isAutoTheme = false;
                      }
                      _selectedSeason = theme.season;
                    });
                    if (!isLocked) {
                      _applyThemeSilently();
                    }
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

              SizedBox(height: 20.h),

              _buildPageIndicator(allThemes),

              SizedBox(height: 24.h),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: const InfoBox(
                  text:
                      'L\'abonnement débloque tous les thèmes. En y souscrivant, vous permettez au projet 321 Vegan de continuer d\'exister et de se développer. Merci !',
                ),
              ),

              if (!isSubscribed) ...[
                SizedBox(height: 20.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Débloquer tous les thèmes',
                      iconAsset: 'lib/assets/images/icons/crown-line.webp',
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      onPressed: _openSubscriptionPage,
                    ),
                  ),
                ),
              ],

              SizedBox(height: 32.h),
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
    final isSelected = index == _currentPage;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      child: GestureDetector(
        onTap: isLocked ? _openSubscriptionPage : null,
        child: Container(
          decoration: ShapeDecoration(
            color: isSelected
                ? theme.primaryColor.withValues(alpha: 0.12)
                : Colors.white,
            shape: squircleBorder(
              radius: 32.r,
              side: BorderSide(
                color: isSelected ? theme.primaryColor : kBorderDefault,
                width: isSelected ? 2 : 1,
              ),
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      _pouleAssetForSeason(theme.season),
                      width: 320.sp,
                      height: 320.sp,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      theme.name,
                      style: AppTextStyles.baloo26.copyWith(
                        color: isSelected ? theme.primaryColor : kTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLocked)
                Positioned(
                  right: 64.w,
                  top: 64.h,
                  child: Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: const BoxDecoration(
                      color: kAccentYellow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 64.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
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
}
