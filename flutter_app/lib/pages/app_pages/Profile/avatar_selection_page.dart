import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../helpers/preference_helper.dart';
import '../../../services/auth_service.dart';
import '../../../themes/app_colors.dart';
import '../../../themes/app_shapes.dart';
import '../../../themes/app_spacing.dart';
import '../../../themes/app_text_styles.dart';
import '../../../widgets/settings/settings_toggle_tile.dart';
import '../../../widgets/shared/app_background.dart';
import '../../../widgets/shared/info_box.dart';

/// Full-page avatar picker, reached from the Paramètres avatar/pencil tap.
/// Tapping an avatar saves it immediately and pops back — there's no
/// separate "Enregistrer" step.
class AvatarSelectionPage extends StatefulWidget {
  final String? currentAvatar;
  final VoidCallback? onAvatarUpdated;

  const AvatarSelectionPage({
    super.key,
    this.currentAvatar,
    this.onAvatarUpdated,
  });

  @override
  State<AvatarSelectionPage> createState() => _AvatarSelectionPageState();
}

class _AvatarSelectionPageState extends State<AvatarSelectionPage> {
  String? _selectedAvatar;
  bool _randomEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedAvatar = widget.currentAvatar;
    _loadRandomSetting();
  }

  Future<void> _loadRandomSetting() async {
    final enabled = await PreferencesHelper.getRandomAvatarEnabled();
    if (!mounted) return;
    setState(() {
      _randomEnabled = enabled;
      _isLoading = false;
    });
  }

  Future<void> _toggleRandom(bool value) async {
    setState(() => _randomEnabled = value);
    await PreferencesHelper.saveRandomAvatarEnabled(value);

    // Turning random mode off makes the displayed avatar an explicit choice
    // — it must reach the account, otherwise the next profile load would
    // revert to the account's last explicit avatar.
    if (!value && _selectedAvatar != null) {
      await AuthService.updateUser(avatar: _selectedAvatar);
    }
    widget.onAvatarUpdated?.call();
  }

  Future<void> _selectAvatar(String avatar) async {
    if (_isSaving) return;
    if (avatar == widget.currentAvatar && !_randomEnabled) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSaving = true;
      _selectedAvatar = avatar;
    });

    await PreferencesHelper.saveAvatar(avatar);
    final result = await AuthService.updateUser(avatar: avatar);

    if (!mounted) return;

    if (result.isSuccess) {
      widget.onAvatarUpdated?.call();
      Navigator.of(context).pop();
    } else {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Erreur lors de la mise à jour'),
          backgroundColor: kSemanticError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Avatar', style: AppTextStyles.baloo22),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: SafeArea(
          top: false,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal, 8.h, AppSpacing.pageHorizontal, 32.h),
                  children: [
                    const InfoBox(
                      text: 'Illustrations par '
                          '@vilainevegane.illustration, '
                          '@kodasmarket.art et @ancielouille.',
                      icon: Icons.favorite,
                    ),
                    SizedBox(height: AppSpacing.item),
                    SettingsToggleTile(
                      title: 'Avatar aléatoire à chaque visite',
                      value: _randomEnabled,
                      onChanged: _isSaving ? (_) {} : _toggleRandom,
                    ),
                    SizedBox(height: AppSpacing.section),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 36.w,
                        mainAxisSpacing: 36.h,
                        childAspectRatio: 1,
                      ),
                      itemCount: kAvailableAvatars.length,
                      itemBuilder: (context, index) {
                        final avatar = kAvailableAvatars[index];
                        final isSelected = avatar == _selectedAvatar;

                        return GestureDetector(
                          onTap: () => _selectAvatar(avatar),
                          child: Container(
                            padding: EdgeInsets.all(24.w),
                            decoration: ShapeDecoration(
                              color: isSelected ? kSecondaryTag : Colors.white,
                              shape: squircleBorder(
                                radius: 90.r,
                                side: BorderSide(
                                  color: isSelected
                                      ? kAccentYellow
                                      : kBorderDefault,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                            ),
                            child: Image.asset(
                              'lib/assets/avatars/$avatar',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                Icons.person,
                                size: 80.sp,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
