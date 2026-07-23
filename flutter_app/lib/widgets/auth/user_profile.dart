import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../services/auth_service.dart';
import '../../services/badge_service.dart';
import '../../services/error_report_badge_service.dart';
import '../../models/error_report.dart';
import '../../models/user.dart';
import '../../models/badge.dart' as app_badge;
import '../../pages/app_pages/Scan/history_modal.dart';
import '../../pages/app_pages/Scan/sent_products_modal.dart';
import '../../pages/app_pages/Scan/settings_modal.dart';
import '../../helpers/preference_helper.dart';
import '../../services/products_of_interest_cache.dart';
import './edit_profile_modal.dart';
import '../shared/social_feedback_buttons.dart';
import '../shared/shine_wrapper.dart';
import '../vegandex/vegandex_modal.dart';
import '../theme/theme_selector_modal.dart';
import '../../pages/app_pages/Profile/b12_reminder_settings_page.dart';
import '../../pages/app_pages/Profile/error_reports_modal.dart';
import '../../pages/app_pages/Profile/subscription_page.dart';
import '../../pages/app_pages/Profile/product_review_page.dart';
import '../../services/b12_reminder_service.dart';
import '../../services/subscription_service.dart';

class UserProfile extends StatefulWidget {
  final VoidCallback? onLogout;
  final Function(DateTime)? onDateSaved;

  const UserProfile({
    super.key,
    this.onLogout,
    this.onDateSaved,
  });

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  User? _user;
  bool _isLoading = false;
  int _scanCount = 0;
  String? _selectedAvatar;
  bool _openOnScanPage = false;
  bool _showBoycott = true;
  bool _showScores = true;
  bool _hapticFeedback = true;
  List<DateTime> _b12History = [];
  int _b12Streak = 0;
  DateTime? _b12NextIntake;
  Set<String> _vegandexEans = {};
  ErrorReportPaginated? _errorReportsFirstPage;
  int _unreadErrorResponses = 0;

  final List<String> _availableAvatars = [
    'lapin.png',
    'ver.png',
    'poisson.png',
    'canard.png',
    'poule.png',
    'mouton.png',
    'cochon.png',
    'vache.png',
    'chat.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadPreferences();
    _loadB12History();
    _loadVegandexProducts();
    _checkErrorReportResponses();
    // Reload when the post-login sync restores the server-side history
    // after this page has already loaded its local copy.
    B12ReminderService.historyRevision.addListener(_onB12HistoryChanged);
  }

  @override
  void dispose() {
    B12ReminderService.historyRevision.removeListener(_onB12HistoryChanged);
    super.dispose();
  }

  void _onB12HistoryChanged() => _loadB12History();

  /// Fetch the recent error reports and count the treated ones whose
  /// response the user hasn't opened yet (badge on "Mes signalements").
  /// The fetched page is kept and handed to the listing modal so opening
  /// it doesn't refetch the same data.
  Future<void> _checkErrorReportResponses() async {
    final result = await ErrorReportBadgeService.refreshUnreadCount();
    if (result == null) return;
    if (mounted) {
      setState(() {
        _errorReportsFirstPage = result;
        _unreadErrorResponses = ErrorReportBadgeService.unreadCount.value;
      });
    }
  }

  Future<void> _loadVegandexProducts() async {
    final products = await ProductsOfInterestCache.loadProductsOfInterest();
    if (mounted) {
      setState(() {
        _vegandexEans = products.map((p) => p.ean).toSet();
      });
    }
  }

  Future<void> _loadB12History() async {
    final history = await B12ReminderService.getB12IntakeHistory();
    final streak = await B12ReminderService.getB12Streak();
    final nextIntake = await B12ReminderService.getNextExpectedIntakeDate();
    if (mounted) {
      setState(() {
        _b12History = history;
        _b12Streak = streak;
        _b12NextIntake = nextIntake;
      });
    }
  }

  bool get _b12TakenToday {
    if (_b12History.isEmpty) return false;
    final today = DateTime.now();
    final last = _b12History.first;
    return last.year == today.year &&
        last.month == today.month &&
        last.day == today.day;
  }

