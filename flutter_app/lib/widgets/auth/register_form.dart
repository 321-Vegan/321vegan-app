import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../models/auth.dart';
import '../../helpers/preference_helper.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/app_text_field.dart';
import '../shared/vegan_since_date_modal.dart';

/// Same check the email field's validator uses, so the submit-button gate
/// and the inline error agree.
final RegExp _kEmailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

class RegisterForm extends StatefulWidget {
  final VoidCallback? onRegisterSuccess;
  final VoidCallback? onSwitchToLogin;
  final bool showTitle;

  const RegisterForm({
    super.key,
    this.onRegisterSuccess,
    this.onSwitchToLogin,
    this.showTitle = true,
  });

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _veganSinceController = TextEditingController();
  DateTime? _veganSince;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _loadVeganSince();
    for (final c in [
      _emailController,
      _nicknameController,
      _passwordController,
      _confirmPasswordController,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() => setState(() {});

  /// Every required field has a value and the email looks valid (Végane
  /// depuis is optional) — gates the submit button.
  bool get _canSubmit =>
      _kEmailRegExp.hasMatch(_emailController.text.trim()) &&
      _nicknameController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _confirmPasswordController.text.isNotEmpty;

  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _veganSinceController.dispose();
    super.dispose();
  }

  // Carries over a vegan-since date picked as a guest so it isn't lost on signup.
  Future<void> _loadVeganSince() async {
    final date = await PreferencesHelper.getSelectedDateFromPrefs();
    if (!mounted || date == null) return;
    setState(() {
      _veganSince = date;
      _veganSinceController.text = DateFormat.yMMMd('fr_FR').format(date);
    });
  }

  Future<void> _pickVeganSince() async {
    final result = await showModalBottomSheet<VeganDateResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VeganSinceDateModal(initialDate: _veganSince),
    );
    if (result == null) return;

    setState(() {
      if (result.action == VeganDateAction.delete) {
        _veganSince = null;
        _veganSinceController.clear();
      } else {
        _veganSince = result.date;
        _veganSinceController.text =
            DateFormat.yMMMd('fr_FR').format(result.date!);
      }
    });
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final nbProductsSent =
        await PreferencesHelper.getTotalSuccessfulSubmissions();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final request = RegisterRequest(
      email: email,
      nickname: _nicknameController.text.trim(),
      password: password,
      veganSince: _veganSince,
      nbProductsSent: nbProductsSent,
    );

    final result = await AuthService.register(request);

    if (mounted) {
      if (result.isSuccess) {
        // Automatically log in the user after successful registration
        final loginRequest = LoginRequest(
          email: email,
          password: password,
        );
        final loginResult = await AuthService.login(loginRequest);

        if (!mounted) return;
        setState(() => _isLoading = false);

        if (loginResult.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compte créé et connecté avec succès !'),
              backgroundColor: kSemanticSuccess,
            ),
          );
          widget.onRegisterSuccess?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compte créé ! Vous pouvez vous connecter.'),
              backgroundColor: kSemanticSuccess,
            ),
          );
          widget.onRegisterSuccess?.call();
        }
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Erreur lors de l\'inscription'),
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
          if (widget.showTitle) ...[
            Text('S\'inscrire', style: AppTextStyles.baloo26),
            SizedBox(height: 32.h),
          ],

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
          SizedBox(height: 24.h),

          // Nickname field
          AppTextField(
            controller: _nicknameController,
            hintText: 'Nom d\'utilisateur',
            autofillHints: const [AutofillHints.username],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer un nom d\'utilisateur';
              }
              if (value.length < 3) {
                return 'Le nom d\'utilisateur doit contenir au moins 3 caractères';
              }
              return null;
            },
          ),
          SizedBox(height: 24.h),

          // Vegan since field (optional)
          AppTextField(
            controller: _veganSinceController,
            hintText: 'Végane depuis (facultatif)',
            readOnly: true,
            onTap: _pickVeganSince,
            suffixIcon: _veganSince != null
                ? IconButton(
                    icon: Icon(Icons.close,
                        size: 40.sp, color: Colors.grey[500]),
                    onPressed: () => setState(() {
                      _veganSince = null;
                      _veganSinceController.clear();
                    }),
                  )
                : Icon(Icons.chevron_right,
                    size: 44.sp, color: Colors.grey[400]),
          ),
          SizedBox(height: 24.h),

          // Password field
          AppTextField(
            controller: _passwordController,
            hintText: 'Mot de passe',
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.newPassword],
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
                return 'Veuillez entrer un mot de passe';
              }
              if (value.length < 8) {
                return 'Le mot de passe doit contenir au moins 8 caractères';
              }
              return null;
            },
          ),
          SizedBox(height: 24.h),

          // Confirm password field
          AppTextField(
            controller: _confirmPasswordController,
            hintText: 'Confirmer le mot de passe',
            obscureText: _obscureConfirmPassword,
            autofillHints: const [AutofillHints.newPassword],
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: Colors.grey[500],
              ),
              onPressed: () {
                setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword);
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez confirmer votre mot de passe';
              }
              if (value != _passwordController.text) {
                return 'Les mots de passe ne correspondent pas';
              }
              return null;
            },
          ),
          SizedBox(height: 32.h),

          // Register button
          AppButton(
            label: 'C\'est parti !',
            backgroundColor: Theme.of(context).colorScheme.primary,
            isLoading: _isLoading,
            onPressed: _canSubmit ? _handleRegister : null,
          ),
          SizedBox(height: 24.h),

          // Switch to login
          Center(
            child: TextButton(
              onPressed: widget.onSwitchToLogin,
              child: Text(
                'J\'ai déjà un compte',
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
