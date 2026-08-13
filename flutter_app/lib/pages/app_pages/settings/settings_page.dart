import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import '../../../helpers/preference_helper.dart';
import '../../../models/error_report.dart';
import '../../../models/seasonal_theme.dart';
import '../../../models/user.dart';
import '../../../services/auth_service.dart';
import '../../../services/b12_reminder_service.dart';
import '../../../services/badge_service.dart';
import '../../../services/error_report_badge_service.dart';
import '../../../widgets/auth/change_email_modal.dart';
import '../../../widgets/auth/change_password_modal.dart';
import '../../../widgets/auth/change_username_modal.dart';
import '../../../widgets/settings/settings_row_tile.dart';
import '../../../widgets/settings/settings_section.dart';
import '../../../themes/app_colors.dart';
import '../../../themes/app_shapes.dart';
import '../../../themes/app_spacing.dart';
import '../../../widgets/settings/settings_toggle_tile.dart';
import '../../../widgets/shared/app_background.dart';
import '../../../widgets/shared/app_button.dart';
import '../../../widgets/shared/shine_wrapper.dart';
import '../../../widgets/shared/vegan_since_date_modal.dart';
import '../../../widgets/theme/theme_selector_modal.dart';
import '../../../main.dart';
import '../Profile/auth_gate_page.dart';
import '../Profile/avatar_selection_page.dart';
import '../Profile/b12_history_page.dart';
import '../Profile/b12_reminder_settings_page.dart';
import '../Scan/scan_history_page.dart';
import '../Scan/sent_products_page.dart';
import 'package:vegan_app/services/subscription_service.dart';
import '../Profile/error_reports_page.dart';
import '../Profile/subscription_page.dart';

