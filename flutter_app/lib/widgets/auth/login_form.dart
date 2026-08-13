import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/auth_service.dart';
import '../../models/auth.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import 'auth_styles.dart';

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
          Text(
            'Connexion',
            style: AppTextStyles.baloo22,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32.h),

          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: authFieldDecoration(
              context,
              label: 'Email',
              hint: 'votre@email.com',
              icon: Icons.email_outlined,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer votre email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(value)) {
                return 'Veuillez entrer un email valide';
              }
              return null;
            },
          ),
          SizedBox(height: 16.h),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            decoration: authFieldDecoration(
              context,
              label: 'Mot de passe',
              icon: Icons.lock_outlined,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey[500],
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
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
          ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: authPrimaryButtonStyle(context),
            child: _isLoading
                ? SizedBox(
                    height: 20.h,
                    width: 20.h,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text('Se connecter', style: authButtonTextStyle()),
          ),
          SizedBox(height: 24.h),

          // Switch to register
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Pas encore de compte ? ',
                style: TextStyle(
                  fontSize: 40.sp,
                  color: Colors.grey[600],
                ),
              ),
              TextButton(
                onPressed: widget.onSwitchToRegister,
                child: Text(
                  'S\'inscrire',
                  style: TextStyle(
                    fontSize: 40.sp,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          ],
        ),
      ),
    );
  }
}
