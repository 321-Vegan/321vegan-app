import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/auth/login_form.dart';
import '../../../widgets/auth/register_form.dart';
import '../../../widgets/auth/forgot_password_form.dart';
import '../../../widgets/shared/app_card.dart';
import '../../../widgets/shared/social_feedback_buttons.dart';

enum AuthView { login, register, forgotPassword }

/// Login/register/forgot-password gate shown in [SettingsPage] for
/// logged-out users. Once a login or registration succeeds,
/// [onLoginSuccess] fires and the parent swaps this page out for the
/// logged-in settings view — this widget never renders an authenticated
/// state itself.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key, this.onLoginSuccess});

  final VoidCallback? onLoginSuccess;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
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
        padding:
            EdgeInsets.only(top: 16.h, left: 24.w, right: 24.w, bottom: 20.h),
        child: Column(
          children: [
            _buildHeader(),
            AppCard(child: _buildCurrentView()),
            SizedBox(height: 32.h),
            const SocialFeedbackButtons(showCard: false),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppCard(
      child: Column(
        children: [
          Image.asset(
            'lib/assets/app_icon.png',
            fit: BoxFit.contain,
            height: 150.h,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.account_circle,
                size: 150.sp,
                color: Colors.grey,
              );
            },
          ),
          SizedBox(height: 16.h),
          Text(
            '321 Vegan',
            style: TextStyle(
              fontSize: 60.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Connectez-vous ou créez votre compte',
            style: TextStyle(
              fontSize: 44.sp,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
