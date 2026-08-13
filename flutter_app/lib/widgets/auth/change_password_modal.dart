import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/auth_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/app_text_field.dart';
import '../shared/bottom_sheet_shell.dart';
import '../shared/form_error_banner.dart';

class ChangePasswordModal extends StatefulWidget {
  final VoidCallback? onPasswordChanged;

  const ChangePasswordModal({
    super.key,
    this.onPasswordChanged,
  });

  @override
  State<ChangePasswordModal> createState() => _ChangePasswordModalState();
}

class _ChangePasswordModalState extends State<ChangePasswordModal> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty) {
      setState(() => _errorMessage = 'Veuillez entrer votre mot de passe actuel');
      return;
    }
    if (newPassword.length < 8) {
      setState(() => _errorMessage =
          'Le nouveau mot de passe doit contenir au moins 8 caractères');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'Les mots de passe ne correspondent pas');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() => _isLoading = false);
      widget.onPasswordChanged?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.data ?? 'Mot de passe mis à jour avec succès.'),
          backgroundColor: kSemanticSuccess,
        ),
      );
    } else {
      // Kept on-screen (not a SnackBar): the sheet stays open so the user
      // can retry, and a page-level SnackBar would render behind it.
      setState(() {
        _isLoading = false;
        _errorMessage = result.error ?? 'Une erreur est survenue.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: BottomSheetShell(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Modifier votre mot de passe',
                      style: AppTextStyles.baloo22),
                  IconButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    iconSize: 64.sp,
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                'Renseignez votre mot de passe actuel puis choisissez-en un nouveau.',
                style: TextStyle(
                  fontSize: 42.sp,
                  color: Colors.grey[600],
                  height: 1.3,
                ),
              ),
              SizedBox(height: 48.h),
              AppTextField(
                controller: _currentPasswordController,
                hintText: 'Mot de passe actuel',
                enabled: !_isLoading,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
              ),
              SizedBox(height: 24.h),
              AppTextField(
                controller: _newPasswordController,
                hintText: 'Nouveau mot de passe',
                enabled: !_isLoading,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
              ),
              SizedBox(height: 24.h),
              AppTextField(
                controller: _confirmPasswordController,
                hintText: 'Confirmer le nouveau mot de passe',
                enabled: !_isLoading,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
              ),
              if (_errorMessage != null) ...[
                SizedBox(height: 24.h),
                FormErrorBanner(message: _errorMessage!),
              ],
              SizedBox(height: 32.h),
              AppButton(
                label: 'Modifier le mot de passe',
                backgroundColor: Theme.of(context).colorScheme.primary,
                isLoading: _isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
