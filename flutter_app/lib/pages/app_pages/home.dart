import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/widgets/shared/app_bottom_nav.dart';
import 'package:vegan_app/helpers/vegan_savings.dart';
import 'package:vegan_app/pages/app_pages/Scan/scan.dart';
import 'package:vegan_app/pages/app_pages/dashboard/dashboard_page.dart';
import 'package:vegan_app/pages/app_pages/map.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vegan_app/services/anniversary_service.dart';
import 'package:vegan_app/services/auth_service.dart';
import 'package:vegan_app/services/b12_reminder_service.dart';
import 'package:vegan_app/services/notification_service.dart';
import 'package:vegan_app/services/profile_notification_service.dart';
import 'package:vegan_app/services/subscription_service.dart';
import 'package:vegan_app/pages/app_pages/Profile/subscription_page.dart';
import 'package:vegan_app/pages/app_pages/Scan/membership_prompt_dialog.dart';
import 'package:vegan_app/widgets/homepage/anniversary_dialog.dart';
import 'package:video_player/video_player.dart';

const int _dashboardTabIndex = 0;
const int _scanTabIndex = 1;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  DateTime? _targetDate;
  late TabController _tabController;
  late ConfettiController _confettiController;
  bool _b12NavigationHandled = false;
  bool _themedNavBar = false;
  int _profileNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initializeDateFormatting('fr_FR', null);

    _tabController = TabController(
      initialIndex: _dashboardTabIndex,
      length: 3,
      vsync: this,
    );
    // Swiping the TabBarView changes the index without going through the
    // bar's onTap; rebuild so index-dependent widgets stay in sync.
    _tabController.addListener(_onTabIndexChanged);
    _initializeTabController();

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 6));

    _loadThemedNavBarPref();
    _loadTargetDate();
    _checkMembershipPrompt();

    // Numeric badge on the Dashboard tab for unread in-app notifications
    // (signalement responses, and any future source).
    ProfileNotificationService.listenable
        .addListener(_onProfileNotificationsChanged);
    ProfileNotificationService.refreshAll();

    // Restyle the tab bar as soon as the preference is toggled in settings
    PreferencesHelper.themedNavBarNotifier.addListener(_onThemedNavBarChanged);

    // Listen for B12 notification taps → navigate to the Dashboard tab
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
      setState(() {
        _tabController.index = _scanTabIndex;
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
        _tabController.index = _dashboardTabIndex;
      });
    }
  }

  void _onAnniversaryNotificationTap() {
    if (NotificationService.showAnniversary.value && mounted) {
      NotificationService.showAnniversary.value = false;
      setState(() {
        _tabController.index = _dashboardTabIndex;
      });
      _confettiController.play();
      _presentAnniversaryDialog();
    }
  }

  Future<void> _presentAnniversaryDialog() async {
    // Cold start (notification tapped from a terminated app) can reach here
    // before _loadTargetDate() has populated targetDate, so load it first.
    if (_targetDate == null) {
      await _loadTargetDate();
    }
    if (_targetDate == null) return; // No vegan date → nothing to celebrate.

    final savings = computeSavings(_targetDate);
    final years = AnniversaryService.veganYears(_targetDate!);
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

  void _onProfileNotificationsChanged() {
    if (mounted) {
      setState(() {
        _profileNotificationCount = ProfileNotificationService.total;
      });
    }
  }

  Future<void> _loadTargetDate() async {
    final date = await PreferencesHelper.getSelectedDateFromPrefs();
    if (mounted) setState(() => _targetDate = date);
  }

  @override
  void dispose() {
    PreferencesHelper.themedNavBarNotifier
        .removeListener(_onThemedNavBarChanged);
    ProfileNotificationService.listenable
        .removeListener(_onProfileNotificationsChanged);
    NotificationService.navigateToProfile.removeListener(_onB12NotificationTap);
    NotificationService.showAnniversary
        .removeListener(_onAnniversaryNotificationTap);
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_onTabIndexChanged);
    _tabController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _onLoginSuccess() async {
    await ProfileNotificationService.refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              const DashboardPage(),
              ScanPage(
                onNavigateToProfile: () {
                  setState(() {
                    _tabController.index = _dashboardTabIndex;
                  });
                },
                onLoginSuccess: _onLoginSuccess,
              ),
              MapPage(onLoginSuccess: _onLoginSuccess),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: ConfettiWidget(
                numberOfParticles: 20,
                maxBlastForce: 50.r,
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _tabController.index,
        themed: _themedNavBar,
        badges: {
          if (_profileNotificationCount > 0)
            _dashboardTabIndex: _profileNotificationCount,
        },
        items: const [
          AppBottomNavItem(
            icon: CupertinoIcons.house,
            activeIcon: CupertinoIcons.house_fill,
            label: 'Dashboard',
          ),
          AppBottomNavItem(
            icon: CupertinoIcons.barcode_viewfinder,
            label: 'Scan',
          ),
          AppBottomNavItem(icon: Icons.travel_explore, label: 'Carte'),
        ],
        onTap: (int value) {
          setState(() {
            _tabController.index = value;
          });
          if (value == _dashboardTabIndex) {
            _checkMembershipPrompt();
          }
        },
      ),
    );
  }
}
