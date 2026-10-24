import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import '../shared/premium_badge.dart';
import 'star_rating.dart';

/// Nickname followed by the premium crown when the author is premium.
class ReviewerName extends StatelessWidget {
  final String? nickname;
  final bool isPremium;

  const ReviewerName({
    super.key,
    required this.nickname,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        nickname != null && nickname!.isNotEmpty ? nickname! : 'Anonyme';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyBold15,
          ),
        ),
        if (isPremium) ...[
          SizedBox(width: 10.w),
          PremiumBadge(size: 45.sp),
        ],
      ],
    );
  }
}

/// White hairline card showing one review: author (with premium crown),
/// date, stars and comment. Shared by shop and product reviews.
///
/// [header] goes above the author row (e.g. the rated product on the
/// "Mes notes" page), [badge] next to the date (e.g. moderation status),
/// [trailing] at the end of the author row (e.g. an edit button; hidden
/// with the author row when [showAuthor] is false), [footer] under the
/// comment (e.g. a restaurant review's detailed ratings and photos).
class ReviewCard extends StatelessWidget {
  final String? nickname;
  final bool isPremium;
  final int rating;
  final String? comment;
  final DateTime? date;
  final Widget? header;
  final Widget? badge;
  final Widget? trailing;
  final Widget? footer;
  final VoidCallback? onTap;

  /// Highlights the card (current user's own review).
  final bool highlighted;

  /// Hides the author row, e.g. on the user's own "Mes notes" list.
  final bool showAuthor;

  const ReviewCard({
    super.key,
    required this.nickname,
    required this.rating,
    this.isPremium = false,
    this.comment,
    this.date,
    this.header,
    this.badge,
    this.trailing,
    this.footer,
    this.onTap,
    this.highlighted = false,
    this.showAuthor = true,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final shape = squircleBorder(
      radius: 36.r,
      side: BorderSide(
        color: highlighted ? primary.withValues(alpha: 0.4) : kBorderDefault,
      ),
    );

    return Material(
      color: highlighted ? primary.withValues(alpha: 0.05) : Colors.white,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(
          padding: EdgeInsets.all(30.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (header != null) ...[
                header!,
                SizedBox(height: 20.h),
              ],
              if (showAuthor) ...[
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ReviewerName(
                          nickname: nickname,
                          isPremium: isPremium,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      SizedBox(width: 16.w),
                      trailing!,
                    ],
                  ],
                ),
                SizedBox(height: 8.h),
              ],
              Row(
                children: [
                  StarRating(value: rating.toDouble(), size: 45.sp),
                  if (date != null) ...[
                    SizedBox(width: 16.w),
                    Text(
                      DateFormat.yMMMd('fr_FR').format(date!),
                      style: AppTextStyles.bodyRegular13
                          .copyWith(color: Colors.grey[500]),
                    ),
                  ],
                  if (badge != null) ...[
                    const Spacer(),
                    badge!,
                  ],
                ],
              ),
              if (comment != null && comment!.isNotEmpty) ...[
                SizedBox(height: 16.h),
                Text(
                  comment!,
                  style: AppTextStyles.bodyRegular15.copyWith(height: 1.3),
                ),
              ],
              if (footer != null) ...[
                SizedBox(height: 16.h),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
