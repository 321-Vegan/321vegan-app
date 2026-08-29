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

/// 4th page of the [OnboardingPage] carousel: login/register/forgot-password
/// plus a "Continuer sans compte" skip. Embedded directly as a [PageView]
/// item (not pushed as its own route) so swiping back works the same as
/// between slides, with no separate back button needed.
///
/// Reuses [LoginForm]/[RegisterForm]/[ForgotPasswordForm] but not
/// `AuthGatePage` itself — its pitch banner and Settings-page layout
/// wouldn't fit a carousel page.
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
    // Guard against a cached session from a previous install/test — unlike
    // the Settings auth gate, onboarding can't assume it's always logged-out.
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
      return const SizedBox.shrink();
    }
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 24.h),
              Center(
                child: Image.asset('lib/assets/app_icon.png', width: 160.w),
              ),
              SizedBox(height: 36.h),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppTextStyles.baloo36,
                    children: const [
                      TextSpan(text: 'Rejoignez la '),
                      TextSpan(text: 'communauté', style: TextStyle(color: kAccentYellow)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                "Un compte vous permet de profiter pleinement de "
                "l'application : rappel B12, collection de produits "
                "scannés, avatar personnalisé...",
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyRegular15.copyWith(
                  color: Colors.grey[600],
                  height: 1.4,
                ),
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
