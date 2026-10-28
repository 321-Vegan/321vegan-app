import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';

/// Square photo with squircle corners (network or file [image]), grey while
/// loading or when it fails. [featured] outlines it in yellow with a star
/// (the photo shown first), [outline] in another color. [overlays] go on
/// top, e.g. a remove button.
class PhotoTile extends StatelessWidget {
  final ImageProvider image;
  final double size;

  /// Defaults to 30.r.
  final double? radius;
  final bool featured;
  final Color? outline;
  final double opacity;
  final VoidCallback? onTap;
  final List<Widget> overlays;

  const PhotoTile({
    super.key,
    required this.image,
    required this.size,
    this.radius,
    this.featured = false,
    this.outline,
    this.opacity = 1,
    this.onTap,
    this.overlays = const [],
  });

  @override
  Widget build(BuildContext context) {
    final r = radius ?? 30.r;
    final borderColor = featured ? kAccentYellow : outline;
    final content = Stack(
      children: [
        Container(
          width: size,
          height: size,
          foregroundDecoration: borderColor == null
              ? null
              : ShapeDecoration(
                  shape: squircleBorder(
                    radius: r,
                    side: BorderSide(color: borderColor, width: 3),
                  ),
                ),
          child: ClipSmoothRect(
            radius: squircleRadius(r),
            child: Opacity(
              opacity: opacity,
              child: ColoredBox(
                color: Colors.grey[200]!,
                child: Image(
                  image: image,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Center(child: Icon(Icons.image, color: Colors.grey[400])),
                ),
              ),
            ),
          ),
        ),
        if (featured)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: kAccentYellow,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.star_rounded, color: Colors.white, size: 16),
            ),
          ),
        ...overlays,
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}
