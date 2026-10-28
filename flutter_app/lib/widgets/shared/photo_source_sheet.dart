import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import 'bottom_sheet_shell.dart';

/// Asks camera or gallery, then picks up to [max] photos (one with the
/// camera). Photos are downscaled like the other upload forms. Empty when
/// dismissed or on picker error.
Future<List<File>> pickPhotos(BuildContext context, {int max = 1}) async {
  if (max <= 0) return [];
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => BottomSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_camera_outlined),
            title:
                Text('Prendre une photo', style: AppTextStyles.bodyRegular15),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(
              max > 1 ? 'Choisir dans la galerie' : 'Choisir une photo',
              style: AppTextStyles.bodyRegular15,
            ),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
          SizedBox(height: 12.h),
        ],
      ),
    ),
  );
  if (source == null) return [];

  try {
    final picker = ImagePicker();
    if (source == ImageSource.gallery && max > 1) {
      final picked = await picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
        limit: max,
      );
      return picked.take(max).map((x) => File(x.path)).toList();
    }
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    return picked == null ? [] : [File(picked.path)];
  } catch (_) {
    return [];
  }
}

/// Lets the user frame [photo] at [ratioX]:[ratioY] in the platform's crop
/// screen. Null when cancelled or on cropper error.
Future<File?> cropPhoto(
  BuildContext context,
  File photo, {
  required double ratioX,
  required double ratioY,
  String title = 'Recadrer',
}) async {
  final primary = Theme.of(context).colorScheme.primary;
  try {
    final cropped = await ImageCropper().cropImage(
      sourcePath: photo.path,
      aspectRatio: CropAspectRatio(ratioX: ratioX, ratioY: ratioY),
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: Colors.white,
          toolbarWidgetColor: kTextPrimary,
          statusBarLight: true,
          activeControlsWidgetColor: primary,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: title,
          doneButtonTitle: 'Valider',
          cancelButtonTitle: 'Annuler',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );
    return cropped == null ? null : File(cropped.path);
  } catch (_) {
    return null;
  }
}
