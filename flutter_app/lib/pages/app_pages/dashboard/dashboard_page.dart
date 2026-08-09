import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../helpers/preference_helper.dart';
import '../../../helpers/vegan_savings.dart';
import '../../../models/error_report.dart';
import '../../../models/partners/partners.dart';
import '../../../models/user.dart';
import '../../../services/anniversary_service.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/b12_reminder_service.dart';
import '../../../services/badge_service.dart';
import '../../../services/error_report_badge_service.dart';
import '../../../services/products_of_interest_cache.dart';
import '../../../services/profile_notification_service.dart';
import '../../../services/subscription_service.dart';
import '../../../themes/app_colors.dart';
import '../../../themes/app_spacing.dart';
import '../../../themes/app_text_styles.dart';
import '../../../widgets/badges/badges_grid.dart';
import '../../../widgets/homepage/b12_reminder_banner.dart';
import '../../../widgets/homepage/share_home_dialog.dart';
import '../../../widgets/shared/app_background.dart';
import '../../../widgets/homepage/promo_carousel.dart';
import '../../../widgets/homepage/solidarity_shops_section.dart';
import '../../../widgets/homepage/stat_card.dart';
import '../../../widgets/shared/app_card.dart';
import '../../../widgets/shared/shine_wrapper.dart';
import '../../../widgets/shared/social_feedback_buttons.dart';
import '../../../widgets/vegandex/vegandex_modal.dart';
import '../Profile/b12_reminder_settings_page.dart';
import '../Profile/subscription_page.dart';
import '../Profile/error_reports_page.dart';
import '../Profile/product_review_page.dart';
import '../settings/settings_page.dart';

