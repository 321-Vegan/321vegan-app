import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/user.dart';
import '../../pages/app_pages/Profile/subscription_page.dart';
import '../../services/auth_service.dart';
import '../../services/subscription_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/app_text_field.dart';
import '../shared/bottom_sheet_shell.dart';
import '../shared/form_error_banner.dart';
import '../shared/premium_badge.dart';

/// Same rule as the API: 4 to 16 letters, digits or underscores.
const _maxFriendCodeLength = 16;
final _friendCodePattern = RegExp(r'^[A-Z0-9_]{4,16}$');

/// The user's pseudo, to change, and friend code, to give to friends so
/// they can send them selections: copy it, and choose it for premium
/// members. Completes with the updated user when either changed.
Future<User?> showProfileSheet(BuildContext context, User user) {
  return showModalBottomSheet<User>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProfileSheet(user: user),
  );
}

class _ProfileSheet extends StatefulWidget {
  final User user;

  const _ProfileSheet({required this.user});

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  late String _nickname = widget.user.nickname;
  late final _newNickname = TextEditingController(text: _nickname);
  bool _isSavingNickname = false;
  String? _nicknameError;

  late String _code = widget.user.friendCode ?? '';
  final _newCode = TextEditingController();
  bool _isEditingCode = false;
  bool _isSavingCode = false;
  String? _codeError;

  User? _updated;

  @override
  void initState() {
    super.initState();
    _newNickname.addListener(() => setState(() {}));
    _newCode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _newNickname.dispose();
    _newCode.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop(_updated);

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: kSemanticSuccess,
      ));
  }

  Future<void> _saveNickname() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSavingNickname = true;
      _nicknameError = null;
    });
    final result =
        await AuthService.updateUser(nickname: _newNickname.text.trim());
    if (!mounted) return;
    setState(() {
      _isSavingNickname = false;
      if (result.isSuccess) {
        _updated = result.data;
        _nickname = result.data!.nickname;
        _newNickname.text = _nickname;
      } else {
        _nicknameError = result.error ?? 'Erreur lors de la mise à jour';
      }
    });
    if (result.isSuccess) _showSuccess('Pseudo mis à jour');
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    _showSuccess('Code ami copié');
  }

  void _customize() {
    if (!SubscriptionService.isSubscribed) {
      Navigator.of(context).pop(_updated);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SubscriptionPage()),
      );
      return;
    }
    setState(() {
      _isEditingCode = true;
      _newCode.text = _code;
    });
  }

  Future<void> _saveCode() async {
    setState(() {
      _isSavingCode = true;
      _codeError = null;
    });
    final result =
        await AuthService.updateFriendCode(_newCode.text.trim().toUpperCase());
    if (!mounted) return;
    setState(() {
      _isSavingCode = false;
      if (result.isSuccess) {
        _updated = result.data;
        _code = result.data!.friendCode ?? _code;
        _isEditingCode = false;
      } else {
        _codeError = result.error;
      }
    });
  }

  Widget _buildNickname() {
    final nickname = _newNickname.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pseudo', style: AppTextStyles.bodyBold15),
        SizedBox(height: 6.h),
        AppTextField(
          controller: _newNickname,
          hintText: 'Nouveau pseudo',
          enabled: !_isSavingNickname,
          textCapitalization: TextCapitalization.words,
        ),
        if (_nicknameError != null) ...[
          SizedBox(height: 24.h),
          FormErrorBanner(message: _nicknameError!),
        ],
        if (nickname.isNotEmpty && nickname != _nickname) ...[
          SizedBox(height: 24.h),
          AppButton(
            label: 'Enregistrer',
            backgroundColor: Theme.of(context).colorScheme.primary,
            isLoading: _isSavingNickname,
            onPressed: _saveNickname,
          ),
        ],
      ],
    );
  }

  /// Tap to copy; the copy icon on the right says so.
  Widget _buildCode() {
    final primary = Theme.of(context).colorScheme.primary;
    final shape = squircleBorder(radius: 36.r);
    final iconSize = 60.sp;
    return Material(
      color: primary.withValues(alpha: 0.08),
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: _isEditingCode ? null : _copy,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 36.h, horizontal: 36.w),
          child: Row(
            children: [
              // Mirrors the icon so the code stays centered
              SizedBox(width: iconSize),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _code,
                    style: AppTextStyles.baloo36
                        .copyWith(color: primary, letterSpacing: 4),
                  ),
                ),
              ),
              Icon(
                Icons.copy_rounded,
                size: iconSize,
                color: _isEditingCode ? Colors.transparent : primary,
                semanticLabel: 'Copier',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeEditor() {
    final code = _newCode.text.trim().toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Nouveau code ami', style: AppTextStyles.bodyBold15),
        SizedBox(height: 6.h),
        AppTextField(
          controller: _newCode,
          hintText: 'VEGAN_LYON',
          textCapitalization: TextCapitalization.characters,
          maxLength: _maxFriendCodeLength,
          showCounter: true,
          enabled: !_isSavingCode,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_]')),
          ],
        ),
        SizedBox(height: 6.h),
        Text('De 4 à 16 lettres, chiffres ou « _ ».',
            style:
                AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[600])),
        if (_codeError != null) ...[
          SizedBox(height: 24.h),
          FormErrorBanner(message: _codeError!),
        ],
        SizedBox(height: 36.h),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Annuler',
                backgroundColor: Colors.white,
                foregroundColor: kTextPrimary,
                borderColor: kBorderDefault,
                onPressed: _isSavingCode
                    ? null
                    : () => setState(() {
                          _isEditingCode = false;
                          _codeError = null;
                        }),
              ),
            ),
            SizedBox(width: 24.w),
            Expanded(
              child: AppButton(
                label: 'Enregistrer',
                backgroundColor: Theme.of(context).colorScheme.primary,
                isLoading: _isSavingCode,
                onPressed: _friendCodePattern.hasMatch(code) && code != _code
                    ? _saveCode
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFriendCode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Code ami', style: AppTextStyles.bodyBold15),
        SizedBox(height: 6.h),
        Text(
          'Donnez-le à vos proches pour qu\'iels vous envoient '
          'leurs sélections de lieux.',
          style: AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[600]),
        ),
        SizedBox(height: 24.h),
        _buildCode(),
        SizedBox(height: 36.h),
        if (_isEditingCode)
          _buildCodeEditor()
        else
          AppButton(
            label: 'Personnaliser mon code',
            icon: Icons.edit_rounded,
            backgroundColor: Theme.of(context).colorScheme.primary,
            trailing: const PremiumBadge(size: 20),
            onPressed: _customize,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<User>(
      // Back pops with the updated user too
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: BottomSheetShell(
          child: Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Mon profil', style: AppTextStyles.baloo22),
                  SizedBox(height: 36.h),
                  _buildNickname(),
                  if (_code.isNotEmpty) ...[
                    SizedBox(height: 60.h),
                    _buildFriendCode(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
