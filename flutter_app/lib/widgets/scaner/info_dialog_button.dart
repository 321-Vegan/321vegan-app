import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vegan_app/pages/app_pages/helpers/product.helper.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/widgets/shared/photo_picker_box.dart';

class InfoDialogButton extends StatelessWidget {
  final String barcode;
  final String buttonLabel;
  final String dialogTitle;
  final String commentTitle;
  final String commentHint;
  final Color buttonColor;

  /// Color of the visible trigger text/underline — defaults to
  /// [buttonColor], override when the trigger sits somewhere [buttonColor]
  /// wouldn't be legible (e.g. white over the camera feed) while keeping
  /// the modal's own styling (header icon, submit button) on [buttonColor].
  final Color? triggerColor;
  final bool showPreReportNotice;
  final VoidCallback? onScannerStop;
  final VoidCallback? onScannerStart;

  const InfoDialogButton({
    super.key,
    required this.barcode,
    required this.buttonLabel,
    required this.dialogTitle,
    required this.commentTitle,
    required this.commentHint,
    required this.buttonColor,
    this.triggerColor,
    this.showPreReportNotice = false,
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
          builder: (context) => _InfoDialogModalContent(
            barcode: barcode,
            dialogTitle: dialogTitle,
            commentTitle: commentTitle,
            commentHint: commentHint,
            buttonColor: buttonColor,
            showPreReportNotice: showPreReportNotice,
            rootContext: rootContext,
          ),
        ).then((_) {
          onScannerStart?.call();
        });
      },
      child: Text(
        buttonLabel,
        style: TextStyle(
          fontSize: 45.sp,
          fontWeight: FontWeight.w600,
          color: triggerColor ?? buttonColor,
          decoration: TextDecoration.underline,
          decorationColor: triggerColor ?? buttonColor,
        ),
      ),
    );
  }
}

class _InfoDialogModalContent extends StatefulWidget {
  final String barcode;
  final String dialogTitle;
  final String commentTitle;
  final String commentHint;
  final Color buttonColor;
  final bool showPreReportNotice;
  final BuildContext rootContext;

  const _InfoDialogModalContent({
    required this.barcode,
    required this.dialogTitle,
    required this.commentTitle,
    required this.commentHint,
    required this.buttonColor,
    required this.showPreReportNotice,
    required this.rootContext,
  });

  @override
  State<_InfoDialogModalContent> createState() =>
      _InfoDialogModalContentState();
}

class _InfoDialogModalContentState extends State<_InfoDialogModalContent> {
  final _commentController = TextEditingController();
  final _contactController = TextEditingController();
  String? _commentErrorText;
  File? _photo;
  bool _isTakingPhoto = false;
  bool _isSending = false;

  @override
  void dispose() {
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
    if (_commentController.text.trim().isEmpty) {
      setState(() => _commentErrorText = "Ce champ est requis.");
      return;
    }
    if (_isSending) return;
    setState(() => _isSending = true);

    Navigator.of(context).pop();

    bool result = await ProductHelper.tryAddError(
      widget.rootContext,
      widget.barcode,
      _commentController.text.trim(),
      contact: _contactController.text.trim(),
    );

    // Upload photo to the product if provided
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
          content: Text("Signalement envoyé. Merci ! Retrouvez vos signalement sur votre page de profil."),
          backgroundColor: kSemanticSuccess,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // Handle bar
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

              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: ShapeDecoration(
                      color: widget.buttonColor.withValues(alpha: 0.1),
                      shape: squircleBorder(radius: 12),
                    ),
                    child: Icon(
                      Icons.report_problem,
                      color: widget.buttonColor,
                      size: 54.sp,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.dialogTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          "Code-barre : ${widget.barcode}",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              // Pre-report notice (error reports only)
              if (widget.showPreReportNotice) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  decoration: ShapeDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    shape: squircleBorder(
                      radius: 12,
                      side: BorderSide(
                        color: Colors.amber.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Colors.amber.shade800,
                            size: 60.sp,
                          ),
                          SizedBox(width: 8.w),
                          const Text(
                            "Avant de signaler une erreur",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      const Text(
                        "• Les mentions « traces de... » ou « peut contenir... » "
                        "ne rendent pas un produit non vegan : c'est une mention à destination des personnes allergiques. Ça ne rentre pas dans les ingrédients de la recette !"
                        "\n"
                        "• Si possible, ajoutez une photo des ingrédients : "
                        "cela nous aide beaucoup à vérifier votre signalement. Merci !",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
              ],

              // Comment field (required)
              RichText(
                text: TextSpan(
                  text: widget.commentTitle,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
              TextField(
                controller: _commentController,
                maxLines: 4,
                maxLength: 800,
                decoration: InputDecoration(
                  hintText: widget.commentHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                  errorText: _commentErrorText,
                ),
                onChanged: (_) {
                  if (_commentErrorText != null) {
                    setState(() => _commentErrorText = null);
                  }
                },
              ),
              SizedBox(height: 12.h),

              // Contact field (optional)
              const Text(
                "Comment vous contacter ?",
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6.h),
              TextField(
                controller: _contactController,
                maxLines: 1,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText:
                      "Email ou @ instagram",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Photo section
              const Text(
                'Photo des ingrédients (si possible)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 6.h),
              PhotoPickerBox(
                photo: _photo,
                isLoading: _isTakingPhoto,
                onPickPhoto: _takePhoto,
                onRemovePhoto: () => setState(() => _photo = null),
              ),
              SizedBox(height: 24.h),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: squircleBorder(radius: 12),
                      ),
                      child: const Text(
                        'Annuler',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.buttonColor,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: squircleBorder(radius: 12),
                      ),
                      child: Text(
                        _isSending ? 'Envoi...' : 'Envoyer',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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

class ReportErrorButton extends StatelessWidget {
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
    return InfoDialogButton(
      barcode: barcode,
      buttonLabel: "Signaler une erreur",
      dialogTitle: "Signaler une erreur",
      commentTitle: "Décrivez le problème ",
      commentHint: "Ex: Ce produit n'est pas vegan, il contient...",
      buttonColor: Colors.orange,
      triggerColor: Colors.white,
      showPreReportNotice: true,
      onScannerStop: onScannerStop,
      onScannerStart: onScannerStart,
    );
  }
}
