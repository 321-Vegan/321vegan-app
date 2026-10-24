import 'dart:io' show File;
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import 'photo_source_sheet.dart';

/// Thumbnails of the photos picked for an upload, each with a remove
/// button, followed by an "add" tile while fewer than [max] are picked.
class PickedPhotosRow extends StatelessWidget {
  final List<File> photos;
  final ValueChanged<List<File>> onChanged;
  final int max;
  final bool enabled;

  const PickedPhotosRow({
    super.key,
    required this.photos,
    required this.onChanged,
    required this.max,
    this.enabled = true,
  });

  Future<void> _add(BuildContext context) async {
    final picked = await pickPhotos(context, max: max - photos.length);
    if (picked.isNotEmpty) onChanged([...photos, ...picked]);
  }

  @override
  Widget build(BuildContext context) {
    final size = 220.w;
    return Wrap(
      spacing: 24.w,
      runSpacing: 24.w,
      children: [
        for (final photo in photos)
          Stack(
            children: [
              ClipSmoothRect(
                radius: squircleRadius(30.r),
                child: Image.file(photo,
                    width: size, height: size, fit: BoxFit.cover),
              ),
              if (enabled)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () =>
                        onChanged([...photos]..remove(photo)),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: kSemanticError,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
            ],
          ),
        if (photos.length < max)
          GestureDetector(
            onTap: enabled ? () => _add(context) : null,
            child: Container(
              width: size,
              height: size,
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: squircleBorder(
                  radius: 30.r,
                  side: const BorderSide(color: kBorderDefault),
                ),
              ),
              child: Icon(Icons.add_a_photo_outlined,
                  size: 72.sp, color: Colors.grey[500]),
            ),
          ),
      ],
    );
  }
}