  Future<void> _markB12AsTaken() async {
    await B12ReminderService.recordB12Intake();
    await _loadB12History();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bien reçu !'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _getRandomAvatar(String? currentAvatar) {
    final random = Random();
    final availableCopy = List<String>.from(_availableAvatars);

    // Remove current avatar from available choices
    if (currentAvatar != null && availableCopy.contains(currentAvatar)) {
      availableCopy.remove(currentAvatar);
    }

    // If we still have options, pick a random one
    if (availableCopy.isNotEmpty) {
      return availableCopy[random.nextInt(availableCopy.length)];
    }

    // Fallback: return a random avatar from full list
    return _availableAvatars[random.nextInt(_availableAvatars.length)];
  }

  Future<void> _loadUserInfo() async {
    setState(() => _isLoading = true);

    final result = await AuthService.getCurrentUser();
    final avatar = await PreferencesHelper.getAvatar();
    final randomAvatarEnabled =
        await PreferencesHelper.getRandomAvatarEnabled();
    // The local total is the source of truth on this device, but the server
    // counter can be higher when the account scanned on another device.
    final localScanCount = await PreferencesHelper.getTotalScanCount();

    if (mounted) {
      String? finalAvatar = avatar;

      // If random avatar is enabled, pick a new random one
      if (randomAvatarEnabled) {
        finalAvatar = _getRandomAvatar(avatar);
        // Save the new random avatar
        await PreferencesHelper.saveAvatar(finalAvatar);
      } else if (result.isSuccess) {
        final serverAvatar = result.data?.avatar;
        if (serverAvatar != null && serverAvatar != finalAvatar) {
          // The account's avatar wins over the device's: it holds the last
          // explicit choice, possibly made on another device or before a
          // reinstall. Explicit changes reach the account through the edit
          // profile modal, never from here.
          finalAvatar = serverAvatar;
          await PreferencesHelper.saveAvatar(finalAvatar);
        } else if (serverAvatar == null && finalAvatar != null) {
          // Account predates avatar sync: claim the device's avatar.
          // Fire-and-forget: a network failure must not block the page.
          AuthService.updateUser(avatar: finalAvatar);
        }
      }

      setState(() {
        _isLoading = false;
        _selectedAvatar = finalAvatar;
        if (result.isSuccess) {
          _user = result.data;
        }
        _scanCount = max(localScanCount, _user?.scanCount ?? 0);
      });
    }
  }

  Future<void> _loadPreferences() async {
    final openOnScanPage = await PreferencesHelper.getOpenOnScanPagePref();
    final showBoycott = await PreferencesHelper.getShowBoycottPref();
    final showScores = await PreferencesHelper.getShowScoresPref();
    final hapticFeedback = await PreferencesHelper.getHapticFeedbackPref();
    if (mounted) {
      setState(() {
        _openOnScanPage = openOnScanPage;
        _showBoycott = showBoycott;
        _showScores = showScores;
        _hapticFeedback = hapticFeedback;
      });
    }
  }

