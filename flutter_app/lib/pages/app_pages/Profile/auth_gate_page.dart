import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../services/auth_service.dart';
import '../../../themes/app_shapes.dart';
import '../../../themes/app_spacing.dart';
import '../../../widgets/auth/login_form.dart';
import '../../../widgets/auth/register_form.dart';
import '../../../widgets/auth/forgot_password_form.dart';
import '../../../widgets/shared/app_card.dart';

/// Reasons to sign up, shown on the coloured header card — mirrors the
/// checklist on [SubscriptionPage]'s "Passez Premium !" pitch, kept to
/// benefits an account unlocks by itself (not the paid tiers).
const _accountBenefits = [
  'Configurer un rappel B12',
  'Collectionner des produits en les scannant',
  'Choisir un avatar',
];

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

    final primary = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: SingleChildScrollView(
        padding:
            EdgeInsets.only(top: 16.h, left: 24.w, right: 24.w, bottom: 20.h),
        child: Column(
          children: [
            _buildHeader(primary),
            SizedBox(height: AppSpacing.section),
            AppCard(child: _buildCurrentView()),
          ],
        ),
      ),
    );
  }

  /// Coloured pitch card echoing [SubscriptionPage]'s "Passez Premium !"
  /// header — bold white title over a benefits checklist — scaled down for
  /// an inline settings section rather than a full-screen takeover.
  Widget _buildHeader(Color primary) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(28.w),
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withAlpha(190)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: squircleBorder(radius: 40.r),
        shadows: [
          BoxShadow(
            color: primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'lib/assets/images/buy-premium/tree.webp',
                fit: BoxFit.contain,
                height: 220.h,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.eco, size: 160.sp, color: Colors.white);
                },
              ),
              SizedBox(width: 20.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rejoignez la communauté !',
                      style: TextStyle(
                        fontSize: 64.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Baloo2',
                        height: 1.1,
                        letterSpacing: -1,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Connectez-vous ou créez un compte pour profiter de toutes les fonctionnalités :',
                      style: TextStyle(
                        fontSize: 38.sp,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          for (final benefit in _accountBenefits)
            Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Row(
                children: [
                  Container(
                    width: 56.w,
                    height: 56.w,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, size: 36.sp, color: primary),
                  ),
                  SizedBox(width: 20.w),
                  Expanded(
                    child: Text(
                      benefit,
                      style: TextStyle(
                        fontSize: 38.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
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
