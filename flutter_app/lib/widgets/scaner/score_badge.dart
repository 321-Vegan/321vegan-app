import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/themes/app_shapes.dart';

/// Nutriscore + Green-score
class ScoreBadges extends StatelessWidget {
  final String? nutriscoreGrade;
  final String? ecoscoreGrade;

  /// Size multiplier for compact placements (e.g. inline in a scan-result
  /// card) — 1.0 matches the original full-size floating layout.
  final double scale;

  /// Row (side by side) or column (stacked) layout for the two badges.
  final Axis direction;

  const ScoreBadges({
    super.key,
    this.nutriscoreGrade,
    this.ecoscoreGrade,
    this.scale = 1.0,
    this.direction = Axis.horizontal,
  });

  static const _nutriAssets = {
    'a': 'lib/assets/images/nutri-eco-scores/nutriA.webp',
    'b': 'lib/assets/images/nutri-eco-scores/nutriB.webp',
    'c': 'lib/assets/images/nutri-eco-scores/nutriC.webp',
    'd': 'lib/assets/images/nutri-eco-scores/nutriD.webp',
    'e': 'lib/assets/images/nutri-eco-scores/nutriE.webp',
  };

  static const _ecoAssets = {
    'a-plus': 'lib/assets/images/nutri-eco-scores/green-score-a-plus.webp',
    'a': 'lib/assets/images/nutri-eco-scores/green-score-a.webp',
    'b': 'lib/assets/images/nutri-eco-scores/green-score-b.webp',
    'c': 'lib/assets/images/nutri-eco-scores/green-score-c.webp',
    'd': 'lib/assets/images/nutri-eco-scores/green-score-d.webp',
    'e': 'lib/assets/images/nutri-eco-scores/green-score-e.webp',
    'f': 'lib/assets/images/nutri-eco-scores/green-score-f.webp',
  };

  @override
  Widget build(BuildContext context) {
    final first = _ScoreImage(
      assetPath: nutriscoreGrade != null ? _nutriAssets[nutriscoreGrade] : null,
      label: 'Nutriscore',
      scale: scale,
    );
    final second = _ScoreImage(
      assetPath: ecoscoreGrade != null ? _ecoAssets[ecoscoreGrade] : null,
      label: 'Green-score',
      scale: scale,
    );
    if (direction == Axis.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [first, SizedBox(height: 8.h * scale), second],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [first, SizedBox(width: 12.w * scale), second],
    );
  }
}

class _ScoreImage extends StatelessWidget {
  final String? assetPath;
  final String label;
  final double scale;

  const _ScoreImage({
    required this.assetPath,
    required this.label,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (assetPath == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 34.sp * scale,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 4.h * scale),
          Container(
            width: 140.w * scale,
            height: 140.w * scale,
            decoration: ShapeDecoration(
              color: Colors.grey[100],
              shape: squircleBorder(radius: 10.r * scale),
            ),
            child: Center(
              child: Text(
                '?',
                style: TextStyle(
                  fontSize: 36.sp * scale,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 25.h * scale),
        Image.asset(
          assetPath!,
          height: 160.w * scale,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}
