import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../services/auth_service.dart';
import '../../../themes/app_spacing.dart';
import '../../../widgets/auth/auth_hero_carousel.dart';
import '../../../widgets/auth/login_form.dart';
import '../../../widgets/auth/register_form.dart';
import '../../../widgets/auth/forgot_password_form.dart';

enum AuthView { login, register, forgotPassword }

/// Login/register/forgot-password gate shown in [SettingsPage] for
/// logged-out users. Once a login or registration succeeds,
/// [onLoginSuccess] fires and the parent swaps this page out for the
/// logged-in settings view — this widget never renders an authenticated
/// state itself.
class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key, this.onLoginSuccess});

  final VoidCallback? onLoginSuccess;

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  AuthView _currentView = AuthView.register;

  void _switchToRegister() => setState(() => _currentView = AuthView.register);
  void _switchToLogin() => setState(() => _currentView = AuthView.login);
  void _switchToForgotPassword() =>
      setState(() => _currentView = AuthView.forgotPassword);

  void _onAuthSuccess() => widget.onLoginSuccess?.call();

  @override
  Widget build(BuildContext context) {
    // The parent unmounts this page as soon as it's notified of a
    // successful login; nothing to render for the in-between frame.
    if (AuthService.isLoggedIn) return const SizedBox.shrink();

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
            top: 16.h,
            left: AppSpacing.pageHorizontal,
            right: AppSpacing.pageHorizontal,
            bottom: 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 24.h),
            Center(
              child: Image.asset('lib/assets/app_icon.png', height: 160.h),
            ),
            SizedBox(height: 24.h),
            const AuthHeroCarousel(),
            SizedBox(height: AppSpacing.section),
            _buildCurrentView(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case AuthView.login:
        return LoginForm(
          onLoginSuccess: _onAuthSuccess,
          onSwitchToRegister: _switchToRegister,
          onSwitchToForgotPassword: _switchToForgotPassword,
        );
      case AuthView.register:
        return RegisterForm(
          onRegisterSuccess: _onAuthSuccess,
          onSwitchToLogin: _switchToLogin,
        );
      case AuthView.forgotPassword:
        return ForgotPasswordForm(onBackToLogin: _switchToLogin);
    }
  }
}
