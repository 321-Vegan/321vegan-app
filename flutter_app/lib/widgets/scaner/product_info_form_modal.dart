import 'dart:io' show File;
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vegan_app/themes/app_shapes.dart';

class ProductInfoFormResult {
  final String productName;
  final String brand;
  final File photo;

  ProductInfoFormResult({
    required this.productName,
    required this.brand,
    required this.photo,
  });
}

class ProductInfoFormModal extends StatefulWidget {
  const ProductInfoFormModal({super.key});

  static Future<ProductInfoFormResult?> show(BuildContext context) {
    return showModalBottomSheet<ProductInfoFormResult>(
      context: context,
      isScrollControlled: true,
      // Prevent accidental swipe-dismiss from discarding the photo/info the
      // user already entered; require an explicit close (X) or submit.
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => const ProductInfoFormModal(),
    );
  }

  @override
  State<ProductInfoFormModal> createState() => _ProductInfoFormModalState();
}

class _ProductInfoFormModalState extends State<ProductInfoFormModal> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  File? _photo;
  bool _isTakingPhoto = false;

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

  void _submit() {
    final photo = _photo;
    if (photo == null) return;
    Navigator.of(context).pop(ProductInfoFormResult(
      productName: _nameController.text.trim(),
      brand: _brandController.text.trim(),
      photo: photo,
    ));
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
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: ShapeDecoration(
                      color: Colors.green.shade50,
                      shape: squircleBorder(radius: 12),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: Colors.green.shade700,
                      size: 54.sp,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  const Expanded(
                    child: Text(
                      'Informations produit',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                'Le nom et la marque sont optionnels (mais ça nous aide si vous les renseignez !). La photo des ingrédients est obligatoire.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 20.h),

              // Product name
              const Text(
                'Nom du produit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 6.h),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Ex: Galettes de légumes',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Brand
              const Text(
                'Marque',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 6.h),
              TextField(
                controller: _brandController,
                textCapitalization: TextCapitalization.words,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Ex: Bjorg',
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
              RichText(
                text: const TextSpan(
                  text: 'Photo des ingrédients ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  children: [
                    TextSpan(
                      text: '*',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),

              const Text(
                'Veuillez ajouter une photo des ingrédients (ou du logo végane s\'il y en a un).',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w200,
                  color: Colors.black87,
                ),
              ),
              
              SizedBox(height: 6.h),
              if (_photo != null) ...[
                Stack(
                  children: [
                    ClipSmoothRect(
                      radius: squircleRadius(12),
                      child: Image.file(
                        _photo!,
                        height: 180.h,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _photo = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Center(
                  child: TextButton.icon(
                    onPressed: _isTakingPhoto ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Reprendre la photo'),
                  ),
                ),
              ] else
                GestureDetector(
                  onTap: _isTakingPhoto ? null : _takePhoto,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    decoration: ShapeDecoration(
                      color: Colors.grey.shade100,
                      shape: squircleBorder(
                        radius: 12,
                        side: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 40,
                          color: Colors.grey.shade500,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Prendre une photo des ingrédients',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 24.h),

              // Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _photo == null ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: squircleBorder(radius: 12),
                  ),
                  child: const Text(
                    'Envoyer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 160.h),
            ],
          ),
        ),
      ),
    );
  }
}
