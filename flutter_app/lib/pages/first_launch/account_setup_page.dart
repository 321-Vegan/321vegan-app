import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../../widgets/auth/forgot_password_form.dart';
import '../../widgets/auth/login_form.dart';
import '../../widgets/auth/register_form.dart';
import '../../widgets/shared/app_button.dart';
import '../../widgets/shared/app_card.dart';
import '../app_pages/home.dart';

enum _AuthView { login, register, forgotPassword }

/// Second and last first-launch screen: login/register/forgot-password on
/// the same dark-green gradient as [OnboardingPage], plus a "Continuer sans
/// compte" skip.
///
/// Reuses the [LoginForm]/[RegisterForm]/[ForgotPasswordForm] widgets that
/// back Settings' auth gate, but not `AuthGatePage` itself — its colored
/// "Rejoignez la communauté" pitch banner duplicates the pitch already made
/// on the previous onboarding screen, and it's laid out for the Settings
/// page's cream background rather than this screen's dark gradient.
class AccountSetupPage extends StatefulWidget {
  const AccountSetupPage({super.key});

  @override
  State<AccountSetupPage> createState() => _AccountSetupPageState();
}

class _AccountSetupPageState extends State<AccountSetupPage> {
  _AuthView _currentView = _AuthView.register;

  @override
  void initState() {
    super.initState();
    // Guard against a cached session from a previous install/test on the
    // same device — onboarding can't assume it's only ever shown logged-out
    // the way the Settings auth gate can.
    if (AuthService.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _finishOnboarding(context);
      });
    }
  }

  Future<void> _finishOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MyHomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService.isLoggedIn) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kOnboardingGradientTop, kOnboardingGradientBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            'lib/assets/images/characters/lemon-vgn.webp',
                            height: 300.h,
                          ),
                          SizedBox(width: 24.w),
                          Expanded(
                            child: Text(
                              "Un compte vous permet de profiter pleinement "
                              "de l'application : rappel B12, collection de "
                              "produits scannés, avatar personnalisé...",
                              style: AppTextStyles.bodyRegular15.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.section),
                      AppCard(child: _buildCurrentView()),
                      SizedBox(height: AppSpacing.item),
                      AppButton(
                        label: "Continuer sans compte",
                        backgroundColor: kAccentYellow,
                        onPressed: () => _finishOnboarding(context),
                      ),
                      SizedBox(height: AppSpacing.item),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case _AuthView.login:
        return LoginForm(
          onLoginSuccess: () => _finishOnboarding(context),
          onSwitchToRegister: () =>
              setState(() => _currentView = _AuthView.register),
          onSwitchToForgotPassword: () =>
              setState(() => _currentView = _AuthView.forgotPassword),
        );
      case _AuthView.register:
        return RegisterForm(
          onRegisterSuccess: () => _finishOnboarding(context),
          onSwitchToLogin: () =>
              setState(() => _currentView = _AuthView.login),
        );
      case _AuthView.forgotPassword:
        return ForgotPasswordForm(
          onBackToLogin: () =>
              setState(() => _currentView = _AuthView.login),
        );
    }
  }
}
