import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';

/// "No review yet" placeholder: chat bubble with a star badge, title and
/// subtitle. Compact, meant to sit inside a sheet above the rate CTA.
class ReviewsEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const ReviewsEmptyState({
    super.key,
    this.title = 'Aucun avis pour le moment',
    this.subtitle = 'Soyez la première personne à mettre un avis 🌱',
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(28.r),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 110.r,
                  color: primary,
                ),
              ),
              Positioned(
                right: 18.w,
                top: 14.h,
                child: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: kAccentYellow,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child:
                      Icon(Icons.star_rounded, size: 40.r, color: Colors.white),
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Text(
            title,
            style: AppTextStyles.baloo22,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            subtitle,
            style:
                AppTextStyles.bodyRegular15.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
