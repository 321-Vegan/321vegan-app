import 'dart:ui';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/pages/app_pages/Profile/subscription_page.dart';
import 'package:vegan_app/services/auth_service.dart';
import 'package:vegan_app/services/subscription_service.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/widgets/auth/forgot_password_form.dart';
import 'package:vegan_app/widgets/auth/login_form.dart';
import 'package:vegan_app/widgets/auth/register_form.dart';

class MapAccessOverlay extends StatefulWidget {
  final VoidCallback onAccessGranted;
  final VoidCallback? onLoginSuccess;

  /// Called when the user starts their one-time free trial of the map.
  final VoidCallback? onFreeTrial;

  const MapAccessOverlay(
      {super.key,
      required this.onAccessGranted,
      this.onLoginSuccess,
      this.onFreeTrial});

  @override
  State<MapAccessOverlay> createState() => _MapAccessOverlayState();
}

class _MapAccessOverlayState extends State<MapAccessOverlay> {
  bool _trialAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadTrialAvailability();
  }

  Future<void> _loadTrialAvailability() async {
    final used = await PreferencesHelper.hasUsedMapFreeTrial();
    if (mounted) setState(() => _trialAvailable = !used);
  }

  Future<void> _startFreeTrial() async {
    await PreferencesHelper.markMapFreeTrialUsed();
    widget.onFreeTrial?.call();
  }

  void _showAuthSheet({required bool showRegister}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (context, scrollController) => ClipSmoothRect(
          radius: SmoothBorderRadius.only(
            topLeft: SmoothRadius(cornerRadius: 28.r, cornerSmoothing: kCornerSmoothing),
            topRight: SmoothRadius(cornerRadius: 28.r, cornerSmoothing: kCornerSmoothing),
          ),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.all(28.w),
              child: _AuthSheetContent(
                initialShowRegister: showRegister,
                onSuccess: () {
                  Navigator.of(context).pop();
                  widget.onLoginSuccess?.call();
                  if (SubscriptionService.isSubscribed) {
                    widget.onAccessGranted();
                  } else if (mounted) {
                    setState(() {});
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openSubscriptionPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SubscriptionPage()),
    ).then((_) {
      if (SubscriptionService.isSubscribed && mounted) {
        widget.onAccessGranted();
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLoggedIn = AuthService.isLoggedIn;

    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: Colors.white.withValues(alpha: 0.6),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(24.w),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: 120.sp,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Text(
                         'Trouvez les produits vegan près de vous',
                        style: TextStyle(
                          fontSize: 52.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        isLoggedIn
                            ? 'Localisez les produits vegan autour de vous. En accès anticipé pour les abonné·es, et vous soutenez le projet !'
                            : 'Créez un compte pour débloquer la carte et localiser les produits vegan autour de vous.',
                        style: TextStyle(
                          fontSize: 40.sp,
                          color: Colors.grey[500],
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 32.h),
                      if (isLoggedIn) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _openSubscriptionPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 20.h),
                              shape: squircleBorder(radius: 16.r),
                              elevation: 0,
                            ),
                            child: Text(
                              'Soutenir et débloquer',
                              style: TextStyle(
                                fontSize: 46.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (_trialAvailable) ...[
                          SizedBox(height: 12.h),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _startFreeTrial,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side:
                                    BorderSide(color: primaryColor, width: 1.5),
                                padding: EdgeInsets.symmetric(vertical: 20.h),
                                shape: squircleBorder(radius: 16.r),
                              ),
                              child: Text(
                                'Tester gratuitement pendant 6h',
                                style: TextStyle(
                                  fontSize: 46.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _showAuthSheet(showRegister: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 20.h),
                              shape: squircleBorder(radius: 16.r),
                              elevation: 0,
                            ),
                            child: Text(
                              'Créer un compte',
                              style: TextStyle(
                                fontSize: 46.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () =>
                                _showAuthSheet(showRegister: false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(color: primaryColor, width: 1.5),
                              padding: EdgeInsets.symmetric(vertical: 20.h),
                              shape: squircleBorder(radius: 16.r),
                            ),
                            child: Text(
                              'Se connecter',
                              style: TextStyle(
                                fontSize: 46.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _AuthView { register, login, forgotPassword }

class _AuthSheetContent extends StatefulWidget {
  final bool initialShowRegister;
  final VoidCallback onSuccess;

  const _AuthSheetContent({
    required this.initialShowRegister,
    required this.onSuccess,
  });

  @override
  State<_AuthSheetContent> createState() => _AuthSheetContentState();
}

class _AuthSheetContentState extends State<_AuthSheetContent> {
  late _AuthView _view;

  @override
  void initState() {
    super.initState();
    _view = widget.initialShowRegister ? _AuthView.register : _AuthView.login;
  }

  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case _AuthView.register:
        return RegisterForm(
          onRegisterSuccess: widget.onSuccess,
          onSwitchToLogin: () => setState(() => _view = _AuthView.login),
        );
      case _AuthView.login:
        return LoginForm(
          onLoginSuccess: widget.onSuccess,
          onSwitchToRegister: () => setState(() => _view = _AuthView.register),
          onSwitchToForgotPassword: () =>
              setState(() => _view = _AuthView.forgotPassword),
        );
      case _AuthView.forgotPassword:
        return ForgotPasswordForm(
          onBackToLogin: () => setState(() => _view = _AuthView.login),
        );
    }
  }
}
