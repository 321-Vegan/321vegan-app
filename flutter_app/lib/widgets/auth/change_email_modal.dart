import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/auth_service.dart';
import '../../helpers/preference_helper.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/app_text_field.dart';
import '../shared/bottom_sheet_shell.dart';
import '../shared/form_error_banner.dart';

class ChangeEmailModal extends StatefulWidget {
  final String currentEmail;
  final VoidCallback? onChangeRequested;

  const ChangeEmailModal({
    super.key,
    required this.currentEmail,
    this.onChangeRequested,
  });

  @override
  State<ChangeEmailModal> createState() => _ChangeEmailModalState();
}

class _ChangeEmailModalState extends State<ChangeEmailModal> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _pendingEmail;

  @override
  void initState() {
    super.initState();
    _loadPendingEmail();
    _emailController.addListener(_handleInputChanged);
    _passwordController.addListener(_handleInputChanged);
  }

  void _handleInputChanged() => setState(() {});

  bool get _canSubmit =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  Future<void> _loadPendingEmail() async {
    final pending = await PreferencesHelper.getPendingEmailChange();
    // If the backend email already matches the pending one, the change was
    // confirmed (on the web) — clear it and drop the badge.
    if (pending != null && pending == widget.currentEmail) {
      await PreferencesHelper.clearPendingEmailChange();
    }
    if (mounted) {
      setState(() {
        _pendingEmail =
            (pending != null && pending != widget.currentEmail) ? pending : null;
      });
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleInputChanged);
    _passwordController.removeListener(_handleInputChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newEmail = _emailController.text.trim();
    final password = _passwordController.text;

    if (newEmail.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(newEmail)) {
      setState(() => _errorMessage = 'Veuillez entrer un email valide');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Veuillez entrer votre mot de passe');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.requestEmailChange(
      newEmail: newEmail,
      currentPassword: password,
    );

    if (result.isSuccess) {
      await PreferencesHelper.savePendingEmailChange(newEmail);
    }

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _isLoading = false;
        _pendingEmail = newEmail;
      });
      widget.onChangeRequested?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.data ??
              'Un email de confirmation a été envoyé à votre nouvelle adresse.'),
          backgroundColor: kSemanticSuccess,
          duration: const Duration(seconds: 6),
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
                  Text('Modifier votre email', style: AppTextStyles.baloo22),
                ],
              ),
              Text(
                'Email actuel : ${widget.currentEmail}',
                style: TextStyle(fontSize: 42.sp, color: Colors.grey[600]),
              ),
              if (_pendingEmail != null) ...[
                SizedBox(height: 4.h),
                Text(
                  'Email en attente : $_pendingEmail',
                  style: TextStyle(
                    fontSize: 42.sp,
                    fontWeight: FontWeight.w600,
                    color: kAccentYellow,
                  ),
                ),
              ],
              SizedBox(height: 48.h),
              AppTextField(
                controller: _emailController,
                hintText: 'Nouvel email',
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              SizedBox(height: 24.h),
              AppTextField(
                controller: _passwordController,
                hintText: 'Mot de passe',
                enabled: !_isLoading,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
              ),
              if (_errorMessage != null) ...[
                SizedBox(height: 24.h),
                FormErrorBanner(message: _errorMessage!),
              ],
              SizedBox(height: 32.h),
              AppButton(
                label: 'Envoyer le lien de confirmation',
                backgroundColor: Theme.of(context).colorScheme.primary,
                isLoading: _isLoading,
                onPressed: _canSubmit ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