/// Merges the former "Accueil" and "Profil" tabs into a single home screen:
/// vegan-since counter + impact stats, partner promos, badges and the
/// account shortcuts that used to live on the Profil tab.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  DateTime? _targetDate;
  Map<String, int> _savings = {};
  Timer? _timer;
  late ConfettiController _confettiController;

  User? _user;
  String? _avatar;
  List<Partners> _partners = [];
  bool _b12BannerDismissed = true; // hidden until the real value loads
  bool _b12Enabled = false;
  bool _b12TakenToday = false;
  Set<String> _vegandexEans = {};
  ErrorReportPaginated? _errorReportsFirstPage;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 6));
    _timer =
        Timer.periodic(const Duration(minutes: 1), (_) => _updateSavings());
    _loadAll();
    ProfileNotificationService.listenable.addListener(_onNotificationsChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confettiController.dispose();
    ProfileNotificationService.listenable
        .removeListener(_onNotificationsChanged);
    super.dispose();
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadTargetDate(),
      _loadUser(),
      _loadPartners(),
      _loadB12State(),
      _loadVegandexProducts(),
      _checkErrorReportResponses(),
    ]);
    _checkForNewBadges();
  }

  /// Re-fetches user-owned data. Called after returning from [SettingsPage],
  /// where the vegan date, avatar, or B12 reminder may have changed.
  Future<void> refresh() async {
    await Future.wait([
      _loadTargetDate(),
      _loadUser(),
      _loadB12State(),
    ]);
    // The vegan date may have moved enough to unlock an anniversary badge.
    _checkForNewBadges();
  }

  Future<void> _loadTargetDate() async {
    final date = await PreferencesHelper.getSelectedDateFromPrefs();
    if (!mounted) return;
    setState(() {
      _targetDate = date;
      _savings = computeSavings(date);
    });
  }

  void _updateSavings() {
    if (mounted) setState(() => _savings = computeSavings(_targetDate));
  }

  Future<void> _loadUser() async {
    final avatar = await PreferencesHelper.getAvatar();
    User? user;
    if (AuthService.isLoggedIn) {
      // Snapshot before the fetch: only a cold start or a fresh login (right
      // after logout cleared the in-memory user) leaves this null. Seeding
      // the badge baseline only in that case — not on every reload — is
      // what lets a fresh login after logout show popups for badges the
      // account already has, instead of silently re-marking them as seen.
      final isFirstFetchThisSession = AuthService.currentUser == null;
      final result = await AuthService.getCurrentUser();
      if (result.isSuccess) {
        user = result.data;
        if (user != null && isFirstFetchThisSession) {
          await BadgeService.initializeBadgeTracking(user);
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _avatar = avatar;
      _user = user;
    });
  }

  Future<void> _loadPartners() async {
    final partners = await ApiService.getPartners();
    if (!mounted) return;
    setState(() => _partners = partners);
  }

  Future<void> _loadB12State() async {
    final settings = await B12ReminderService.getSettings();
    final dismissed = await PreferencesHelper.hasB12BannerBeenDismissed();
    final history = await B12ReminderService.getB12IntakeHistory();
    final today = DateTime.now();
    final takenToday = history.isNotEmpty &&
        history.first.year == today.year &&
        history.first.month == today.month &&
        history.first.day == today.day;
    if (!mounted) return;
    setState(() {
      _b12Enabled = settings.enabled;
      _b12BannerDismissed = dismissed;
      _b12TakenToday = takenToday;
    });
  }

  Future<void> _markB12Taken() async {
    await B12ReminderService.recordB12Intake();
    if (!mounted) return;
    setState(() => _b12TakenToday = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bien reçu !'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadVegandexProducts() async {
    final products = await ProductsOfInterestCache.loadProductsOfInterest();
    if (!mounted) return;
    setState(() => _vegandexEans = products.map((p) => p.ean).toSet());
  }

  Future<void> _checkErrorReportResponses() async {
    final result = await ErrorReportBadgeService.refreshUnreadCount();
    if (result == null || !mounted) return;
    setState(() => _errorReportsFirstPage = result);
  }

  Future<void> _checkForNewBadges() async {
    if (!AuthService.isLoggedIn || !mounted) return;
    final result = await AuthService.getCurrentUser();
    if (result.isSuccess && result.data != null && mounted) {
      await BadgeService.checkAndShowNewBadges(context, result.data!,
          mounted: mounted);
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    if (mounted) refresh();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now(),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
    );
    if (picked == null || picked == _targetDate) return;
    await PreferencesHelper.addSelectedDateToPrefs(picked);
    AnniversaryService.scheduleAnniversary(picked);
    if (!mounted) return;
    setState(() {
      _targetDate = picked;
      _savings = computeSavings(picked);
    });
    // Picking an earlier date can retroactively unlock an anniversary badge.
    _checkForNewBadges();
  }

  Future<void> _launchCounter() async {
    final now = DateTime.now();
    await PreferencesHelper.addSelectedDateToPrefs(now);
    AnniversaryService.scheduleAnniversary(now);
    if (!mounted) return;
    setState(() {
      _targetDate = now;
      _savings = computeSavings(now);
    });
    _confettiController.play();
  }

  Future<void> _openErrorReports() async {
    // Logged-out users have no reports to show — send them through the
    // same login/create-account gate as the Paramètres tab instead of
    // opening a page that would just error out fetching them.
    if (!AuthService.isLoggedIn) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
      if (mounted) refresh();
      return;
    }

    if (ErrorReportBadgeService.unreadCount.value > 0) {
      ErrorReportBadgeService.markHandledAsSeen(
          _errorReportsFirstPage?.items ?? []);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ErrorReportsPage(initialData: _errorReportsFirstPage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysSince = _targetDate == null
        ? null
        : DateTime.now().difference(_targetDate!).inDays;

    return AppBackground(
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    if (!SubscriptionService.isSubscribed ||
                        !AuthService.isLoggedIn) ...[
                      SizedBox(height: AppSpacing.section),
                      _buildSupportButton(context),
                    ],
                    SizedBox(height: 24.h),
                    const PromoCarousel(),
                    SizedBox(height: AppSpacing.section),
                    if (!_b12Enabled && !_b12BannerDismissed) ...[
                      B12ReminderBanner(
                        onActivate: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const B12ReminderSettingsPage()),
                          );
                          _loadB12State();
                        },
                        onDismiss: () async {
                          await PreferencesHelper.markB12BannerDismissed();
                          if (mounted) {
                            setState(() => _b12BannerDismissed = true);
                          }
                        },
                      ),
                      SizedBox(height: AppSpacing.section),
                    ] else if (_b12Enabled && !_b12TakenToday) ...[
                      B12IntakeButton(onPressed: _markB12Taken),
                      SizedBox(height: AppSpacing.section),
                    ],
                    _buildVeganCounterRow(context, daysSince),
                    SizedBox(height: AppSpacing.afterTitle),
                    for (int i = 0; i < homeStats.length; i++) ...[
                      if (i > 0) SizedBox(height: AppSpacing.item),
                      buildStatCard(
                        context,
                        homeStats[i],
                        _savings[homeStats[i].savingsKey] ?? 0,
                      ),
                    ],
                    SizedBox(height: AppSpacing.section),
                    SolidarityShopsSection(partners: _partners),
                    SizedBox(height: AppSpacing.section),
                    BadgesGrid(user: _user),
                    SizedBox(height: AppSpacing.section),
                    _buildVegandexCard(context),
                    if (_user?.isContributor ?? false) ...[
                      SizedBox(height: AppSpacing.section),
                      _buildContributorCard(context),
                    ],
                    SizedBox(height: AppSpacing.section),
                    const SocialFeedbackButtons(showCard: true),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 20,
                  maxBlastForce: 50,
                  shouldLoop: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final name = _user?.nickname ?? 'Bienvenue';
    final notifCount = ProfileNotificationService.total;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _openSettings,
            child: Row(
              children: [
                // Raw image, no disc background or clipping: the avatar
                // assets are irregular shapes with transparency.
                SizedBox(
                  width: 162.w,
                  height: 162.w,
                  child: Image.asset(
                    'lib/assets/avatars/${_avatar ?? 'cochon.png'}',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                SizedBox(width: 20.w),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.pageTitle,
                      ),
                      if (_b12TakenToday)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'B12 prise',
                              style: TextStyle(
                                fontSize: 40.sp,
                                fontWeight: FontWeight.w600,
                                color: kAccentYellow,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Icon(Icons.check,
                                size: 40.sp, color: kAccentYellow),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildIconButton(
          icon: Icons.notifications_none_rounded,
          badgeCount: notifCount,
          onTap: _openErrorReports,
        ),
        SizedBox(width: 30.w),
        _buildIconButton(icon: Icons.settings_outlined, onTap: _openSettings),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Figma spec: 47×47, radius 12, padding 11.5 (×3 units).
          Container(
            width: 141.w,
            height: 141.w,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.grey[700], size: 72.sp),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -8.w,
              top: -8.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 15.w),
                height: 64.w,
                constraints: BoxConstraints(minWidth: 44.w),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(22.w),
                  border: Border.all(color: Colors.white, width: 3.w),
                ),
                child: Center(
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        height: 1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Full-width support pill shown to non-subscribers, carried over from
  /// the old home page (purple gradient + heart), tap → subscription page.
  Widget _buildSupportButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionPage()),
        );
        if (mounted) setState(() {});
      },
      child: ShineWrapper(
        borderRadius: 40,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 30.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(40.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite, color: Colors.white, size: 44.sp),
              SizedBox(width: 12.w),
              Text(
                'Soutenir 321 Vegan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Baloo2',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVeganCounterRow(BuildContext context, int? daysSince) {
    return Row(
      children: [
        Expanded(
          // Tapping the title adjusts the start date (also editable from
          // the "Végane depuis" row in Paramètres).
          child: GestureDetector(
            onTap: daysSince == null ? null : _pickDate,
            child: Text(
              daysSince == null
                  ? 'Vegan depuis 0 jours'
                  : 'Végane depuis $daysSince jour${daysSince > 1 ? 's' : ''}',
              style: AppTextStyles.sectionTitle,
            ),
          ),
        ),
        if (daysSince == null)
          // Figma spec: hug 114×44, radius 100 (pill), padding 13 (v) /
          // 24 (h), bg Primary/Default — ×3 for ScreenUtil units.
          ElevatedButton(
            onPressed: _launchCounter,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 72.w, vertical: 39.h),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const StadiumBorder(),
            ),
            child: Text(
              'Démarrer',
              style: TextStyle(
                fontSize: 44.sp,
                fontFamily: 'Karla',
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          )
        else
          GestureDetector(
            onTap: () => showShareHomeDialog(
              context,
              targetDate: _targetDate!,
              savings: _savings,
            ),
            child: Padding(
              padding: EdgeInsets.all(8.w),
              child: Icon(
                Icons.share,
                size: 64.sp,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVegandexCard(BuildContext context) {
    final totalCount = _vegandexEans.length;
    final scannedCount = totalCount > 0
        ? (_user?.scannedProducts
                ?.where((sp) => _vegandexEans.contains(sp.ean))
                .length ??
            0)
        : (_user?.scannedProducts?.length ?? 0);
    final progress =
        totalCount > 0 ? (scannedCount / totalCount).clamp(0.0, 1.0) : 0.0;
    final isComplete = totalCount > 0 && scannedCount >= totalCount;
    final primary = Theme.of(context).colorScheme.primary;
    const gold = Color(0xFFFFD700);

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: const VegandexModal(),
        ),
      ),
      child: ShineWrapper(
        borderRadius: 28,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(28.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, primary.withAlpha(190)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28.r),
            boxShadow: [
              BoxShadow(
                  color: primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isComplete ? Icons.emoji_events : Icons.catching_pokemon,
                      size: 56.sp,
                      color: isComplete ? gold : Colors.white,
                    ),
                  ),
                  SizedBox(width: 20.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vegandex',
                            style: TextStyle(
                                fontSize: 52.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        SizedBox(height: 4.h),
                        Text(
                          isComplete
                              ? 'Collection complète, bravo !'
                              : scannedCount > 0
                                  ? 'Continuez la collection !'
                                  : 'Collectionnez les produits !',
                          style: TextStyle(
                              fontSize: 36.sp,
                              color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 48.sp, color: Colors.white70),
                ],
              ),
              if (totalCount > 0) ...[
                SizedBox(height: 28.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$scannedCount / $totalCount produits',
                        style: TextStyle(
                            fontSize: 38.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text('${(progress * 100).round()} %',
                          style: TextStyle(
                              fontSize: 36.sp,
                              fontWeight: FontWeight.bold,
                              color: isComplete ? gold : Colors.white)),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14.r),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: progress),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 28.h,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          isComplete ? gold : Colors.white),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContributorCard(BuildContext context) {
    final nbProductsModified = _user?.nbProductsModified ?? 0;
    final nbCheckings = _user?.nbCheckings ?? 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: const BoxDecoration(
                  color: kAccentYellow,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.star, size: 44.sp, color: Colors.white),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contributions', style: AppTextStyles.sectionTitle),
                    Text('Merci pour votre aide précieuse !',
                        style: TextStyle(
                            fontSize: 36.sp, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.afterTitle),
          Row(
            children: [
              Expanded(
                child: _contributorStat(
                  nbProductsModified,
                  'Produit${nbProductsModified > 1 ? 's' : ''}',
                ),
              ),
              SizedBox(width: AppSpacing.item),
              Expanded(
                child: _contributorStat(
                  nbCheckings,
                  'Contact${nbCheckings > 1 ? 's' : ''}',
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.item),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ProductReviewPage()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 18.h),
                shape: const StadiumBorder(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Valider des produits',
                      style: TextStyle(
                          fontSize: 38.sp, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contributorStat(int value, String label) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6F2),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: kBorderDefault),
      ),
      child: Column(
        children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 56.sp,
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary)),
          SizedBox(height: 4.h),
          Text(label,
              style: TextStyle(fontSize: 36.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
