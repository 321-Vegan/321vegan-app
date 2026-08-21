import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/auth_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/app_text_field.dart';
import '../shared/bottom_sheet_shell.dart';
import '../shared/form_error_banner.dart';

class ChangeUsernameModal extends StatefulWidget {
  final String currentNickname;
  final VoidCallback? onUsernameChanged;

  const ChangeUsernameModal({
    super.key,
    required this.currentNickname,
    this.onUsernameChanged,
  });

  @override
  State<ChangeUsernameModal> createState() => _ChangeUsernameModalState();
}

class _ChangeUsernameModalState extends State<ChangeUsernameModal> {
  late final TextEditingController _nicknameController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.currentNickname);
    _nicknameController.addListener(_handleInputChanged);
  }

  void _handleInputChanged() => setState(() {});

  bool get _canSubmit => _nicknameController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nicknameController.removeListener(_handleInputChanged);
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newNickname = _nicknameController.text.trim();

    if (newNickname.isEmpty) {
      setState(() => _errorMessage = 'Le pseudo ne peut pas être vide');
      return;
    }

    if (newNickname == widget.currentNickname) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.updateUser(nickname: newNickname);

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() => _isLoading = false);
      widget.onUsernameChanged?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pseudo mis à jour avec succès !'),
          backgroundColor: kSemanticSuccess,
        ),
      );
    } else {
      // Kept on-screen (not a SnackBar): the sheet stays open so the user
      // can retry, and a page-level SnackBar would render behind it.
      setState(() {
        _isLoading = false;
        _errorMessage = result.error ?? 'Erreur lors de la mise à jour';
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
                  Text('Modifier votre pseudo', style: AppTextStyles.baloo22),
                ],
              ),
              Text(
                'Pseudo actuel : ${widget.currentNickname}',
                style: TextStyle(fontSize: 42.sp, color: Colors.grey[600]),
              ),
              SizedBox(height: 48.h),
              AppTextField(
                controller: _nicknameController,
                hintText: 'Nouveau pseudo',
                enabled: !_isLoading,
                textCapitalization: TextCapitalization.words,
              ),
              if (_errorMessage != null) ...[
                SizedBox(height: 24.h),
                FormErrorBanner(message: _errorMessage!),
              ],
              SizedBox(height: 32.h),
              AppButton(
                label: 'Enregistrer',
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
