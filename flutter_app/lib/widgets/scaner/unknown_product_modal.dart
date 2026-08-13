import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vegan_app/models/vegan_status.dart';
import 'package:vegan_app/pages/app_pages/helpers/product.helper.dart';
import 'package:vegan_app/services/auth_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';
import 'package:vegan_app/widgets/shared/app_text_field.dart';
import 'package:vegan_app/widgets/shared/info_box.dart';
import 'package:vegan_app/widgets/shared/photo_picker_box.dart';

/// Bottom sheet shown automatically when a scanned barcode isn't in the
/// database yet ([ScanStatus.unknown]) or was submitted before but still
/// couldn't be identified ([ScanStatus.notFound]) — same form covers both,
/// since [ProductHelper.tryAddDocument] treats a resubmission the same as a
/// first submission.
class UnknownProductModal extends StatefulWidget {
  final String barcode;

  /// True for [ScanStatus.notFound] — someone already sent this product in,
  /// but it couldn't be processed — vs. false for [ScanStatus.unknown],
  /// where nobody has submitted it yet. Only changes the intro copy; the
  /// form and submission both stay the same either way.
  final bool alreadySubmitted;

  final VoidCallback? onNavigateToProfile;

  const UnknownProductModal({
    super.key,
    required this.barcode,
    this.alreadySubmitted = false,
    this.onNavigateToProfile,
  });

  @override
  State<UnknownProductModal> createState() => _UnknownProductModalState();
}

class _UnknownProductModalState extends State<UnknownProductModal> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  VeganStatus? _status;
  File? _photo;
  bool _isTakingPhoto = false;
  bool _isSending = false;

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (_isTakingPhoto) return;
    setState(() => _isTakingPhoto = true);

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() => _photo = File(pickedFile.path));
      }
    } finally {
      setState(() => _isTakingPhoto = false);
    }
  }

  Future<void> _submit() async {
    final photo = _photo;
    // Status is only collected (and required) for a first-time submission —
    // an already-submitted product already has one on file, we're just
    // filling in what's missing.
    if (photo == null || _isSending) return;
    if (!widget.alreadySubmitted && _status == null) return;
    setState(() => _isSending = true);

    final success = await ProductHelper.tryAddDocument(
      context,
      widget.barcode,
      _status,
      productName: _nameController.text.trim(),
      brand: _brandController.text.trim(),
      photo: photo,
    );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      setState(() => _isSending = false);
    }
  }

  void _navigateToProfile() {
    Navigator.of(context).pop();
    widget.onNavigateToProfile?.call();
  }

  Widget _buildStatusCard({
    required VeganStatus status,
    required String imagePath,
    required String label,
  }) {
    final isSelected = _status == status;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final (selectedBackground, selectedBorder) = switch (status) {
      VeganStatus.vegan => (kPrimaryTag, primaryColor),
      VeganStatus.nonVegan => (Colors.red.shade50, Colors.red.shade700),
      VeganStatus.maybeVegan => (Colors.orange.shade50, kAccentYellow),
    };
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _status = status),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
          decoration: ShapeDecoration(
            color: isSelected ? selectedBackground : Colors.white,
            shape: squircleBorder(
              radius: 40.r,
              side: BorderSide(
                color: isSelected ? selectedBorder : kBorderDefault,
                width: isSelected ? 1.5 : 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(imagePath, height: 300.h),
              SizedBox(height: 8.h),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium15.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Oops ! Produit non-référencé', style: AppTextStyles.baloo22),
        SizedBox(height: 12.h),
        Text(
          'Connectez-vous pour nous aider à ajouter ce produit à la base de données.',
          style: AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[600]),
        ),
        SizedBox(height: 28.h),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _navigateToProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: squircleBorder(radius: 12.r),
            ),
            child: const Text(
              'Se connecter / S\'inscrire',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey.shade300, width: 1.5),
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: squircleBorder(radius: 12.r),
            ),
            child: const Text('Plus tard', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final canSubmit = _photo != null &&
        !_isSending &&
        (widget.alreadySubmitted || _status != null);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: squircleBorderOnly(topLeft: 28.r, topRight: 28.r),
        ),
        padding: EdgeInsets.all(28.w),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 70.w,
                  height: 8.h,
                  margin: EdgeInsets.only(bottom: 24.h),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
              if (!AuthService.isLoggedIn)
                _buildLoginPrompt(context)
              else ...[
                Text(
                  widget.alreadySubmitted
                      ? 'Oops, il nous manque des infos sur ce produit'
                      : 'Oops ! Produit non-référencé',
                  style: AppTextStyles.baloo22,
                ),
                SizedBox(height: 4.h),
                Text(
                  'Code-barre : ${widget.barcode}',
                  style: AppTextStyles.bodyRegular13.copyWith(color: Colors.grey[500]),
                ),
                SizedBox(height: 8.h),
                Text(
                  widget.alreadySubmitted
                      ? 'Le produit nous a déjà été envoyé mais nous n\'avons pas réussi à '
                          'le traiter, merci de nous envoyer des infos !'
                      : 'Aidez-nous en nous transmettant des informations sur ce produit. '
                          'Chaque envoi est vérifié manuellement avant d\'être ajouté.',
                  style: AppTextStyles.bodyRegular15.copyWith(
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 42.h),
                const InfoBox(
                    text:
                        'Merci de n\'envoyer que des produits alimentaires, pas de cosmétiques.',
                  ),
                if (!widget.alreadySubmitted) ...[
                  SizedBox(height: 42.h),
                  Row(
                    spacing: 20.w,
                    children: [
                      _buildStatusCard(
                        status: VeganStatus.vegan,
                        imagePath: 'lib/assets/images/characters/lemon-vgn.webp',
                        label: 'Végane',
                      ),
                      _buildStatusCard(
                        status: VeganStatus.nonVegan,
                        imagePath: 'lib/assets/images/characters/lemon-not.webp',
                        label: 'Non-végane',
                      ),
                      _buildStatusCard(
                        status: VeganStatus.maybeVegan,
                        imagePath: 'lib/assets/images/characters/lemon-mby.webp',
                        label: 'Ne sais pas',
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 42.h),
                AppTextField(
                  controller: _nameController,
                  hintText: 'Nom du produit',
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 200,
                ),
                SizedBox(height: 24.h),
                AppTextField(
                  controller: _brandController,
                  hintText: 'Marque',
                  textCapitalization: TextCapitalization.words,
                  maxLength: 200,
                ),
                SizedBox(height: 24.h),
                PhotoPickerBox(
                  photo: _photo,
                  isLoading: _isTakingPhoto,
                  onPickPhoto: _takePhoto,
                  onRemovePhoto: () => setState(() => _photo = null),
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Annuler',
                        backgroundColor: kAccentYellow,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: AppButton(
                        label: _isSending ? 'Envoi...' : 'Envoyer',
                        backgroundColor: primaryColor,
                        onPressed: canSubmit ? _submit : null,
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: MediaQuery.of(context).padding.bottom + 12.h),
            ],
          ),
        ),
      ),
    );
  }
}