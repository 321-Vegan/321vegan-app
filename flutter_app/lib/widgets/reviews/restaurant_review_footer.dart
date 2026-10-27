import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/restaurants/restaurant_review.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import '../restaurants/photo_viewer_page.dart';

/// Under a restaurant review's comment ([ReviewCard.footer]): the criteria
/// rated and the price per person, then its photos (opening the viewer).
/// The vegan choice isn't rated for a fully vegan place.
class RestaurantReviewFooter extends StatelessWidget {
  final RestaurantReview review;
  final bool isFullyVegan;

  const RestaurantReviewFooter({
    super.key,
    required this.review,
    required this.isFullyVegan,
  });

  /// The footer, or null when the review has nothing to show in it.
  static Widget? orNull(RestaurantReview review, {required bool isFullyVegan}) {
    final footer =
        RestaurantReviewFooter(review: review, isFullyVegan: isFullyVegan);
    return footer._isEmpty ? null : footer;
  }

  List<RestaurantCriterion> get _rated => RestaurantCriterion.all
      .where((c) =>
          !(isFullyVegan && c.key == 'choice') &&
          review.criteria.containsKey(c.field))
      .toList();

  bool get _isEmpty =>
      _rated.isEmpty && review.priceRange == null && review.photos.isEmpty;

  Widget _thumbnail(BuildContext context, int index, double size) {
    final photo = review.photos[index];
    return GestureDetector(
      onTap: () => PhotoViewerPage.open(context, review.photos, index),
      child: Stack(
        children: [
          ClipSmoothRect(
            radius: squircleRadius(24.r),
            child: CachedNetworkImage(
              imageUrl: photo.url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey[200]),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey[200],
                child: Icon(Icons.image, color: Colors.grey[400]),
              ),
            ),
          ),
          if (photo.isPending)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: ShapeDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: const StadiumBorder(),
                ),
                child: Text('En attente',
                    style: TextStyle(fontSize: 30.sp, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rated = _rated;
    final priceRange = review.priceRange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rated.isNotEmpty || priceRange != null)
          Wrap(
            spacing: 24.w,
            runSpacing: 8.h,
            children: [
              for (final c in rated)
                Text.rich(TextSpan(children: [
                  TextSpan(
                    text: '${c.label} ',
                    style: AppTextStyles.bodyRegular13
                        .copyWith(color: Colors.grey[600]),
                  ),
                  TextSpan(
                    text: '★ ${review.criteria[c.field]}',
                    style:
                        AppTextStyles.bodyBold13.copyWith(color: kAccentYellow),
                  ),
                ])),
              if (priceRange != null)
                Text.rich(TextSpan(children: [
                  TextSpan(
                    text: 'Prix ',
                    style: AppTextStyles.bodyRegular13
                        .copyWith(color: Colors.grey[600]),
                  ),
                  TextSpan(
                    text: RestaurantPriceRanges.label(priceRange),
                    style: AppTextStyles.bodyBold13,
                  ),
                ])),
            ],
          ),
        if (review.photos.isNotEmpty) ...[
          SizedBox(height: 16.h),
          Wrap(
            spacing: 12.w,
            runSpacing: 12.w,
            children: [
              for (var i = 0; i < review.photos.length; i++)
                _thumbnail(context, i, 160.w),
            ],
          ),
        ],
      ],
    );
  }
}