  void _showSettingsModal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: SettingsModal(
            initialOpenOnScanPage: _openOnScanPage,
            onOpenOnScanPageChanged: (value) {
              setState(() {
                _openOnScanPage = value;
              });
            },
            initialShowBoycott: _showBoycott,
            onShowBoycottChanged: (value) {
              setState(() {
                _showBoycott = value;
              });
            },
            initialShowScores: _showScores,
            onShowScoresChanged: (value) {
              setState(() {
                _showScores = value;
              });
            },
            initialHapticFeedback: _hapticFeedback,
            onHapticFeedbackChanged: (value) {
              setState(() {
                _hapticFeedback = value;
              });
            },
          ),
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);

    final result = await AuthService.logout();

    // Clear badge tracking on logout
    await BadgeService.clearBadgeTracking();

    if (mounted) {
      setState(() => _isLoading = false);

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Déconnexion réussie !'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onLogout?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Erreur lors de la déconnexion'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    setState(() => _isLoading = true);
    final result = await AuthService.deleteAccount(context, _user);

    // Clear badge tracking on account deletion
    await BadgeService.clearBadgeTracking();

    if (mounted) {
      setState(() => _isLoading = false);
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte supprimé avec succès.'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onLogout?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(result.error ?? 'Erreur lors de la suppression du compte'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfileCard(),
        SizedBox(height: 24.h),
        _buildSupportButton(),
        SizedBox(height: 24.h),
        _buildStatsCards(),
        if ((_user?.nbProductsModified ?? 0) > 0 ||
            (_user?.nbCheckings ?? 0) > 0 ||
            (_user?.isContributor ?? false)) ...[
          SizedBox(height: 24.h),
          _buildContributorCards(),
        ],
        SizedBox(height: 24.h),
        _buildVegandexCard(),
        SizedBox(height: 24.h),
        _buildB12HistoryCard(),
        SizedBox(height: 24.h),
        _buildErrorReportsCard(),
        SizedBox(height: 24.h),
        _buildBadgesSection(),
        SizedBox(height: 24.h),
        _buildSettingsCard(),
        SizedBox(height: 24.h),
        _buildSocialAndFeedbackSection(),
        SizedBox(height: 32.h),
        _buildActionsCard(),
      ],
    );
  }

  Widget _buildProfileCard() {
    return _buildCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile avatar with edit badge
          Stack(
            children: [
              GestureDetector(
                onTap: _openEditProfileModal,
                child: SizedBox(
                  width: 400.w,
                  height: 480.w,
                  child: ClipOval(
                    child: _selectedAvatar != null
                        ? Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Image.asset(
                              'lib/assets/avatars/$_selectedAvatar',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  size: 64.sp,
                                  color: Colors.green,
                                );
                              },
                            ),
                          )
                        : Image.asset(
                            'lib/assets/avatars/cochon.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                size: 64.sp,
                                color: Colors.green,
                              );
                            },
                          ),
                  ),
                ),
              ),
              // Edit badge overlay
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _openEditProfileModal,
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.edit,
                      size: 48.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(width: 24.w),

          // User info with B12 reminder
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user?.nickname ?? 'Utilisateur·ice',
                  style: TextStyle(
                    fontSize: 56.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  _user?.email ?? '',
                  style: TextStyle(
                    fontSize: 44.sp,
                    color: Colors.grey[600],
                  ),
                ),

                // B12 Reminder with golden background
                SizedBox(height: 30.h),
                GestureDetector(
                  onTap: _navigateToB12Settings,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFD700), // Gold
                          Color(0xFFFFE44D), // Lighter gold
                          Color(0xFFFFD700), // Gold
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    child: Row(
                      children: [
                        Icon(
                          Icons.alarm,
                          size: 48.sp,
                          color: Colors.grey[800],
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rappel B12',
                                style: TextStyle(
                                  fontSize: 44.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 40.sp,
                          color: Colors.grey[700],
                        ),
                      ],
                    ),
                  ),
                ),

                // Theme selection
                SizedBox(height: 24.h),
                GestureDetector(
                  onTap: _showThemeSelector,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.8),
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.6),
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                    child: Row(
                      children: [
                        Icon(
                          Icons.palette,
                          size: 64.sp,
                          color: Colors.white,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Thèmes',
                                style: TextStyle(
                                  fontSize: 44.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 40.sp,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportButton() {
    return GestureDetector(
        onTap: _openSubscriptionPage,
        child: ShineWrapper(
          borderRadius: 12,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: SubscriptionService.isSubscribed
                    ? [
                        Colors.amber.shade600,
                        Colors.orange.shade600,
                      ]
                    : [
                        Colors.pink.shade400,
                        Colors.deepPurple.shade400,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: (SubscriptionService.isSubscribed
                          ? Colors.amber
                          : Colors.pink)
                      .withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            child: Row(
              children: [
                Icon(
                  SubscriptionService.isSubscribed
                      ? Icons.military_tech
                      : Icons.favorite,
                  size: 48.sp,
                  color: Colors.white,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        SubscriptionService.isSubscribed
                            ? 'Abonnement actif'
                            : 'Soutenir 321 Vegan',
                        style: TextStyle(
                          fontSize: 44.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 40.sp,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ));
  }

  void _openEditProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.r),
            topRight: Radius.circular(20.r),
          ),
        ),
        child: EditProfileModal(
          currentNickname: _user?.nickname ?? 'Utilisateur·ice',
          currentAvatar: _selectedAvatar,
          currentEmail: _user?.email ?? '',
          onProfileUpdated: () {
            _loadUserInfo();
          },
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        // Scanned products card
        Expanded(
          child: _buildStatCard(
            icon: CupertinoIcons.barcode,
            iconColor: Colors.teal,
            title: 'Produits scannés',
            value: _scanCount.toString(),
            onTap: () async {
              final history = await PreferencesHelper.getScanHistory();
              if (!mounted) return;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.9,
                  child: HistoryModal(scanHistory: history),
                ),
              );
            },
          ),
        ),
        SizedBox(width: 16.w),
        // Products sent card
        Expanded(
          child: _buildStatCard(
            icon: Icons.info_outline,
            iconColor: Colors.black,
            title: 'Produits envoyés',
            value: _user?.nbProductsSent?.toString() ?? '0',
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.9,
                  child: const SentProductsModal(),
                ),
              );
            },
          ),
        ),
        SizedBox(width: 16.w),
        // Vegan since card
        Expanded(
          child: _buildStatCard(
            icon: Icons.calendar_today,
            iconColor: Theme.of(context).colorScheme.primary,
            title: 'Végane depuis',
            value: _user?.veganSince != null
                ? DateFormat.yMMMd('fr_FR').format(_user!.veganSince!)
                : 'Non défini',
            onTap: _pickVeganDate,
          ),
        ),
      ],
    );
  }

  Widget _buildContributorCards() {
    final nbProductsModified = _user?.nbProductsModified ?? 0;
    final nbCheckings = _user?.nbCheckings ?? 0;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star,
                  size: 48.sp,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contributions',
                      style: TextStyle(
                        fontSize: 52.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      'Merci pour votre aide précieuse !',
                      style: TextStyle(
                        fontSize: 36.sp,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          // Contributor stats in a row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1A722E).withValues(alpha: 0.1),
                        const Color(0xFF1A722E).withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: const Color(0xFF1A722E).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        nbProductsModified.toString(),
                        style: TextStyle(
                          fontSize: 56.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A722E),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Produit${nbProductsModified > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 36.sp,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade500.withValues(alpha: 0.1),
                        Colors.blue.shade500.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: Colors.blue.shade500.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        nbCheckings.toString(),
                        style: TextStyle(
                          fontSize: 56.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Contact${nbCheckings > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 36.sp,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_user?.isContributor ?? false) ...[
            SizedBox(height: 20.h),
            GestureDetector(
              onTap: _openProductReviewPage,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_note_outlined,
                        size: 64.sp, color: Colors.white),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Text(
                        'Valider des produits',
                        style: TextStyle(
                          fontSize: 44.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        size: 40.sp, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openProductReviewPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProductReviewPage(),
      ),
    );
  }

  void _navigateToB12Settings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const B12ReminderSettingsPage(),
      ),
    );
  }

  Widget _buildB12HistoryCard() {
    final formatter = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    final lastTaken = _b12History.isNotEmpty ? _b12History.first : null;
    final takenToday = _b12TakenToday;

    return _buildCard(
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _b12History.isNotEmpty ? () => _showB12HistoryModal() : null,
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '💊',
                    style: TextStyle(fontSize: 48.sp),
                  ),
                ),
                SizedBox(width: 20.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Historique B12',
                        style: TextStyle(
                          fontSize: 52.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4.h),
                      if (lastTaken != null)
                        Text(
                          'Dernière prise : ${formatter.format(lastTaken)}',
                          style: TextStyle(
                            fontSize: 36.sp,
                            color: Colors.grey[600],
                          ),
                        )
                      else
                        Text(
                          'Aucune prise enregistrée',
                          style: TextStyle(
                            fontSize: 36.sp,
                            color: Colors.grey[500],
                          ),
                        ),
                      if (_b12Streak >= 2) ...[
                        SizedBox(height: 12.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade400,
                                Colors.deepOrange.shade400,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '🔥',
                                style: TextStyle(fontSize: 36.sp),
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                '$_b12Streak jours d\'affilée',
                                style: TextStyle(
                                  fontSize: 36.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_b12History.isNotEmpty)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 40.sp,
                    color: Colors.grey[400],
                  ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: takenToday
                ? Container(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 44.sp,
                          color: Colors.green[700],
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          'B12 prise aujourd\'hui',
                          style: TextStyle(
                            fontSize: 40.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _markB12AsTaken,
                    icon: Icon(Icons.check, size: 70.sp),
                    label: Text(
                      'Marquer comme prise aujourd\'hui',
                      style: TextStyle(fontSize: 40.sp),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _capitalizeFr(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  void _showB12HistoryModal() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthFormatter = DateFormat('MMMM yyyy', 'fr_FR');
    final monthCount = _b12History
        .where((d) => d.year == now.year && d.month == now.month)
        .length;

    // Flat list of month headers + intake tiles, in history order
    final items = <Widget>[];
    String? currentMonth;
    for (final date in _b12History) {
      final month = _capitalizeFr(monthFormatter.format(date));
      if (month != currentMonth) {
        currentMonth = month;
        items.add(_buildB12MonthHeader(month, isFirst: items.isEmpty));
      }
      items.add(_buildB12HistoryTile(date, today));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) => GestureDetector(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Column(
                      children: [
                        Container(
                          width: 60.w,
                          height: 6.h,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(3.r),
                          ),
                        ),
                        SizedBox(height: 20.h),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(14.w),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '💊',
                                style: TextStyle(fontSize: 44.sp),
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Text(
                              'Historique B12',
                              style: TextStyle(
                                fontSize: 52.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),
                        Row(
                          children: [
                            _buildB12StatTile(
                              emoji: '🔥',
                              value: '$_b12Streak',
                              label: 'd\'affilée',
                              highlighted: _b12Streak >= 2,
                            ),
                            SizedBox(width: 12.w),
                            _buildB12StatTile(
                              emoji: '📅',
                              value: '$monthCount',
                              label: 'ce mois-ci',
                            ),
                            SizedBox(width: 12.w),
                            _buildB12StatTile(
                              emoji: '✅',
                              value: '${_b12History.length}',
                              label: 'au total',
                            ),
                          ],
                        ),
                        if (_b12NextIntake != null) ...[
                          SizedBox(height: 12.h),
                          _buildB12NextIntakeBanner(today),
                        ],
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey[200]),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
                      itemCount: items.length,
                      itemBuilder: (context, index) => items[index],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildB12StatTile({
    required String emoji,
    required String value,
    required String label,
    bool highlighted = false,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
        decoration: BoxDecoration(
          gradient: highlighted
              ? LinearGradient(
                  colors: [
                    Colors.orange.shade400,
                    Colors.deepOrange.shade400,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: highlighted ? null : Colors.grey[50],
          borderRadius: BorderRadius.circular(16.r),
          border: highlighted ? null : Border.all(color: Colors.grey[200]!),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              '$emoji $value',
              style: TextStyle(
                fontSize: 44.sp,
                fontWeight: FontWeight.bold,
                color: highlighted ? Colors.white : Colors.grey[800],
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.w500,
                color: highlighted
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildB12NextIntakeBanner(DateTime today) {
    final next = _b12NextIntake!;
    final nextDay = DateTime(next.year, next.month, next.day);
    final inDays = nextDay.difference(today).inDays;
    final String label;
    if (inDays <= 0) {
      label = 'aujourd\'hui';
    } else if (inDays == 1) {
      label = 'demain';
    } else {
      label = DateFormat('EEEE d MMMM', 'fr_FR').format(nextDay);
    }
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_repeat, size: 40.sp, color: primary),
          SizedBox(width: 10.w),
          Flexible(
            child: Text(
              'Prochaine prise : $label',
              style: TextStyle(
                fontSize: 34.sp,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildB12MonthHeader(String month, {bool isFirst = false}) {
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 4.h : 20.h, bottom: 12.h),
      child: Text(
        month.toUpperCase(),
        style: TextStyle(
          fontSize: 30.sp,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  Widget _buildB12HistoryTile(DateTime date, DateTime today) {
    final dayFormatter = DateFormat('EEEE d MMMM', 'fr_FR');
    final daysAgo = B12ReminderService.calendarDaysBetween(date, today);
    final isToday = daysAgo == 0;
    final isYesterday = daysAgo == 1;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: isToday ? primary.withValues(alpha: 0.08) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isToday
              ? primary.withValues(alpha: 0.3)
              : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 90.w,
            height: 90.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? primary : primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 38.sp,
                fontWeight: FontWeight.bold,
                color: isToday ? Colors.white : primary,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              _capitalizeFr(dayFormatter.format(date)),
              style: TextStyle(
                fontSize: 38.sp,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
          ),
          if (isToday || isYesterday)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isToday ? primary : Colors.grey[200],
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                isToday ? 'Aujourd\'hui' : 'Hier',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w600,
                  color: isToday ? Colors.white : Colors.grey[600],
                ),
              ),
            )
          else
            Icon(
              Icons.check_circle,
              size: 40.sp,
              color: primary.withValues(alpha: 0.5),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return GestureDetector(
      onTap: _showSettingsModal,
      child: _buildCard(
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.settings,
                size: 56.sp,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(width: 20.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Options',
                    style: TextStyle(
                      fontSize: 52.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Personnalisez votre expérience',
                    style: TextStyle(
                      fontSize: 36.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 48.sp,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void _openSubscriptionPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SubscriptionPage()),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: const ThemeSelectorModal(),
      ),
    );
  }

  void _showVegandexModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: const VegandexModal(),
      ),
    );
  }

  Widget _buildVegandexCard() {
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
      onTap: _showVegandexModal,
      child: ShineWrapper(
        borderRadius: 28,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(28.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primary,
                primary.withAlpha(190),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28.r),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
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
                        Text(
                          'Vegandex',
                          style: TextStyle(
                            fontSize: 52.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          isComplete
                              ? 'Collection complète, bravo !'
                              : scannedCount > 0
                                  ? 'Continuez la collection !'
                                  : 'Collectionnez les produits !',
                          style: TextStyle(
                            fontSize: 36.sp,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 48.sp,
                    color: Colors.white70,
                  ),
                ],
              ),
              if (totalCount > 0) ...[
                SizedBox(height: 28.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$scannedCount / $totalCount produits',
                      style: TextStyle(
                        fontSize: 38.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        '${(progress * 100).round()} %',
                        style: TextStyle(
                          fontSize: 36.sp,
                          fontWeight: FontWeight.bold,
                          color: isComplete ? gold : Colors.white,
                        ),
                      ),
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
                        isComplete ? gold : Colors.white,
                      ),
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

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48.sp,
                color: iconColor,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 36.sp,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              value,
              style: TextStyle(
                fontSize: 44.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVeganDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _user?.veganSince ?? DateTime.now(),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
    );

    if (picked != null && picked != _user?.veganSince) {
      setState(() => _isLoading = true);

      // Update both local storage and backend (via PreferencesHelper)
      await PreferencesHelper.addSelectedDateToPrefs(picked);

      // Refresh user data from backend to get the updated info
      final result = await AuthService.getCurrentUser();

      if (mounted) {
        setState(() => _isLoading = false);

        if (result.isSuccess) {
          setState(() {
            _user = result.data;
          });

          // Notify the home page about the date change
          widget.onDateSaved?.call(picked);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Date mise à jour avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Erreur lors de la mise à jour'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildActionsCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Actions du compte',
            style: TextStyle(
              fontSize: 52.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 24.h),

          // Account info text
          Text(
            'Votre compte permet de conserver certaines données et de collectionner des badges.',
            style: TextStyle(
              fontSize: 42.sp,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          SizedBox(height: 32.h),

          // Logout button
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleLogout,
            icon: _isLoading
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.logout),
            label: Text(
              _isLoading ? 'Déconnexion...' : 'Se déconnecter',
              style: TextStyle(fontSize: 44.sp),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: 24.w,
                vertical: 16.h,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),

          // Delete button
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleDeleteAccount,
            icon: _isLoading
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.delete),
            label: Text(
              _isLoading ? 'Suppression...' : 'Supprimer mon compte',
              style: TextStyle(fontSize: 44.sp),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: 24.w,
                vertical: 16.h,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorReportsCard() {
    final count = _user?.nbErrorReports ?? 0;
    final unread = _unreadErrorResponses;

    return GestureDetector(
      onTap: () {
        // Opening the listing acknowledges the treated reports: the
        // "unread responses" badge disappears.
        if (unread > 0) {
          ErrorReportBadgeService.markHandledAsSeen(
              _errorReportsFirstPage?.items ?? []);
          setState(() => _unreadErrorResponses = 0);
        }
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.9,
            child: ErrorReportsModal(initialData: _errorReportsFirstPage),
          ),
        );
      },
      child: _buildCard(
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.flag_outlined,
                size: 48.sp,
                color: Colors.orange[800],
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mes signalements',
                    style: TextStyle(
                      fontSize: 52.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    unread > 0
                        ? '$unread réponse${unread > 1 ? 's' : ''} non lue${unread > 1 ? 's' : ''} !'
                        : count > 0
                            ? '$count signalement${count > 1 ? 's' : ''} envoyé${count > 1 ? 's' : ''}'
                            : 'Aucun signalement envoyé',
                    style: TextStyle(
                      fontSize: 36.sp,
                      color: unread > 0 ? Colors.red[700] : Colors.grey[600],
                      fontWeight:
                          unread > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (unread > 0) ...[
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$unread',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 16.w),
            ],
            Icon(
              Icons.arrow_forward_ios,
              size: 48.sp,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesSection() {
    final productsSent = _user?.nbProductsSent ?? 0;
    final veganSince = _user?.veganSince;
    final supporterLevel = _user?.supporterLevel ?? 0;
    final errorReports = _user?.nbErrorReports ?? 0;

    // Sort badges: unlocked first, then locked
    // Supporter badge is always first (locked or not)
    final sortedBadges = List<app_badge.Badge>.from(app_badge.Badges.all);
    sortedBadges.sort((a, b) {
      if (a.type == app_badge.BadgeType.supporter) return -1;
      if (b.type == app_badge.BadgeType.supporter) return 1;

      final aUnlocked = a.isUnlocked(
        productsSent: productsSent,
        veganSince: veganSince,
        supporterLevel: supporterLevel,
        errorSolved: errorReports,
      );
      final bUnlocked = b.isUnlocked(
        productsSent: productsSent,
        veganSince: veganSince,
        supporterLevel: supporterLevel,
        errorSolved: errorReports,
      );

      // Unlocked badges first (true comes before false)
      if (aUnlocked && !bUnlocked) return -1;
      if (!aUnlocked && bUnlocked) return 1;
      return 0; // Keep original order within same unlock status
    });

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              Icon(
                Icons.emoji_events,
                size: 64.sp,
                color: Colors.amber[700],
              ),
              SizedBox(width: 40.w),
              Text(
                'Badges',
                style: TextStyle(
                  fontSize: 56.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Badges grid (show all)
          GridView.builder(
            padding: EdgeInsets.all(25.w),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16.w,
              mainAxisSpacing: 16.h,
              childAspectRatio: 0.85,
            ),
            itemCount: sortedBadges.length,
            itemBuilder: (context, index) {
              final badge = sortedBadges[index];
              final isUnlocked = badge.isUnlocked(
                productsSent: productsSent,
                veganSince: veganSince,
                supporterLevel: supporterLevel,
                errorSolved: errorReports,
              );

              return _buildBadgeItem(badge, isUnlocked);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSocialAndFeedbackSection() {
    return const SocialFeedbackButtons(showCard: true);
  }

  Widget _buildBadgeItem(app_badge.Badge badge, bool isUnlocked) {
    final progress = badge.getProgress(
      productsSent: _user?.nbProductsSent ?? 0,
      veganSince: _user?.veganSince,
      supporterLevel: _user?.supporterLevel ?? 0,
      errorSolved: _user?.nbErrorReports ?? 0,
    );

    return GestureDetector(
      onTap: () => _showBadgeDetails(badge, isUnlocked),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge icon with progress ring while locked
          SizedBox(
            width: 180.w,
            height: 180.w,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnlocked ? Colors.white : Colors.grey[300],
                    border: Border.all(
                      color: isUnlocked
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[400]!,
                      width: isUnlocked ? 3 : 2,
                    ),
                    boxShadow: isUnlocked
                        ? [
                            BoxShadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withAlpha(80),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: _buildBadgeIcon(badge, isUnlocked),
                ),
                if (!isUnlocked && progress > 0)
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.transparent,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.orange[700]!),
                  ),
              ],
            ),
          ),

          SizedBox(height: 8.h),

          // Badge name
          Text(
            badge.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 32.sp,
              fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
              color: isUnlocked ? Colors.grey[800] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeIcon(app_badge.Badge badge, bool isUnlocked) {
    return ClipOval(
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.all(20.w),
                    child: ColorFiltered(
                      colorFilter: isUnlocked
                          ? const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.multiply,
                            )
                          : const ColorFilter.matrix(<double>[
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0,
                              0,
                              0,
                              1,
                              0,
                            ]),
                      child: Image.asset(
                        badge.iconPath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.emoji_events,
                            size: 80.sp,
                            color: isUnlocked
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[600],
                          );
                        },
                      ),
                    ),
                  ),
                  if (!isUnlocked)
                    Center(
                      child: Icon(
                        Icons.lock,
                        size: 64.sp,
                        color: Colors.orange[700],
                      ),
                    ),
                ],
              ),
    );
  }

  void _showBadgeDetails(app_badge.Badge badge, bool isUnlocked) {
    final progress = badge.getProgress(
      productsSent: _user?.nbProductsSent ?? 0,
      veganSince: _user?.veganSince,
      supporterLevel: _user?.supporterLevel ?? 0,
      errorSolved: _user?.nbErrorReports ?? 0,
    );
    final progressText = badge.getProgressText(
      productsSent: _user?.nbProductsSent ?? 0,
      veganSince: _user?.veganSince,
      supporterLevel: _user?.supporterLevel ?? 0,
      errorSolved: _user?.nbErrorReports ?? 0,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge icon
            Container(
              width: 200.w,
              height: 200.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnlocked ? Colors.white : Colors.grey[300],
                border: Border.all(
                  color: isUnlocked
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[400]!,
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(24.w),
                      child: ColorFiltered(
                        colorFilter: isUnlocked
                            ? const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.multiply,
                              )
                            : const ColorFilter.matrix(<double>[
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                              ]),
                        child: Image.asset(
                          badge.iconPath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.emoji_events,
                              size: 100.sp,
                              color: isUnlocked
                                  ? Colors.amber[700]
                                  : Colors.grey[600],
                            );
                          },
                        ),
                      ),
                    ),
                    if (!isUnlocked)
                      Center(
                        child: Icon(
                          Icons.lock,
                          size: 64.sp,
                          color: Colors.orange[700],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24.h),

            // Badge name
            Text(
              badge.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 56.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),

            SizedBox(height: 12.h),

            // Badge description
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 44.sp,
                color: Colors.grey[600],
              ),
            ),

            SizedBox(height: 16.h),

            // Status
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 8.h,
              ),
              decoration: BoxDecoration(
                color: isUnlocked
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isUnlocked ? Colors.green : Colors.orange,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUnlocked ? Icons.check_circle : Icons.lock_outline,
                    size: 44.sp,
                    color: isUnlocked ? Colors.green : Colors.orange,
                  ),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: Text(
                      isUnlocked
                          ? 'Badge débloqué !'
                          : badge.getRequirementText(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 40.sp,
                        fontWeight: FontWeight.w600,
                        color:
                            isUnlocked ? Colors.green[700] : Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Progress toward unlocking
            if (!isUnlocked && progressText != null) ...[
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    progressText,
                    style: TextStyle(
                      fontSize: 40.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()} %',
                    style: TextStyle(
                      fontSize: 40.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: progress),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 20.h,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.orange[700]!,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(28.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: child,
    );
  }
}
