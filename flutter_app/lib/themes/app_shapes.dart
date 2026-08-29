import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';

/// Figma "corner smoothing" factor applied to every rounded corner in the
/// app so borders read as squircles (mi-rond mi-carré) rather than plain
/// circular arcs. 0.6 matches the default Figma smoothing preset.
const double kCornerSmoothing = 0.6;

/// Radius helper for [ClipSmoothRect] and anywhere a [BorderRadiusGeometry]
/// is expected (e.g. clipping an image into a squircle).
SmoothBorderRadius squircleRadius(
  double radius, {
  double smoothing = kCornerSmoothing,
}) {
  return SmoothBorderRadius(cornerRadius: radius, cornerSmoothing: smoothing);
}

/// Shape helper for anywhere a [ShapeBorder] is expected: `Card.shape`,
/// `Dialog.shape`, `InkWell.customBorder`, or `ShapeDecoration.shape`
/// (the squircle replacement for `BoxDecoration.borderRadius`).
SmoothRectangleBorder squircleBorder({
  required double radius,
  double smoothing = kCornerSmoothing,
  BorderSide side = BorderSide.none,
  BorderAlign align = BorderAlign.inside,
}) {
  return SmoothRectangleBorder(
    borderRadius: squircleRadius(radius, smoothing: smoothing),
    side: side,
    borderAlign: align,
  );
}

/// Same as [squircleBorder] but with independent per-corner radii, for
/// shapes like bottom-sheet handles (top corners only).
SmoothRectangleBorder squircleBorderOnly({
  double topLeft = 0,
  double topRight = 0,
  double bottomLeft = 0,
  double bottomRight = 0,
  double smoothing = kCornerSmoothing,
  BorderSide side = BorderSide.none,
  BorderAlign align = BorderAlign.inside,
}) {
  return SmoothRectangleBorder(
    borderRadius: SmoothBorderRadius.only(
      topLeft: SmoothRadius(cornerRadius: topLeft, cornerSmoothing: smoothing),
      topRight:
          SmoothRadius(cornerRadius: topRight, cornerSmoothing: smoothing),
      bottomLeft:
          SmoothRadius(cornerRadius: bottomLeft, cornerSmoothing: smoothing),
      bottomRight:
          SmoothRadius(cornerRadius: bottomRight, cornerSmoothing: smoothing),
    ),
    side: side,
    borderAlign: align,
  );
}
