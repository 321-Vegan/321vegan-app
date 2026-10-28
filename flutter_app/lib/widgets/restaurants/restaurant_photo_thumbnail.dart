import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/restaurants/restaurant.dart';
import '../shared/photo_tile.dart';
import 'photo_viewer_page.dart';

/// Thumbnail of [photos] at [index], marked "En attente" while moderated;
/// tapping it opens the gallery there.
class RestaurantPhotoThumbnail extends StatelessWidget {
  final List<RestaurantPhoto> photos;
  final int index;
  final double size;

  const RestaurantPhotoThumbnail({
    super.key,
    required this.photos,
    required this.index,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final photo = photos[index];
    return PhotoTile(
      image: CachedNetworkImageProvider(photo.url),
      size: size,
      radius: 24.r,
      onTap: () => PhotoViewerPage.open(context, photos, index),
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
      ],
    );
  }
}
