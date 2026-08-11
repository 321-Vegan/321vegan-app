import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/themes/app_shapes.dart';

/// Nutriscore + Green-score
class ScoreBadges extends StatelessWidget {
  final String? nutriscoreGrade;
  final String? ecoscoreGrade;

  const ScoreBadges({
    super.key,
    this.nutriscoreGrade,
    this.ecoscoreGrade,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ScoreImage(
          assetPath: nutriscoreGrade != null ? _nutriAssets[nutriscoreGrade] : null,
          label: 'Nutriscore',
        ),
        SizedBox(width: 12.w),
        _ScoreImage(
          assetPath: ecoscoreGrade != null ? _ecoAssets[ecoscoreGrade] : null,
          label: 'Green-score',
        ),
      ],
    );
  }
}

class _ScoreImage extends StatelessWidget {
  final String? assetPath;
  final String label;

  const _ScoreImage({required this.assetPath, required this.label});

  @override
  Widget build(BuildContext context) {
    if (assetPath == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 34.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          SizedBox(height: 4.h),
          Container(
            width: 140.w,
            height: 140.w,
            decoration: ShapeDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: squircleBorder(radius: 10.r),
            ),
            child: Center(
              child: Text(
                '?',
                style: TextStyle(
                  fontSize: 36.sp,
                  color: Colors.white.withValues(alpha: 0.5),
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
        SizedBox(height: 25.h),
        Image.asset(
          assetPath!,
          height: 160.w,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}
