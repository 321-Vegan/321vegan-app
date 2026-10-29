import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/restaurants/restaurant.dart';
import '../../themes/app_colors.dart';
import '../shared/photo_tile.dart';
import 'photo_viewer_page.dart';

/// Thumbnail of [photos] at [index], marked "En attente" while moderated;
/// tapping it opens the gallery there.
class RestaurantPhotoThumbnail extends StatelessWidget {
  final List<RestaurantPhoto> photos;
  final int index;
  final double size;

  /// Rating of the review the photo comes from, shown over it.
  final int? rating;

  /// Instead of opening the gallery (e.g. shows the review the photo comes
  /// from).
  final VoidCallback? onTap;

  const RestaurantPhotoThumbnail({
    super.key,
    required this.photos,
    required this.index,
    required this.size,
    this.rating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final photo = photos[index];
    return PhotoTile(
      image: CachedNetworkImageProvider(photo.url),
      size: size,
      radius: 24.r,
      onTap: onTap ?? () => PhotoViewerPage.open(context, photos, index),
      overlays: [
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
        if (rating != null)
          Positioned(
            right: 6,
            bottom: 6,
            child: Semantics(
              label: 'Avis : $rating sur 5',
              child: ExcludeSemantics(
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                  decoration: ShapeDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded,
                          size: 34.sp, color: kAccentYellow),
                      SizedBox(width: 4.w),
                      Text('$rating',
                          style: TextStyle(
                              fontSize: 30.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
