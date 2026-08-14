import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_text_styles.dart';

/// The two-panel "device" illustration used on the Vegandex page, with the
/// live scanned count and completion percentage overlaid on the placeholder
/// "screens" baked into `vegandex.webp`. The overlay rectangles below are
/// fractions of the source image's own 1006x728 bounds (measured against the
/// asset directly), so they land in the right spot at any render size as
/// long as the image is drawn at its native aspect ratio.
class VegandexStatsIllustration extends StatelessWidget {
  final int scannedCount;
  final int totalCount;

  const VegandexStatsIllustration({
    super.key,
    required this.scannedCount,
    required this.totalCount,
  });

  static const double _imageAspectRatio = 1006 / 728;
  static const Rect _countRect = Rect.fromLTRB(0.094, 0.305, 0.438, 0.679);
  static const Rect _percentRect = Rect.fromLTRB(0.594, 0.323, 0.921, 0.482);

  @override
  Widget build(BuildContext context) {
    final percent =
        totalCount > 0 ? ((scannedCount / totalCount) * 100).round() : 0;

    return AspectRatio(
      aspectRatio: _imageAspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            children: [
              Image.asset(
                'lib/assets/images/vegandex.webp',
                width: w,
                height: h,
                fit: BoxFit.contain,
              ),
              Positioned(
                left: _countRect.left * w,
                top: _countRect.top * h,
                width: _countRect.width * w,
                height: _countRect.height * h,
                child: Center(
                  child: Text(
                    '$scannedCount/$totalCount',
                    style: AppTextStyles.baloo26,
                  ),
                ),
              ),
              Positioned(
                left: _percentRect.left * w,
                top: _percentRect.top * h,
                width: _percentRect.width * w,
                height: _percentRect.height * h,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Complété à $percent %',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.baloo17.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
