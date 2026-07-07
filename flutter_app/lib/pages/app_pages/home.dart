import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/pages/app_pages/Partners/partners_page.dart';
import 'package:vegan_app/pages/app_pages/Scan/scan.dart';
import 'package:vegan_app/pages/app_pages/map.dart';
import 'package:vegan_app/pages/app_pages/profile.dart';
import 'package:vegan_app/helpers/time_counter/time_counter.dart';
import 'package:vegan_app/widgets/homepage/stat_card.dart';
import 'package:vegan_app/widgets/homepage/draggable_profile_bubble.dart';
import 'package:vegan_app/widgets/homepage/share_home_dialog.dart';
import 'package:vegan_app/widgets/homepage/anniversary_dialog.dart';
import 'package:vegan_app/services/anniversary_service.dart';
import 'package:vegan_app/services/subscription_service.dart';
import 'package:vegan_app/pages/app_pages/Profile/subscription_page.dart';
import 'package:confetti/confetti.dart';
import 'package:vegan_app/widgets/wave_clipper.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vegan_app/services/auth_service.dart';
import 'package:vegan_app/services/b12_reminder_service.dart';
import 'package:vegan_app/services/badge_service.dart';
import 'package:vegan_app/services/notification_service.dart';
import 'package:vegan_app/models/seasonal_theme.dart';
import 'package:vegan_app/widgets/theme/seasonal_icon.dart';
import 'package:vegan_app/widgets/shared/shine_wrapper.dart';
import 'package:vegan_app/pages/app_pages/Scan/membership_prompt_dialog.dart';
import 'package:video_player/video_player.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  DateTime? targetDate;
  late TabController _tabController;
  late Map<String, int> _savings;
  late Timer _timer;
  late ConfettiController _confettiController;
  final TextEditingController _dateController = TextEditingController();
  bool _hasNewPartners = false;
  late AnimationController _partnersAnimationController;
  String? _currentAvatar;
  int _profileKey = 0;
  bool _b12NavigationHandled = false;
  bool _themedNavBar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initializeDateFormatting('fr_FR', null);
    _timer = Timer.periodic(
        const Duration(minutes: 1), (Timer t) => _updateSavings());

    // Initialize with default home tab, then update based on preference
    _tabController = TabController(
      initialIndex: 1, // Default to home tab
      length: 5,
      vsync: this,
    );

    // Swiping the TabBarView changes the index without going through the
    // bar's onTap; rebuild so index-dependent widgets (profile bubble)
    // stay in sync.
    _tabController.addListener(_onTabIndexChanged);

    _initializeTabController();

    _savings = {};
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 6));

    _partnersAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _loadData();
    _checkNewPartners();
    _loadAvatar();
    _loadThemedNavBarPref();

    // Refresh the tab bar avatar as soon as it is changed in the profile page
    PreferencesHelper.avatarNotifier.addListener(_onAvatarChanged);

    // Restyle the tab bar as soon as the preference is toggled in settings
    PreferencesHelper.themedNavBarNotifier.addListener(_onThemedNavBarChanged);

    // Listen for B12 notification taps → navigate to profile tab
    NotificationService.navigateToProfile.addListener(_onB12NotificationTap);
    // Cold start: value may already be true before this listener was registered
    WidgetsBinding.instance.addPostFrameCallback((_) => _onB12NotificationTap());

    // Listen for vegan anniversary notification taps → show congratulation popup
    NotificationService.showAnniversary.addListener(_onAnniversaryNotificationTap);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _onAnniversaryNotificationTap());
  }

  Future<void> _initializeTabController() async {
    final shouldOpenOnScanPage =
        await PreferencesHelper.getOpenOnScanPagePref();
    // A B12 notification tap (cold start) must win over the scan-page
    // preference, whether it was already handled or is still pending.
    if (_b12NavigationHandled || NotificationService.navigateToProfile.value) {
      return;
    }
    if (shouldOpenOnScanPage && mounted) {
      // Update to scan tab if preference is set
      setState(() {
        _tabController.index = 2;
      });
    }
  }

  Future<void> _checkMembershipPrompt() async {
    if (!AuthService.isLoggedIn) return;
    if (SubscriptionService.isSubscribed) return;

    final pending = await PreferencesHelper.isMembershipPromptPending();
    if (!pending) return;

    await PreferencesHelper.clearMembershipPromptPending();

    if (!mounted) return;

    // Pre-initialize video before opening dialog so it plays immediately
    final videoController = VideoPlayerController.asset(
      'lib/assets/abonnement-popup-vid.mp4',
    );
    await videoController.initialize();
    videoController.setLooping(true);
    videoController.setVolume(0);
    videoController.play();

    if (!mounted) {
      videoController.dispose();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MembershipPromptDialog(
        videoController: videoController,
        onSupport: () {
          Navigator.of(context).pop();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubscriptionPage()),
          );
        },
        onLater: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      B12ReminderService.checkAndRescheduleIfNeeded();
      _checkMembershipPrompt();
    }
  }

  void _onB12NotificationTap() {
    if (NotificationService.navigateToProfile.value && mounted) {
      NotificationService.navigateToProfile.value = false;
      _b12NavigationHandled = true;
      setState(() {
        _tabController.index = 4; // Profile tab
        _profileKey++; // force ProfilePage to rebuild and re-fetch user info
      });
    }
  }

  void _onAnniversaryNotificationTap() {
    if (NotificationService.showAnniversary.value && mounted) {
      NotificationService.showAnniversary.value = false;
      // Make sure the home tab is visible behind the popup.
      setState(() {
        _tabController.index = 1;
      });
      _confettiController.play();
      _presentAnniversaryDialog();
    }
  }

  Future<void> _presentAnniversaryDialog() async {
    // Cold start (notification tapped from a terminated app) can reach here
    // before _loadData() has populated targetDate/_savings, so load them first.
    if (targetDate == null) {
      await loadTargetDate();
    }
    if (targetDate == null) return; // No vegan date → nothing to celebrate.

    final savings = computeSavings(targetDate);
    final years = AnniversaryService.veganYears(targetDate!);
    final scanCount = await PreferencesHelper.getTotalScanCount();

    // Backend contribution counters — only for logged-in users, and
    // best-effort (omitted when offline / the call fails).
    int? productsSent;
    int? issuesReported;
    if (AuthService.isLoggedIn) {
      final result = await AuthService.getCurrentUser();
      if (result.isSuccess && result.data != null) {
        productsSent = result.data!.nbProductsSent;
        issuesReported = result.data!.nbErrorReports;
      }
    }

    if (!mounted) return;
    showAnniversaryDialog(
      context,
      years: years,
      savings: savings,
      scanCount: scanCount,
      productsSent: productsSent,
      issuesReported: issuesReported,
    );
  }

  void _onTabIndexChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onAvatarChanged() {
    if (mounted) {
      setState(() {
        _currentAvatar = PreferencesHelper.avatarNotifier.value;
      });
    }
  }

  Future<void> _loadThemedNavBarPref() async {
    final value = await PreferencesHelper.getThemedNavBarPref();
    if (mounted) {
      setState(() {
        _themedNavBar = value;
      });
    }
  }

  void _onThemedNavBarChanged() {
    if (mounted) {
      setState(() {
        _themedNavBar = PreferencesHelper.themedNavBarNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    PreferencesHelper.avatarNotifier.removeListener(_onAvatarChanged);
    PreferencesHelper.themedNavBarNotifier
        .removeListener(_onThemedNavBarChanged);
    NotificationService.navigateToProfile.removeListener(_onB12NotificationTap);
    NotificationService.showAnniversary
        .removeListener(_onAnniversaryNotificationTap);
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_onTabIndexChanged);
    _tabController.dispose();
    _confettiController.dispose();
    _partnersAnimationController.dispose();
    _timer.cancel();
    _dateController.dispose();
    super.dispose();
  }

  void _loadData() async {
    await loadTargetDate();
    final savings = computeSavings(targetDate);
    setState(() {
      _savings = savings;
    });

    // Check for new badges on initial load
    _checkForNewBadges();

    _checkMembershipPrompt();

    // One-time: existing users with a vegan date who were never asked for
    // notification permission (e.g. never set up B12) get prompted once, so the
    // yearly anniversary notification can be scheduled.
    _ensureAnniversaryScheduled();
  }

  Future<void> _ensureAnniversaryScheduled() async {
    if (targetDate == null) return;
    if (await PreferencesHelper.hasNotificationPermissionBeenAsked()) return;
    await PreferencesHelper.markNotificationPermissionAsked();
    // Requests the app-wide notification permission (if not already granted)
    // and schedules the anniversary notification.
    await AnniversaryService.scheduleAnniversary(targetDate!);
  }

  void _onDateSaved(DateTime date) {
    setState(() {
      targetDate = date;
      _savings = computeSavings(targetDate);
    });
    // Keep the yearly anniversary notification in sync with the chosen date.
    AnniversaryService.scheduleAnniversary(date);
  }

  Future<void> _onLoginSuccess() async {
    // Reload target date from preferences after login
    await loadTargetDate();
    // The vegan start date may have been synced from the backend → reschedule.
    if (targetDate != null) {
      AnniversaryService.scheduleAnniversary(targetDate!);
    }
    // Reload avatar after login
    await _loadAvatar();
  }

  Future<void> _checkNewPartners() async {
    final hasNew = await PreferencesHelper.hasNewPartners();
    if (mounted) {
      setState(() {
        _hasNewPartners = hasNew;
      });
    }
  }

  Future<void> _loadAvatar() async {
    if (AuthService.isLoggedIn) {
      final avatar = await PreferencesHelper.getAvatar();
      if (mounted) {
        setState(() {
          _currentAvatar = avatar;
        });
      }
    } else if (mounted) {
      setState(() {
        _currentAvatar = null;
      });
    }
  }

  Widget _buildAvatarTabIcon() {
    // Raw image, no ClipOval: the avatar assets are irregular shapes with
    // transparency, clipping to a circle cuts them (e.g. the worm's head).
    return Image.asset(
      'lib/assets/avatars/${_currentAvatar ?? 'cochon.png'}',
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.person_sharp,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: targetDate ?? DateTime.now(),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != targetDate) {
      setState(() {
        targetDate = picked;
        _dateController.text = DateFormat.yMMMd('fr_FR').format(targetDate!);
      });

      await PreferencesHelper.addSelectedDateToPrefs(targetDate!);
      _onDateSaved(targetDate!);
    }
  }

  Future<void> loadTargetDate() async {
    final DateTime? dateFromPrefs =
        await PreferencesHelper.getSelectedDateFromPrefs();
    setState(() {
      targetDate = dateFromPrefs;
      if (targetDate != null) {
        _dateController.text = DateFormat.yMMMd('fr_FR').format(targetDate!);
      } else {
        _dateController.clear();
      }
      _savings = computeSavings(targetDate);
    });
  }

  void _updateSavings() {
    setState(() {
      _savings = computeSavings(targetDate);
    });
  }

  Future<void> _checkForNewBadges() async {
    // Check if user is logged in and get current user
    if (AuthService.isLoggedIn && mounted) {
      final result = await AuthService.getCurrentUser();
      if (result.isSuccess && result.data != null && mounted) {
        await BadgeService.checkAndShowNewBadges(
          context,
          result.data!,
          mounted: mounted,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: Stack(
            children: [
              TabBarView(
                controller: _tabController,
                children: [
                  const PartnersPage(),
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: ClipPath(
                            clipper: WaveClipper(),
                            child: Container(
                                color: Theme.of(context)
                                        .extension<SeasonalTheme>()
                                        ?.waveColor ??
                                    Theme.of(context).colorScheme.primary,
                                height: 480.h),
                          ),
                        ),
                        Positioned(
                          top: 42.h,
                          left: -72.w,
                          child: Opacity(
                            opacity: 1.0,
                            child:
                                Theme.of(context).extension<SeasonalTheme>() !=
                                        null
                                    ? SeasonalIcon(
                                        theme: Theme.of(context)
                                            .extension<SeasonalTheme>()!)
                                    : Icon(
                                        Icons.sunny,
                                        size: 889.r,
                                        color: Colors.white,
                                      ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            SizedBox(height: 200.h),
                            if (!SubscriptionService.isSubscribed)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding:
                                      EdgeInsets.only(left: 16.w, bottom: 8.h),
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const SubscriptionPage(),
                                        ),
                                      );
                                    },
                                    child: ShineWrapper(
                                      borderRadius: 40,
                                      child: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 28.w, vertical: 14.h),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF7C3AED),
                                                Color(0xFFA855F7),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(40.r),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF7C3AED)
                                                    .withValues(alpha: 0.35),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.favorite,
                                                  color: Colors.white,
                                                  size: 44.sp),
                                              SizedBox(width: 10.w),
                                              Text(
                                                'Soutenir 321 Vegan',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 40.sp,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Baloo',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            Text(
                              "Vous êtes végane depuis",
                              style: TextStyle(
                                  fontSize: 90.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  fontFamily: 'Baloo'),
                            ),
                            Center(
                              child: TimeCounter(targetDate: targetDate),
                            ),
                            ...homeStats.map(
                              (stat) => buildStatCard(
                                context,
                                stat,
                                _savings[stat.savingsKey] ?? 0,
                                theme: Theme.of(context)
                                    .extension<SeasonalTheme>(),
                              ),
                            ),
                          ],
                        ),
                        if (targetDate == null)
                          Positioned(
                            bottom: 100.h,
                            child: ElevatedButton(
                              onPressed: launchCounter,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 32.w, vertical: 12.h),
                                textStyle: TextStyle(
                                  fontSize: 20.sp,
                                  fontFamily: 'Baloo',
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.r),
                                ),
                              ),
                              child: Text('Démarrer le compteur',
                                  style: TextStyle(fontSize: 60.sp)),
                            ),
                          )
                        else
                          Positioned(
                            bottom: 120.h,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 32.w, vertical: 12.h),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat.yMd('fr_FR').format(targetDate!),
                                    style: TextStyle(
                                      fontSize: 50.sp,
                                      fontFamily: 'Baloo',
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(width: 20.w),
                                  GestureDetector(
                                    onTap: _pickDate,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 20.w, vertical: 8.h),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        borderRadius:
                                            BorderRadius.circular(20.r),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "Modifier",
                                            style: TextStyle(
                                              fontSize: 45.sp,
                                              fontFamily: 'Baloo',
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          Icon(
                                            Icons.calendar_today,
                                            color: Colors.white,
                                            size: 40.sp,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (targetDate != null)
                          Positioned(
                            top: 160.h,
                            right: 40.w,
                            child: GestureDetector(
                              onTap: () => showShareHomeDialog(
                                context,
                                targetDate: targetDate!,
                                savings: _savings,
                              ),
                              child: Container(
                                padding: EdgeInsets.all(24.w),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.share_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 56.sp,
                                ),
                              ),
                            ),
                          ),
                        ConfettiWidget(
                          numberOfParticles: 20,
                          maxBlastForce: 50.r,
                          confettiController: _confettiController,
                          blastDirectionality: BlastDirectionality.explosive,
                          shouldLoop: false,
                          colors: Theme.of(context)
                                  .extension<SeasonalTheme>()
                                  ?.confettiColors ??
                              const [
                                Colors.red,
                                Colors.blue,
                                Colors.green,
                                Colors.yellow,
                              ],
                        ),
                      ],
                    ),
                  ),
                  ScanPage(
                    onNavigateToProfile: () {
                      setState(() {
                        _tabController.index = 4;
                      });
                    },
                    onLoginSuccess: _onLoginSuccess,
                  ),
                  MapPage(onLoginSuccess: _onLoginSuccess),
                  ProfilePage(
                    key: ValueKey(_profileKey),
                    onDateSaved: _onDateSaved,
                    onLoginSuccess: _onLoginSuccess,
                  ),
                ],
              ),
              // Draggable profile bubble. only when logged in and on home tab
              if (AuthService.isLoggedIn && _tabController.index == 1)
                DraggableProfileBubble(
                  avatar: _currentAvatar,
                  onTap: () {
                    setState(() {
                      _tabController.index = 4;
                    });
                  },
                ),
            ],
          ),
          bottomNavigationBar: StyleProvider(
            style: _TabBarStyle(),
            child: ConvexAppBar.badge(
              // Animated notification badge for partners tab
              _hasNewPartners
                  ? <int, dynamic>{0: 'new'}
                  : const <int, dynamic>{},
              // Offsets the dot to the top-right of the centered icon.
              badgeMargin: const EdgeInsets.only(left: 24, bottom: 24),
              controller: _tabController,
              // react style: enlarged active icon, no background disc — so
              // the avatar renders as-is, unclipped, on the convex bulge.
              style: TabStyle.react,
              backgroundColor: _themedNavBar
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white,
              color: _themedNavBar ? Colors.white : Colors.grey,
              activeColor: _themedNavBar
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
              items: [
                const TabItem(icon: Icons.percent, title: "Promos"),
                const TabItem(icon: Icons.home_rounded, title: "Accueil"),
                const TabItem(
                    icon: CupertinoIcons.barcode, title: "Scan"),
                const TabItem(icon: Icons.travel_explore, title: "Carte"),
                // Show the user's avatar on the Profil tab when logged in;
                // logged-out users keep the default person icon. Inactive,
                // the avatar is painted ~35% larger than its icon box so it
                // reads bigger than the plain icons.
                if (AuthService.isLoggedIn)
                  TabItem<Widget>(
                    icon: Transform.scale(
                      scale: 1.35,
                      child: _buildAvatarTabIcon(),
                    ),
                    activeIcon: _buildAvatarTabIcon(),
                    title: "Profil",
                  )
                else
                  const TabItem(icon: Icons.person_sharp, title: "Profil"),
              ],
              onTap: (int value) async {
                // The bar already drives _tabController; rebuild so widgets
                // that depend on the index (profile bubble) stay in sync.
                setState(() {});
                // Refresh so an avatar changed in the profile page shows
                // up in the tab bar right away
                _loadAvatar();
                // Check for new badges when Accueil tab is selected
                if (value == 1) {
                  _checkForNewBadges();
                  _checkMembershipPrompt();
                }
                // Mark partners as visited when tab is selected
                if (value == 0 && _hasNewPartners) {
                  await PreferencesHelper.markPartnersAsVisited();
                  await _checkNewPartners();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Map<String, int> computeSavings(DateTime? targetTime) {
    // Constant values for each unit, per day.
    const double animalPer = 1.3;
    const double co2Per = 9.0;
    const double waterPer = 2.271;
    const double forestPer = 2.7;

    Duration duration = Duration.zero;
    if (targetTime != null) {
      duration = DateTime.now().difference(targetTime);
    }
    final double days = duration.inMinutes / 1440.0;
    final int animalUnit = (days * animalPer).toInt();
    final int co2Unit = (days * co2Per).toInt();
    final int waterUnit = (days * waterPer).toInt();
    final int forestUnit = (days * forestPer).toInt();

    return {
      'animalUnit': animalUnit,
      'co2Unit': co2Unit,
      'waterUnit': waterUnit,
      'forestUnit': forestUnit,
    };
  }

  void launchCounter() async {
    final DateTime now = DateTime.now();
    await PreferencesHelper.addSelectedDateToPrefs(now);

    setState(() {
      targetDate = now;
      _savings = computeSavings(targetDate);
    });

    // Schedule the yearly anniversary notification for this start date.
    AnniversaryService.scheduleAnniversary(now);

    _confettiController.play();
  }
}

/// Sizing for the tab bar: smaller inactive icons, large active icon/avatar.
/// With [TabStyle.react] there is no background disc, so [activeIconSize]
/// applies to the icon (or avatar) itself.
class _TabBarStyle extends StyleHook {
  @override
  double? get iconSize => 20;

  @override
  double get activeIconMargin => 5; // only used by the circle styles

  @override
  double get activeIconSize => 50;

  @override
  TextStyle textStyle(Color color, String? fontFamily) {
    return TextStyle(color: color, fontFamily: 'Baloo');
  }
}

