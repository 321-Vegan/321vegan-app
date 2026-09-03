import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/auth_service.dart';
import '../../models/auth.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/app_text_field.dart';

/// Same check the email field's validator uses, so the submit-button gate
/// and the inline error agree.
final RegExp _kEmailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

class LoginForm extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onSwitchToRegister;
  final VoidCallback? onSwitchToForgotPassword;

  const LoginForm({
    super.key,
    this.onLoginSuccess,
    this.onSwitchToRegister,
    this.onSwitchToForgotPassword,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  /// Every required field has a value and the email looks valid — gates the
  /// submit button.
  bool get _canSubmit =>
      _kEmailRegExp.hasMatch(_emailController.text.trim()) &&
      _passwordController.text.isNotEmpty;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final request = LoginRequest(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    final result = await AuthService.login(request);

    if (mounted) {
      setState(() => _isLoading = false);

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
            content: Text('Connexion réussie !'),
            backgroundColor: kSemanticSuccess,
          ),
        );
        widget.onLoginSuccess?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Erreur de connexion'),
            backgroundColor: kSemanticError,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Connexion', style: AppTextStyles.baloo26),
          SizedBox(height: 32.h),

          // Email field
          AppTextField(
            controller: _emailController,
            hintText: 'Email',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer votre email';
              }
              if (!_kEmailRegExp.hasMatch(value)) {
                return 'Veuillez entrer un email valide';
              }
              return null;
            },
          ),
          SizedBox(height: 16.h),

          // Password field
          AppTextField(
            controller: _passwordController,
            hintText: 'Mot de passe',
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey[500],
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer votre mot de passe';
              }
              return null;
            },
          ),
          SizedBox(height: 8.h),

          // Forgot password link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onSwitchToForgotPassword,
              child: Text(
                'Mot de passe oublié ?',
                style: TextStyle(
                  fontSize: 40.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          SizedBox(height: 24.h),

          // Login button
          AppButton(
            label: 'Se connecter',
            backgroundColor: Theme.of(context).colorScheme.primary,
            isLoading: _isLoading,
            onPressed: _canSubmit ? _handleLogin : null,
          ),
          SizedBox(height: 24.h),

          // Switch to register
          Center(
            child: TextButton(
              onPressed: widget.onSwitchToRegister,
              child: Text(
                'Je n\'ai pas de compte',
                style: TextStyle(
                  fontSize: 40.sp,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
