import 'dart:io' show File;
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';

/// Photo capture control used on the various "send us info" forms: a
/// dashed squircle drop-zone when empty, a preview with a remove button
/// once a photo's been taken.
class PhotoPickerBox extends StatelessWidget {
  final File? photo;
  final VoidCallback onPickPhoto;
  final VoidCallback onRemovePhoto;
  final bool isLoading;
  final String label;

  const PhotoPickerBox({
    super.key,
    required this.photo,
    required this.onPickPhoto,
    required this.onRemovePhoto,
    this.isLoading = false,
    this.label = 'Prendre une photo des ingrédients',
  });

  @override
  Widget build(BuildContext context) {
    final currentPhoto = photo;
    if (currentPhoto != null) {
      return Column(
        children: [
          Stack(
            children: [
              ClipSmoothRect(
                radius: squircleRadius(40.r),
                child: Image.file(
                  currentPhoto,
                  height: 200.h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onRemovePhoto,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: kSemanticError,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          TextButton.icon(
            onPressed: isLoading ? null : onPickPhoto,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Reprendre la photo'),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: isLoading ? null : onPickPhoto,
      child: CustomPaint(
        painter: _DashedSquircleBorderPainter(
          radius: 40.r,
          color: kBorderDefault,
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 100.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 120.h,
                color: Colors.grey.shade500,
              ),
              SizedBox(height: 10.h),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashes the outline of a squircle around whatever it's painted behind —
/// no third-party dashed-border dependency, just splitting the squircle's
/// own outline path into on/off segments via [PathMetric].
class _DashedSquircleBorderPainter extends CustomPainter {
  final double radius;
  final Color color;

  static const double _strokeWidth = 1.5;
  static const double _dashLength = 6;
  static const double _gapLength = 5;

  _DashedSquircleBorderPainter({
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_strokeWidth / 2);
    final outline = squircleBorder(radius: radius).getOuterPath(rect);

    final dashed = Path();
    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final segment = draw ? _dashLength : _gapLength;
        final next = (distance + segment).clamp(0.0, metric.length);
        if (draw) {
          dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        }
        distance = next;
        draw = !draw;
      }
    }

    canvas.drawPath(
      dashed,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DashedSquircleBorderPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}
