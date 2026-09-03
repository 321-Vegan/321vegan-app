import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../helpers/preference_helper.dart';
import '../../../helpers/vegan_savings.dart';
import '../../../models/error_report.dart';
import '../../../models/partners/partners.dart';
import '../../../models/seasonal_theme.dart';
import '../../../models/user.dart';
import '../../../services/anniversary_service.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/b12_reminder_service.dart';
import '../../../services/badge_service.dart';
import '../../../services/error_report_badge_service.dart';
import '../../../services/profile_notification_service.dart';
import '../../../themes/app_colors.dart';
import '../../../themes/app_shapes.dart';
import '../../../themes/app_spacing.dart';
import '../../../themes/app_text_styles.dart';
import '../../../widgets/badges/badges_grid.dart';
import '../../../widgets/homepage/b12_reminder_banner.dart';
import '../../../widgets/homepage/share_home_dialog.dart';
import '../../../widgets/shared/app_background.dart';
import '../../../widgets/shared/app_button.dart';
import '../../../widgets/shared/square_icon_button.dart';
import '../../../widgets/homepage/promo_carousel.dart';
import '../../../widgets/homepage/solidarity_shops_section.dart';
import '../../../widgets/homepage/stat_card.dart';
import '../../../widgets/homepage/vegan_counter.dart';
import '../../../widgets/shared/app_card.dart';
import '../../../widgets/shared/vegan_since_date_modal.dart';
import '../../../widgets/b12/b12_reminder_settings_modal.dart';
import '../Profile/error_reports_page.dart';
import '../Profile/product_review_page.dart';
import '../settings/settings_page.dart';

