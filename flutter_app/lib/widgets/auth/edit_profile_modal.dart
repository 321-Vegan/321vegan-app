import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/auth_service.dart';
import '../../helpers/preference_helper.dart';
import './change_email_modal.dart';

class EditProfileModal extends StatefulWidget {
  final String currentNickname;
  final String? currentAvatar;
  final String currentEmail;
  final VoidCallback onProfileUpdated;

  const EditProfileModal({
    super.key,
    required this.currentNickname,
    this.currentAvatar,
    required this.currentEmail,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends State<EditProfileModal> {
  late TextEditingController _nicknameController;
  String? _selectedAvatar;
  bool _isLoading = false;
  bool _randomAvatarEnabled = false;
  String? _pendingEmail;

  final List<String> _availableAvatars = [
    'lapin.png',
    'ver.png',
    'poisson.png',
    'canard.png',
    'poule.png',
    'mouton.png',
    'cochon.png',
    'vache.png',
    'chat.png'
  ];

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.currentNickname);
    _selectedAvatar = widget.currentAvatar;
    _loadRandomAvatarSetting();
    _loadPendingEmail();
  }

  Future<void> _loadRandomAvatarSetting() async {
    final enabled = await PreferencesHelper.getRandomAvatarEnabled();
    setState(() {
      _randomAvatarEnabled = enabled;
    });
  }

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
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final newNickname = _nicknameController.text.trim();

    if (newNickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le pseudo ne peut pas être vide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save random avatar preference
      await PreferencesHelper.saveRandomAvatarEnabled(_randomAvatarEnabled);

      // Save avatar to SharedPreferences
      final avatarChanged = _selectedAvatar != widget.currentAvatar;
      if (avatarChanged) {
        await PreferencesHelper.saveAvatar(_selectedAvatar);
      }

      // Update nickname/avatar on backend if changed
      final nicknameChanged = newNickname != widget.currentNickname;

      final nickname = nicknameChanged ? newNickname : null;
      final avatar = avatarChanged ? _selectedAvatar : null;
      if (nickname != null || avatar != null) {
        final result = await AuthService.updateUser(
          nickname: nicknameChanged ? newNickname : null,
          avatar: avatarChanged ? _selectedAvatar : null,
        );

        if (!result.isSuccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.error ?? 'Erreur lors de la mise à jour'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onProfileUpdated();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openChangeEmailModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.r),
            topRight: Radius.circular(20.r),
          ),
        ),
        child: ChangeEmailModal(
          currentEmail: widget.currentEmail,
          onChangeRequested: _loadPendingEmail,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Modifier le profil',
                style: TextStyle(
                  fontSize: 60.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                iconSize: 64.sp,
              ),
            ],
          ),

          SizedBox(height: 32.h),

          // Nickname field
          TextField(
            controller: _nicknameController,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'Pseudo',
              labelStyle: TextStyle(fontSize: 44.sp),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              prefixIcon: const Icon(Icons.person),
            ),
            style: TextStyle(fontSize: 48.sp),
          ),

          SizedBox(height: 24.h),

          // Email row — opens the dedicated change-email flow (requires
          // password + email confirmation, so it's not part of the main save).
          InkWell(
            onTap: _isLoading ? null : _openChangeEmailModal,
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.email_outlined,
                      size: 56.sp, color: Colors.grey[700]),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Email',
                              style: TextStyle(
                                fontSize: 40.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (_pendingEmail != null) ...[
                              SizedBox(width: 12.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20.r),
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.hourglass_top,
                                        size: 32.sp, color: Colors.orange[800]),
                                    SizedBox(width: 6.w),
                                    Text(
                                      'En attente de confirmation',
                                      style: TextStyle(
                                        fontSize: 30.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _pendingEmail ??
                              (widget.currentEmail.isNotEmpty
                                  ? widget.currentEmail
                                  : 'Changer d\'email'),
                          style: TextStyle(
                            fontSize: 44.sp,
                            color: Colors.grey[800],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 40.sp, color: Colors.grey[400]),
                ],
              ),
            ),
          ),

          SizedBox(height: 32.h),

          // Avatar selection
          Text(
            'Choisir un avatar',
            style: TextStyle(
              fontSize: 52.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          Text(
            'Illustrations par @violetteviette.tattoo.dessin & @kodasmarket.art & @ancielouille',
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 32.sp,
              color: Colors.grey[600],
            ),
          ),

          SizedBox(height: 16.h),

          // Avatar grid
          SizedBox(
            height: 900.h,
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16.w,
                mainAxisSpacing: 16.h,
              ),
              itemCount: _availableAvatars.length,
              itemBuilder: (context, index) {
                final avatar = _availableAvatars[index];
                final isSelected = avatar == _selectedAvatar;

                return GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _selectedAvatar = avatar;
                          });
                        },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[300]!,
                        width: isSelected ? 4 : 2,
                      ),
                      color: Colors.grey[100],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Image.asset(
                          'lib/assets/avatars/$avatar',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              size: 80.sp,
                              color: Colors.grey,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Random avatar checkbox
          CheckboxListTile(
            title: Text(
              'Avatar aléatoire',
              style: TextStyle(
                fontSize: 48.sp,
                color: Colors.grey[800],
              ),
            ),
            subtitle: Text(
              'Change automatiquement à chaque visite',
              style: TextStyle(
                fontSize: 36.sp,
                color: Colors.grey[600],
              ),
            ),
            value: _randomAvatarEnabled,
            onChanged: _isLoading
                ? null
                : (bool? value) {
                    setState(() {
                      _randomAvatarEnabled = value ?? false;
                    });
                  },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),

          SizedBox(height: 12.h),

          // Save button
          ElevatedButton(
            onPressed: _isLoading ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Enregistrer',
                    style: TextStyle(
                      fontSize: 48.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          SizedBox(height: 100.h),
        ],
      ),
    );
  }
}
