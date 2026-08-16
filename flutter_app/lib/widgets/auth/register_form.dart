import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../models/auth.dart';
import '../../helpers/preference_helper.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/vegan_since_date_modal.dart';
import 'auth_styles.dart';

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
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _veganSinceController.dispose();
    super.dispose();
  }

  // Carries over a vegan-since date already picked as a guest (e.g. from
  // the Dashboard counter) so it isn't lost when creating an account.
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

    // Retrieve products sent from local storage; vegan-since comes from
    // the form field above (pre-filled from local storage if already set).
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
      // Default values for role and isActive are set in the model
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
          // Registration succeeded but login failed
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
            Text(
              'Créer un compte',
              style: AppTextStyles.baloo22,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
          ],

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
          SizedBox(height: 24.h),

          // Nickname field
          TextFormField(
            controller: _nicknameController,
            autofillHints: const [AutofillHints.username],
            decoration: authFieldDecoration(
              context,
              label: 'Nom d\'utilisateur',
              hint: 'Votre pseudo',
              icon: Icons.person_outlined,
            ),
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
          TextFormField(
            controller: _veganSinceController,
            readOnly: true,
            onTap: _pickVeganSince,
            decoration: authFieldDecoration(
              context,
              label: 'Végane depuis (facultatif)',
              hint: 'Je ne suis pas encore végane',
              icon: Icons.eco_outlined,
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
          ),
          SizedBox(height: 24.h),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.newPassword],
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
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            autofillHints: const [AutofillHints.newPassword],
            decoration: authFieldDecoration(
              context,
              label: 'Confirmer le mot de passe',
              icon: Icons.lock_outlined,
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
            label: 'S\'inscrire',
            backgroundColor: Theme.of(context).colorScheme.primary,
            isLoading: _isLoading,
            onPressed: _handleRegister,
          ),
          SizedBox(height: 24.h),

          // Switch to login
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Déjà un compte ? ',
                style: TextStyle(
                  fontSize: 40.sp,
                  color: Colors.grey[600],
                ),
              ),
              TextButton(
                onPressed: widget.onSwitchToLogin,
                child: Text(
                  'Se connecter',
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
