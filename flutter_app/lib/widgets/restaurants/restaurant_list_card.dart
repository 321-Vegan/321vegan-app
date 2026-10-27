import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/restaurants/restaurant.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_card.dart';

/// Restaurant in a list: featured photo, name, city and [badges] (status
/// chips...), an optional [trailing] action, then the optional [footer]
/// across the card (e.g. a note).
class RestaurantListCard extends StatelessWidget {
  final Restaurant restaurant;
  final List<Widget> badges;

  /// Null when there is nothing to open (e.g. a restaurant refused).
  final VoidCallback? onTap;
  final Widget? footer;

  /// At the end of the row, e.g. a button acting on the restaurant.
  final Widget? trailing;

  const RestaurantListCard({
    super.key,
    required this.restaurant,
    required this.badges,
    this.onTap,
    this.footer,
    this.trailing,
  });

  static Widget _placeholder() => Container(
        width: 165.w,
        height: 165.w,
        color: Colors.grey[100],
        child: Icon(Icons.restaurant, color: Colors.grey[400]),
      );

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        ClipSmoothRect(
          radius: squircleRadius(24.r),
          child: restaurant.featuredPhoto != null
              ? CachedNetworkImage(
                  imageUrl: restaurant.featuredPhoto!.url,
                  width: 165.w,
                  height: 165.w,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
        SizedBox(width: 30.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(restaurant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.baloo17),
              if (restaurant.city != null)
                Text(restaurant.city!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLight15),
              SizedBox(height: 12.h),
              Wrap(spacing: 12.w, runSpacing: 12.h, children: badges),
            ],
          ),
        ),
        if (trailing != null) ...[
          SizedBox(width: 12.w),
          trailing!,
        ],
      ],
    );
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        radius: 36.r,
        padding: EdgeInsets.all(30.w),
        child: footer == null
            ? row
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [row, SizedBox(height: 24.h), footer!],
              ),
      ),
    );
  }
}
