import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vegan_app/models/vegan_status.dart';
import 'package:vegan_app/pages/app_pages/helpers/product.helper.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/services/auth_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';
import 'package:vegan_app/widgets/shared/app_text_field.dart';
import 'package:vegan_app/widgets/shared/info_box.dart';
import 'package:vegan_app/widgets/shared/photo_picker_box.dart';

/// Bottom sheet for a barcode missing from the database
/// ([ScanStatus.unknown]) or submitted but unidentified
/// ([ScanStatus.notFound]). First-time submissions create a product via
/// [ProductHelper.tryAddDocument]; resubmissions file an error report via
/// [ProductHelper.tryAddError] instead, same as "Signaler une erreur".
class UnknownProductModal extends StatefulWidget {
  final String barcode;

  /// True for [ScanStatus.notFound] (already sent in, unprocessed) vs false
  /// for [ScanStatus.unknown] (never submitted). Only changes the intro copy.
  final bool alreadySubmitted;

  /// Opens the login/register sheet when a logged-out user taps in — see
  /// [_buildLoginPrompt].
  final VoidCallback? onLoginRequested;

  const UnknownProductModal({
    super.key,
    required this.barcode,
    this.alreadySubmitted = false,
    this.onLoginRequested,
  });

  @override
  State<UnknownProductModal> createState() => _UnknownProductModalState();
}

class _UnknownProductModalState extends State<UnknownProductModal> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _descriptionController = TextEditingController();
  VeganStatus? _status;
  File? _photo;
  bool _isTakingPhoto = false;
  bool _isSending = false;

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
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
    // Status is only required for a first-time submission — an already-
    // submitted product already has one on file.
    if (photo == null || _isSending) return;
    if (!widget.alreadySubmitted && _status == null) return;
    setState(() => _isSending = true);

    final bool success;
    if (widget.alreadySubmitted) {
      // Existing (incomplete) entry — file an error report, not a new product.
      success = await ProductHelper.tryAddError(
        context,
        widget.barcode,
        _descriptionController.text.trim(),
      );
      if (success) {
        final productId = await ApiService.getProductIdByEan(ean: widget.barcode);
        if (productId != null) {
          await ApiService.uploadProductImage(productId: productId, photo: photo);
        }
      }
      // tryAddError doesn't show its own snackbar (unlike tryAddDocument
      // below), so show one here for both outcomes.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Informations envoyées. Merci !'
                : 'Une erreur est survenue. Veuillez réessayer.'),
            backgroundColor: success ? kSemanticSuccess : kSemanticError,
          ),
        );
      }
    } else {
      success = await ProductHelper.tryAddDocument(
        context,
        widget.barcode,
        _status,
        productName: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        photo: photo,
      );
    }

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      setState(() => _isSending = false);
    }
  }

  void _requestLogin() {
    Navigator.of(context).pop();
    widget.onLoginRequested?.call();
  }

  Widget _buildStatusCard({
    required VeganStatus status,
    required String imagePath,
    required String label,
  }) {
    final isSelected = _status == status;
    final (selectedBackground, selectedBorder) = switch (status) {
      VeganStatus.vegan => (kPrimaryTag, kSemanticSuccess),
      VeganStatus.nonVegan => (kSemanticError.withValues(alpha: 0.1), kSemanticError),
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
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Plus tard',
                backgroundColor: Colors.white,
                foregroundColor: Colors.grey[700]!,
                borderColor: kBorderDefault,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: AppButton(
                label: 'Se connecter',
                backgroundColor: kAccentYellow,
                onPressed: _requestLogin,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
                if (widget.alreadySubmitted)
                  AppTextField(
                    controller: _descriptionController,
                    hintText: 'Décrivez le produit',
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 500,
                    minLines: 4,
                    maxLines: 8,
                  )
                else ...[
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
                ],
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
                        backgroundColor: kSemanticSuccess,
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