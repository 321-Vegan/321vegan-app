import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/announcements.dart';
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
import 'package:vegan_app/services/deep_link_service.dart';
import 'package:vegan_app/services/notification_service.dart';
import 'package:vegan_app/services/profile_notification_service.dart';
import 'package:vegan_app/widgets/homepage/anniversary_dialog.dart';
import 'package:vegan_app/models/restaurants/restaurant_selection.dart';
import 'package:vegan_app/widgets/auth/auth_bottom_sheet.dart';
import 'package:vegan_app/widgets/restaurants/selection_page.dart';

const int _dashboardTabIndex = 0;
const int _scanTabIndex = 1;
const int _mapTabIndex = 2;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  static MyHomePageState? of(BuildContext context) {
    return context.findAncestorStateOfType<MyHomePageState>();
  }

  @override
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  DateTime? _targetDate;
  late TabController _tabController;
  late ConfettiController _confettiController;

  bool _notificationForcedDashboard = false;
  bool _openedFromLink = false;

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
    _applyOpenOnScanPagePref();

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 6));

    _loadTargetDate();

    // Populates ProfileNotificationService.total, read directly by the
    // Dashboard header's notification bell badge.
    ProfileNotificationService.refreshAll();

    // Listen for B12 notification taps → navigate to the Dashboard tab
    NotificationService.navigateToProfile.addListener(_onB12NotificationTap);
    // Cold start: value may already be true before this listener was registered
    WidgetsBinding.instance.addPostFrameCallback((_) => _onB12NotificationTap());

    // Listen for vegan anniversary notification taps → show congratulation popup
    NotificationService.showAnniversary.addListener(_onAnniversaryNotificationTap);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _onAnniversaryNotificationTap());

    // Listen for a pushed page (e.g. scan/sent history empty state) asking
    // to jump to the Scan tab.
    NotificationService.navigateToScan.addListener(_onNavigateToScan);

    // Link to a public selection opened → its page. Cold start (or link
    // opened during the onboarding): it may already be set.
    DeepLinkService.selectionId.addListener(_onSelectionLink);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSelectionLink());

    WidgetsBinding.instance.addPostFrameCallback((_) => _showAnnouncement());
  }

  /// Shows the next unseen app news (one per launch), once the home screen
  /// has settled.
  Future<void> _showAnnouncement() async {
    await Future.delayed(const Duration(seconds: 1));
    // Don't stack it on the anniversary popup or a selection opened by a link
    if (!mounted || _notificationForcedDashboard || _openedFromLink) return;
    await AnnouncementCenter.showNext(context, home: this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      B12ReminderService.checkAndRescheduleIfNeeded();
      // Selections sent, signalement answers... while the app was in the
      // background (it can stay there for days)
      ProfileNotificationService.refreshAll();
    }
  }

  void _onB12NotificationTap() {
    if (NotificationService.navigateToProfile.value && mounted) {
      NotificationService.navigateToProfile.value = false;
      _notificationForcedDashboard = true;
      setState(() {
        _tabController.index = _dashboardTabIndex;
      });
    }
  }

  void _onAnniversaryNotificationTap() {
    if (NotificationService.showAnniversary.value && mounted) {
      NotificationService.showAnniversary.value = false;
      _notificationForcedDashboard = true;
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

  /// Opens the selection of a link, over whatever is shown. The API needs an
  /// account, even for a public one: logged out, it opens once logged in.
  void _onSelectionLink() {
    final id = DeepLinkService.selectionId.value;
    if (id == null || !mounted) return;
    DeepLinkService.selectionId.value = null;
    _openedFromLink = true;

    // The page loads it from its id (unavailable if it isn't public)
    void open() {
      if (!mounted) return;
      SelectionPage.open(
        context,
        RestaurantSelection(
            id: id, title: '', ownerNickname: '', isOwner: false),
      );
    }

    if (AuthService.isLoggedIn) {
      open();
      return;
    }
    showAuthBottomSheet(context, onSuccess: () {
      _onLoginSuccess();
      open();
    });
  }

  void _onNavigateToScan() {
    if (NotificationService.navigateToScan.value && mounted) {
      NotificationService.navigateToScan.value = false;
      setState(() {
        _tabController.index = _scanTabIndex;
      });
    }
  }

  void _onTabIndexChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _applyOpenOnScanPagePref() async {
    final shouldOpenOnScanPage =
        await PreferencesHelper.getOpenOnScanPagePref();
    if (!shouldOpenOnScanPage) return;
    await NotificationService.launchDetailsReady
        .timeout(const Duration(milliseconds: 800), onTimeout: () {});

    if (!_notificationForcedDashboard &&
        !NotificationService.navigateToProfile.value &&
        !NotificationService.showAnniversary.value &&
        mounted) {
      setState(() {
        _tabController.index = _scanTabIndex;
      });
    }
  }

  Future<void> _loadTargetDate() async {
    final date = await PreferencesHelper.getSelectedDateFromPrefs();
    if (mounted) setState(() => _targetDate = date);
  }

  @override
  void dispose() {
    NotificationService.navigateToProfile.removeListener(_onB12NotificationTap);
    NotificationService.showAnniversary
        .removeListener(_onAnniversaryNotificationTap);
    NotificationService.navigateToScan.removeListener(_onNavigateToScan);
    DeepLinkService.selectionId.removeListener(_onSelectionLink);
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_onTabIndexChanged);
    _tabController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _onLoginSuccess() async {
    await ProfileNotificationService.refreshAll();
  }

  /// Switches to the Map tab (e.g. from a Dashboard promo slide).
  void goToMapTab() {
    _tabController.animateTo(_mapTabIndex);
  }

  /// Switches to the Scan tab (e.g. from an announcement).
  void goToScanTab() {
    _tabController.animateTo(_scanTabIndex);
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
              ScanPage(onLoginSuccess: _onLoginSuccess),
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
        items: const [
          AppBottomNavItem(
            iconAsset: 'lib/assets/images/icons/home-off.webp',
            activeIconAsset: 'lib/assets/images/icons/home-on.webp',
            label: 'Accueil',
          ),
          AppBottomNavItem(
            iconAsset: 'lib/assets/images/icons/scan.webp',
            label: 'Scan',
          ),
          AppBottomNavItem(
            iconAsset: 'lib/assets/images/icons/map-off.webp',
            activeIconAsset: 'lib/assets/images/icons/map-on.webp',
            label: 'Carte',
          ),
        ],
        onTap: (int value) {
          setState(() {
            _tabController.index = value;
          });
        },
      ),
    );
  }
}
