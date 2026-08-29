import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vegan_app/pages/app_pages/helpers/product.helper.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';
import 'package:vegan_app/widgets/shared/app_text_field.dart';
import 'package:vegan_app/widgets/shared/info_box.dart';
import 'package:vegan_app/widgets/shared/photo_picker_box.dart';

/// Trigger + bottom sheet for reporting an error on a scanned product
/// (wrong vegan status, missing/incorrect ingredients, etc). Tapping the
/// trigger opens a form (comment, optional contact, optional photo) that
/// submits via [ProductHelper.tryAddError].
class ReportErrorButton extends StatelessWidget {
  static const _accentColor = Colors.orange;

  final String barcode;
  final VoidCallback? onScannerStop;
  final VoidCallback? onScannerStart;

  const ReportErrorButton({
    super.key,
    required this.barcode,
    this.onScannerStop,
    this.onScannerStart,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onScannerStop?.call();
        final rootContext = context;
        showModalBottomSheet(
          context: rootContext,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _ReportErrorModalContent(
            barcode: barcode,
            rootContext: rootContext,
          ),
        ).then((_) {
          onScannerStart?.call();
        });
      },
      // White trigger text since it sits over the live camera feed; the
      // modal itself (header icon, submit button) uses [_accentColor].
      child: Text(
        "Signaler une erreur",
        style: AppTextStyles.bodyBold15.copyWith(
          color: Colors.white,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white,
        ),
      ),
    );
  }
}

class _ReportErrorModalContent extends StatefulWidget {
  final String barcode;
  final BuildContext rootContext;

  const _ReportErrorModalContent({
    required this.barcode,
    required this.rootContext,
  });

  @override
  State<_ReportErrorModalContent> createState() =>
      _ReportErrorModalContentState();
}

class _ReportErrorModalContentState extends State<_ReportErrorModalContent> {
  final _commentController = TextEditingController();
  final _contactController = TextEditingController();
  File? _photo;
  bool _isTakingPhoto = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Rebuilds on every keystroke so the submit button's enabled state
    // (gated on a non-empty comment) stays in sync.
    _commentController.addListener(_onCommentChanged);
  }

  void _onCommentChanged() => setState(() {});

  @override
  void dispose() {
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    _contactController.dispose();
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
    if (_commentController.text.trim().isEmpty || _isSending) return;
    setState(() => _isSending = true);

    Navigator.of(context).pop();

    bool result = await ProductHelper.tryAddError(
      widget.rootContext,
      widget.barcode,
      _commentController.text.trim(),
      contact: _contactController.text.trim(),
    );

    if (_photo != null) {
      final productId = await ApiService.getProductIdByEan(ean: widget.barcode);
      if (productId != null) {
        await ApiService.uploadProductImage(
          productId: productId,
          photo: _photo!,
        );
      }
    }

    await Future.delayed(const Duration(milliseconds: 100));
    if (!widget.rootContext.mounted) return;
    final messenger = ScaffoldMessenger.of(widget.rootContext);

    if (!result) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Une erreur est survenue. Veuillez réessayer."),
          backgroundColor: kSemanticError,
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
              "Signalement envoyé. Merci ! Retrouvez vos signalement sur votre page de profil."),
          backgroundColor: kSemanticSuccess,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _commentController.text.trim().isNotEmpty && !_isSending;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: squircleBorderOnly(topLeft: 20.r, topRight: 20.r),
        ),
        padding: EdgeInsets.all(24.w),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 16.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: ShapeDecoration(
                      color:
                          ReportErrorButton._accentColor.withValues(alpha: 0.1),
                      shape: squircleBorder(radius: 12),
                    ),
                    child: Icon(
                      Icons.report_problem,
                      color: ReportErrorButton._accentColor,
                      size: 54.sp,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Signaler une erreur",
                          style: AppTextStyles.baloo22,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          "Code-barre : ${widget.barcode}",
                          style: AppTextStyles.bodyRegular13.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              const InfoBox(
                text: "Avant de signaler une erreur : les mentions "
                    "« traces de... » ou « peut contenir... » ne rendent "
                    "pas un produit non vegan, c'est une mention à "
                    "destination des personnes allergiques. Si possible, "
                    "ajoutez une photo des ingrédients : cela nous aide "
                    "beaucoup à vérifier votre signalement. Merci !",
              ),
              SizedBox(height: 16.h),

              RichText(
                text: TextSpan(
                  text: "Décrivez le problème ",
                  style: AppTextStyles.bodyBold15,
                  children: const [
                    TextSpan(
                      text: "*",
                      style: TextStyle(
                        color: kSemanticError,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 6.h),
              AppTextField(
                controller: _commentController,
                hintText: "Ex: Ce produit n'est pas vegan, il contient...",
                textCapitalization: TextCapitalization.sentences,
                maxLength: 800,
                minLines: 4,
                maxLines: 8,
              ),
              SizedBox(height: 12.h),

              Text(
                "Comment vous contacter ?",
                style: AppTextStyles.bodyBold15,
              ),
              SizedBox(height: 6.h),
              AppTextField(
                controller: _contactController,
                hintText: "Email ou @ instagram",
                maxLength: 200,
              ),
              SizedBox(height: 16.h),

              Text(
                'Photo des ingrédients (si possible)',
                style: AppTextStyles.bodyBold15,
              ),
              SizedBox(height: 6.h),
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
              SizedBox(height: 160.h),
            ],
          ),
        ),
      ),
    );
  }
}
