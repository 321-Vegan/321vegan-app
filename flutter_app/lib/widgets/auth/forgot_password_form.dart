import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/auth_service.dart';
import '../../models/auth.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import 'auth_styles.dart';

class ForgotPasswordForm extends StatefulWidget {
  final VoidCallback? onBackToLogin;

  const ForgotPasswordForm({
    super.key,
    this.onBackToLogin,
  });

  @override
  State<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<ForgotPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final request = PasswordResetRequest(
      email: _emailController.text.trim(),
    );

    final result = await AuthService.requestPasswordReset(request);

    if (mounted) {
      setState(() => _isLoading = false);

      if (result.isSuccess) {
        setState(() => _emailSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Email de réinitialisation envoyé !'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Erreur lors de l\'envoi'),
            backgroundColor: Colors.red,
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
            'Mot de passe oublié',
            style: AppTextStyles.baloo22,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),

          if (!_emailSent) ...[
            Text(
              'Entrez votre adresse email pour recevoir un lien de réinitialisation.',
              style: TextStyle(
                fontSize: 42.sp,
                color: Colors.grey[600],
                height: 1.4,
              ),
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
            SizedBox(height: 32.h),

            // Send reset email button
            ElevatedButton(
              onPressed: _isLoading ? null : _handlePasswordReset,
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
                  : Text('Envoyer le lien', style: authButtonTextStyle()),
            ),
          ] else ...[
            // Success message
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: ShapeDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                shape: squircleBorder(
                  radius: 24.r,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.mark_email_read,
                    size: 64.sp,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Email envoyé !',
                    style: TextStyle(
                      fontSize: 52.sp,
                      fontWeight: FontWeight.bold,
                      color: kTextPrimary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Vérifiez votre boîte email et suivez les instructions pour réinitialiser votre mot de passe.',
                    style: TextStyle(
                      fontSize: 42.sp,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
          ],

          // Back to login button
          TextButton(
            onPressed: widget.onBackToLogin,
            child: Text(
              'Retour à la connexion',
              style: TextStyle(
                fontSize: 44.sp,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
