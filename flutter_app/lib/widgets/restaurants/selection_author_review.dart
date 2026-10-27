import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/restaurants/restaurant.dart';
import '../../models/restaurants/restaurant_review.dart';
import '../../services/restaurant_api_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../reviews/restaurant_review_footer.dart';
import '../reviews/review_card.dart';
import '../reviews/star_rating.dart';
import '../shared/bottom_sheet_shell.dart';

/// The rating a selection's author gave a place, as stars on a white pill.
/// Tapping it shows their whole review.
class AuthorRatingPill extends StatelessWidget {
  final int rating;
  final VoidCallback? onTap;

  const AuthorRatingPill({super.key, required this.rating, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: 'Note de l\'auteur : $rating sur 5',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 9.h),
          decoration: const ShapeDecoration(
            color: Colors.white,
            shape: StadiumBorder(side: BorderSide(color: kBorderDefault)),
          ),
          child: StarRating(value: rating.toDouble(), size: 48.sp),
        ),
      ),
    );
  }
}

/// The review [authorNickname] (null for the user) left on [restaurant],
/// loaded from its id, in a bottom sheet.
Future<void> showAuthorReviewSheet(
  BuildContext context, {
  required int reviewId,
  required Restaurant restaurant,
  String? authorNickname,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AuthorReviewSheet(
      reviewId: reviewId,
      restaurant: restaurant,
      authorNickname: authorNickname,
    ),
  );
}

class _AuthorReviewSheet extends StatefulWidget {
  final int reviewId;
  final Restaurant restaurant;
  final String? authorNickname;

  const _AuthorReviewSheet({
    required this.reviewId,
    required this.restaurant,
    this.authorNickname,
  });

  @override
  State<_AuthorReviewSheet> createState() => _AuthorReviewSheetState();
}

class _AuthorReviewSheetState extends State<_AuthorReviewSheet> {
  late final Future<RestaurantReview?> _review =
      RestaurantApiService.getReview(widget.reviewId);

  @override
  Widget build(BuildContext context) {
    final author = widget.authorNickname;
    return BottomSheetShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(author == null ? 'Votre avis' : 'L\'avis de $author',
                    style: AppTextStyles.baloo22),
                Text(widget.restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLight15),
              ],
            ),
          ),
          SizedBox(height: 30.h),
          FutureBuilder<RestaurantReview?>(
            future: _review,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 60.h),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              final review = snapshot.data;
              if (review == null) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 60.h),
                  child: Center(
                    child: Text(
                      'Impossible de charger l\'avis, réessayez.',
                      style: AppTextStyles.bodyRegular15
                          .copyWith(color: kSemanticError),
                    ),
                  ),
                );
              }
              return ReviewCard(
                nickname: review.userNickname,
                isPremium: review.userIsPremium,
                rating: review.rating,
                comment: review.comment,
                date: review.createdAt,
                footer: RestaurantReviewFooter.orNull(review,
                    isFullyVegan: widget.restaurant.isFullyVegan),
              );
            },
          ),
        ],
      ),
    );
  }
}