/// Vegan-since counter + impact stats, partner promos, badges and the
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

  // Seed with whatever AuthService already has cached (e.g. from the
  // background sync in AuthService.init()) so the first build doesn't grey
  // out badges/hide the contributor card while _loadUser()'s own fetch is
  // still in flight.
  User? _user = AuthService.currentUser;
  String? _avatar;
  List<Partners> _partners = [];
  bool _b12BannerDismissed = true; // hidden until the real value loads
  bool _b12Enabled = false;
  bool _b12TakenToday = false;
  bool _b12DueToday = false;
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
      // Null only on cold start or right after logout. Seeding the badge
      // baseline just in that case (not every reload) lets a fresh login
      // show popups for badges the account already has.
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
      _b12DueToday = B12ReminderService.isDueDay(today, settings);
    });
  }

  Future<void> _markB12Taken() async {
    await B12ReminderService.recordB12Intake();
    if (!mounted) return;
    setState(() => _b12TakenToday = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bien reçu !'),
        backgroundColor: kSemanticSuccess,
        duration: Duration(seconds: 2),
      ),
    );
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
    final result = await showModalBottomSheet<VeganDateResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VeganSinceDateModal(initialDate: _targetDate),
    );
    if (result == null) return;

    if (result.action == VeganDateAction.delete) {
      await PreferencesHelper.removeSelectedDateFromPrefs();
      await AnniversaryService.cancel();
      if (!mounted) return;
      setState(() {
        _targetDate = null;
        _savings = computeSavings(null);
      });
      return;
    }

    final picked = result.date!;
    if (picked == _targetDate) return;
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

  // ignore: unused_element
  Future<void> _openErrorReports() async {
    // Logged-out users have no reports to show — send them through the
    // same login gate as the Paramètres tab instead of a page that would
    // just error out fetching them.
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
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal, 16.h, AppSpacing.pageHorizontal, 32.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    SizedBox(height: AppSpacing.section),
                    const PromoCarousel(),
                    SizedBox(height: AppSpacing.section),
                    if (!_b12Enabled && !_b12BannerDismissed) ...[
                      B12ReminderBanner(
                        onActivate: () async {
                          await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const B12ReminderSettingsModal(),
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
                    ] else if (_b12Enabled && _b12DueToday && !_b12TakenToday) ...[
                      B12IntakeButton(onPressed: _markB12Taken),
                      SizedBox(height: AppSpacing.section),
                    ],
                    _buildVeganCounterRow(context, daysSince),
                    if (_targetDate != null) ...[
                      SizedBox(height: AppSpacing.afterTitle),
                      VeganCounter(targetDate: _targetDate!),
                    ],
                    SizedBox(height: AppSpacing.afterTitle),
                    _buildStatCards(context),
                    SizedBox(height: AppSpacing.section),
                    SolidarityShopsSection(partners: _partners),
                    SizedBox(height: AppSpacing.section),
                    BadgesGrid(user: _user),
                    if (_user?.isContributor ?? false) ...[
                      SizedBox(height: AppSpacing.section),
                      _buildContributorCard(context),
                    ],
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

  Widget _buildStatCards(BuildContext context) {
    final cards = Column(
      children: [
        for (int i = 0; i < homeStats.length; i++) ...[
          if (i > 0) SizedBox(height: AppSpacing.item),
          buildStatCard(
            context,
            homeStats[i],
            _savings[homeStats[i].savingsKey] ?? 0,
          ),
        ],
      ],
    );

    final seasonal = Theme.of(context).extension<SeasonalTheme>();
    if (seasonal?.season != Season.spring) return cards;

    // Vine draped over the left edge of the first cards
    return Stack(
      clipBehavior: Clip.none,
      children: [
        cards,
        Positioned(
          top: 120.h,
          left: -50.w,
          child: IgnorePointer(
            child: Image.asset(
              'lib/assets/themes/plant.webp',
              width: 230.w,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topLeft,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final name = _user?.nickname ?? 'Bienvenue';
    // final notifCount = ProfileNotificationService.total;

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
                        style: AppTextStyles.baloo26,
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
        // _buildIconButton(
        //   icon: Icons.notifications_none_rounded,
        //   badgeCount: notifCount,
        //   onTap: _openErrorReports,
        // ),
        // SizedBox(width: 30.w),
        _buildIconButton(icon: Icons.settings_outlined, onTap: _openSettings),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SquareIconButton.action(
            icon: icon,
            onTap: onTap,
            iconColor: Colors.grey[700]!,
            shadows: const []),
        if (badgeCount > 0)
          Positioned(
            right: -8.w,
            top: -8.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 15.w),
              height: 64.w,
              constraints: BoxConstraints(minWidth: 44.w),
              decoration: ShapeDecoration(
                color: Colors.red,
                shape: squircleBorder(
                  radius: 22.w,
                  side: BorderSide(color: Colors.white, width: 3.w),
                ),
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
              'Végane depuis',
              style: AppTextStyles.baloo22,
            ),
          ),
        ),
        if (daysSince == null)
          AppButton(
            label: 'Démarrer',
            backgroundColor: Theme.of(context).colorScheme.primary,
            onPressed: _launchCounter,
          )
        else
          IconButton(
            onPressed: () => showShareHomeDialog(
              context,
              targetDate: _targetDate!,
              savings: _savings,
            ),
            padding: EdgeInsets.all(8.w),
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            icon: Image.asset(
              'lib/assets/images/icons/share-line.webp',
              width: 72.sp,
              height: 72.sp,
              color: Theme.of(context).colorScheme.primary,
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
      ],
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
                    Text('Contributions', style: AppTextStyles.baloo22),
                    Text('Merci pour votre aide précieuse !',
                        style: AppTextStyles.bodyRegular15
                            .copyWith(color: Colors.grey[600])),
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
            child: AppButton(
              label: 'Valider des produits',
              backgroundColor: Theme.of(context).colorScheme.primary,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ProductReviewPage()),
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
      decoration: ShapeDecoration(
        color: const Color(0xFFF7F6F2),
        shape: squircleBorder(
          radius: 24.r,
          side: const BorderSide(color: kBorderDefault),
        ),
      ),
      child: Column(
        children: [
          Text('$value', style: AppTextStyles.baloo26),
          SizedBox(height: 4.h),
          Text(label,
              style: AppTextStyles.bodyRegular15.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