/// Full-screen "Paramètres", reached from the Dashboard's gear icon.
/// Logged-out users see the existing login/register flow ([AuthGatePage])
/// unchanged; logged-in users see the redesigned settings list.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  User? _user;
  String? _avatar;
  bool _isLoading = true;

  bool _b12RemindersEnabled = false;
  DateTime? _b12NextReminder;
  bool _showBoycott = true;
  bool _showScores = true;
  bool _hapticFeedback = true;

  int _unreadErrorResponses = 0;
  ErrorReportPaginated? _errorReportsFirstPage;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadUser(),
      _loadPreferences(),
      _loadErrorReports(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUser() async {
    final avatar = await PreferencesHelper.getAvatar();
    User? user;
    if (AuthService.isLoggedIn) {
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

  /// "Prochain rappel : aujourd'hui/demain/<jour> à HH:mm" — null while
  /// reminders are off or nothing is scheduled yet.
  String? get _b12NextReminderLabel {
    final next = _b12NextReminder;
    if (!_b12RemindersEnabled || next == null) return null;

    final dayLabel = B12ReminderService.relativeDayLabel(next);
    final timeLabel = DateFormat('HH:mm').format(next);
    return 'Prochain : $dayLabel à $timeLabel';
  }

  Future<void> _loadPreferences() async {
    final b12Settings = await B12ReminderService.getSettings();
    final b12Next = await B12ReminderService.getNextNotificationTime();
    final showBoycott = await PreferencesHelper.getShowBoycottPref();
    final showScores = await PreferencesHelper.getShowScoresPref();
    final hapticFeedback = await PreferencesHelper.getHapticFeedbackPref();
    if (!mounted) return;
    setState(() {
      _b12RemindersEnabled = b12Settings.enabled;
      _b12NextReminder = b12Next;
      _showBoycott = showBoycott;
      _showScores = showScores;
      _hapticFeedback = hapticFeedback;
    });
  }

  Future<void> _loadErrorReports() async {
    final result = await ErrorReportBadgeService.refreshUnreadCount();
    if (result == null || !mounted) return;
    setState(() {
      _errorReportsFirstPage = result;
      _unreadErrorResponses = ErrorReportBadgeService.unreadCount.value;
    });
  }

  // Turning the switch on needs a frequency/time first, so it opens the B12
  // settings page instead of scheduling a reminder with whatever frequency
  // was last configured (or none). Turning it off needs no such setup.
  Future<void> _toggleB12Reminders(bool value) async {
    if (value) {
      await _openB12Settings();
      return;
    }
    final settings = await B12ReminderService.getSettings();
    await B12ReminderService.scheduleReminder(
        settings.copyWith(enabled: value));
    if (mounted) {
      setState(() {
        _b12RemindersEnabled = value;
        _b12NextReminder = null;
      });
    }
  }

  Future<void> _pickVeganDate() async {
    final sheetResult = await showModalBottomSheet<VeganDateResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VeganSinceDateModal(initialDate: _user?.veganSince),
    );
    if (sheetResult == null) return;

    if (sheetResult.action == VeganDateAction.delete) {
      if (_user?.veganSince == null) return;
      setState(() => _isLoading = true);
      await PreferencesHelper.removeSelectedDateFromPrefs();
      final result = await AuthService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (result.isSuccess) _user = result.data;
      });
      return;
    }

    final picked = sheetResult.date!;
    if (picked == _user?.veganSince) return;

    setState(() => _isLoading = true);
    await PreferencesHelper.addSelectedDateToPrefs(picked);
    final result = await AuthService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.isSuccess) _user = result.data;
    });
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Date mise à jour avec succès !'),
          backgroundColor: kSemanticSuccess,
        ),
      );
    }
  }

  void _openAvatarSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AvatarSelectionPage(
          currentAvatar: _avatar,
          onAvatarUpdated: _loadUser,
        ),
      ),
    );
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

  void _openChangeUsernameModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChangeUsernameModal(
        currentNickname: _user?.nickname ?? 'Utilisateur·ice',
        onUsernameChanged: _loadUser,
      ),
    );
  }

  void _openChangeEmailModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChangeEmailModal(
        currentEmail: _user?.email ?? '',
      ),
    );
  }

  void _openChangePasswordModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ChangePasswordModal(),
    );
  }

  Future<void> _openB12Settings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const B12ReminderSettingsPage()),
    );
    // Frequency/enabled may have changed there — resync the "Rappels" switch.
    if (mounted) _loadPreferences();
  }

  void _openB12History() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const B12HistoryPage()),
    );
  }

  void _openErrorReports() {
    if (_unreadErrorResponses > 0) {
      ErrorReportBadgeService.markHandledAsSeen(
          _errorReportsFirstPage?.items ?? []);
      setState(() => _unreadErrorResponses = 0);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ErrorReportsPage(initialData: _errorReportsFirstPage),
      ),
    );
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);
    final result = await AuthService.logout();
    await BadgeService.clearBadgeTracking();
    if (result.isSuccess) {
      // Subscription status belongs to the account that just logged out —
      // clear it and re-evaluate the theme so a premium seasonal theme
      // doesn't keep showing for a signed-out (or now different) user.
      await SubscriptionService.reset();
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.isSuccess) {
      if (mounted) await MyApp.of(context)?.updateTheme();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Déconnexion réussie !'),
          backgroundColor: kSemanticSuccess,
        ),
      );
      setState(() => _user = null);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Erreur lors de la déconnexion'),
          backgroundColor: kSemanticError,
        ),
      );
    }
  }

  Future<void> _handleDeleteAccount() async {
    setState(() => _isLoading = true);
    final result = await AuthService.deleteAccount(context, _user);
    await BadgeService.clearBadgeTracking();
    if (result.isSuccess) {
      await SubscriptionService.reset();
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.isSuccess) {
      if (mounted) await MyApp.of(context)?.updateTheme();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte supprimé avec succès.'),
          backgroundColor: kSemanticSuccess,
        ),
      );
      setState(() => _user = null);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(result.error ?? 'Erreur lors de la suppression du compte'),
          backgroundColor: kSemanticError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Paramètres',
             style: AppTextStyles.baloo22,
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: SafeArea(
          top: false,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : AuthService.isLoggedIn
                  ? _buildLoggedInBody(context)
                  : SingleChildScrollView(
                      child: AuthGatePage(onLoginSuccess: _loadAll),
                    ),
        ),
      ),
    );
  }

  Widget _buildLoggedInBody(BuildContext context) {
    final themeName =
        Theme.of(context).extension<SeasonalTheme>()?.name ?? 'Aucun';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _openAvatarSelection,
                  // Raw image, no disc background: the avatar assets are
                  // irregular shapes with transparency.
                  child: SizedBox(
                    width: 320.w,
                    height: 320.w,
                    child: Image.asset(
                      'lib/assets/avatars/${_avatar ?? 'cochon.png'}',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person,
                        size: 64.sp,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: GestureDetector(
                    onTap: _openAvatarSelection,
                    // Figma "Button/Primary/Small": hug 34, radius 12,
                    // padding 8 — ×3 for ScreenUtil units.
                    child: Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: ShapeDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: squircleBorder(radius: 36.r),
                        shadows: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.edit, size: 54.sp, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.section),
          _buildPremiumBanner(context),
          SizedBox(height: AppSpacing.section),
          SettingsSection(
            title: 'Compte',
            children: [
              SettingsRowTile(
                label: 'Pseudo',
                value: _user?.nickname ?? '',
                onTap: _openChangeUsernameModal,
              ),
              SettingsRowTile(
                label: 'Végane depuis',
                value: _user?.veganSince != null
                    ? DateFormat.yMMMd('fr_FR').format(_user!.veganSince!)
                    : 'Jamais',
                onTap: _pickVeganDate,
              ),
              SettingsRowTile(
                label: 'Thème',
                labelSuffix: Image.asset(
                  'lib/assets/images/icons/crown-line.webp',
                  width: 72.sp,
                  height: 72.sp,
                  color: kAccentYellow,
                  colorBlendMode: BlendMode.srcIn,
                ),
                value: themeName,
                onTap: _showThemeSelector,
              ),
              SettingsRowTile(
                label: 'Mail',
                value: _user?.email ?? '',
                onTap: _openChangeEmailModal,
              ),
              SettingsRowTile(
                label: 'Mot de passe',
                value: '••••••',
                onTap: _openChangePasswordModal,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.section),
          SettingsSection(
            title: 'B12',
            children: [
              SettingsToggleTile(
                title: 'Rappels',
                subtitle: _b12NextReminderLabel,
                value: _b12RemindersEnabled,
                onChanged: _toggleB12Reminders,
                onTap: _openB12Settings,
              ),
              SettingsRowTile(
                label: 'Historique B12',
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 32.sp, color: Colors.grey[400]),
                onTap: _openB12History,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.section),
          SettingsSection(
            title: 'Produits',
            children: [
              SettingsRowTile(
                label: 'Scannés',
                value: '${_user?.scanCount ?? 0}',
                onTap: () async {
                  final history = await PreferencesHelper.getScanHistory();
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScanHistoryPage(scanHistory: history),
                    ),
                  );
                },
              ),
              SettingsRowTile(
                label: 'Envoyés',
                value: '${_user?.nbProductsSent ?? 0}',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SentProductsPage()),
                ),
              ),
              SettingsRowTile(
                label: 'Signalements',
                value: '${_user?.nbErrorReports ?? 0}',
                trailing: _unreadErrorResponses > 0
                    ? Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 4.h),
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        child: Text(
                          '$_unreadErrorResponses',
                          style:
                              TextStyle(color: Colors.white, fontSize: 24.sp),
                        ),
                      )
                    : null,
                onTap: _openErrorReports,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.section),
          SettingsSection(
            title: 'Scan',
            children: [
              SettingsToggleTile(
                title: 'Mentions "Boycott"',
                value: _showBoycott,
                onChanged: (value) async {
                  await PreferencesHelper.setShowBoycottPref(value);
                  if (mounted) setState(() => _showBoycott = value);
                },
              ),
              SettingsToggleTile(
                title: '"NutriScore" et "GreenScore"',
                value: _showScores,
                onChanged: (value) async {
                  await PreferencesHelper.setShowScoresPref(value);
                  if (mounted) setState(() => _showScores = value);
                },
              ),
              SettingsToggleTile(
                title: 'Vibrer lors d\'un scan produit',
                value: _hapticFeedback,
                onChanged: (value) async {
                  await PreferencesHelper.setHapticFeedbackPref(value);
                  if (mounted) setState(() => _hapticFeedback = value);
                },
              ),
            ],
          ),
          SizedBox(height: AppSpacing.section),
          AppButton(
            label: 'Se déconnecter',
            backgroundColor: Theme.of(context).colorScheme.primary,
            onPressed: _handleLogout,
          ),
          SizedBox(height: 16.h),
          AppButton(
            label: 'Supprimer mon compte',
            backgroundColor: kAccentYellow,
            onPressed: _handleDeleteAccount,
          ),
        ],
      ),
    );
  }

  /// Green banner matching the Figma "Passez Premium !" card, with a yellow
  /// call-to-action while not subscribed and the pineapple illustration.
  Widget _buildPremiumBanner(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isSubscribed = SubscriptionService.isSubscribed;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SubscriptionPage()),
      ).then((_) {
        if (mounted) setState(() {});
      }),
      child: ShineWrapper(
        borderRadius: 24,
        child: Container(
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              colors: [primary, primary.withAlpha(190)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: squircleBorder(radius: 20),
            shadows: [
              BoxShadow(
                color: primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.all(24.w),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            isSubscribed
                                ? 'Abonnement actif'
                                : 'Passez Premium !',
                            style: AppTextStyles.baloo26.copyWith(color: Colors.white),
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Image.asset(
                          'lib/assets/images/icons/crown-line.webp',
                          width: 72.sp,
                          height: 72.sp,
                          color: kAccentYellow,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      isSubscribed
                          ? 'Merci de soutenir 321Vegan !'
                          : 'Accédez à des fonctionnalités tout en soutenant 321Vegan.',
                      style: TextStyle(
                        fontSize: 42.sp,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    if (!isSubscribed) ...[
                      SizedBox(height: 16.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 24.w, vertical: 10.h),
                        decoration: ShapeDecoration(
                          color: kAccentYellow,
                          shape: squircleBorder(radius: 30),
                        ),
                        child: Text(
                          'Découvrir les offres',
                          style: TextStyle(
                            fontSize: 42.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 20.w),
              SizedBox(
                width: 210.w,
                height: 260.w,
                child: Image.asset(
                  'lib/assets/images/buy-premium/pineapple.webp',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
