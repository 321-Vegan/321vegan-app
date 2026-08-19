import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/widgets/auth/forgot_password_form.dart';
import 'package:vegan_app/widgets/auth/login_form.dart';
import 'package:vegan_app/widgets/auth/register_form.dart';

/// Shows the login/register bottom sheet shared by every "you need an
/// account for this" prompt (scan submissions, map access, ...). Pops
/// itself and calls [onSuccess] once login or registration succeeds.
Future<void> showAuthBottomSheet(
  BuildContext context, {
  required VoidCallback onSuccess,
  bool initialShowRegister = true,
  double initialChildSize = 0.85,
  double minChildSize = 0.5,
  double maxChildSize = 0.95,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      builder: (context, scrollController) => ClipSmoothRect(
        radius: squircleRadius(28.r),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              SizedBox(height: 12.h),
              Container(
                width: 70.w,
                height: 8.h,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(3.r),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(28.w),
                  child: _AuthSheetContent(
                    initialShowRegister: initialShowRegister,
                    onSuccess: () {
                      Navigator.of(context).pop();
                      onSuccess();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
