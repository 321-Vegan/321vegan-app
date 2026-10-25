import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';

/// Search pill over the map. Tapping it opens the full-page search
/// (MapSearchPage); it shows the last chosen result, with a button to clear
/// it.
class MapSearchBar extends StatelessWidget {
  final String query;
  final String hintText;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const MapSearchBar({
    super.key,
    required this.query,
    required this.hintText,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = query.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Same height as the square action buttons next to it (map.dart),
        // so the whole top row reads as one line.
        height: 144.w,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: squircleBorder(
            radius: 42.r,
            side: const BorderSide(color: kBorderDefault, width: 1),
          ),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(width: 39.w),
            Image.asset(
              'lib/assets/images/icons/search-line.webp',
              width: 60.sp,
              height: 60.sp,
              color: Colors.grey[600],
              colorBlendMode: BlendMode.srcIn,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                hasText ? query : hintText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 42.sp,
                  color: hasText ? kTextPrimary : Colors.grey[500],
                ),
              ),
            ),
            if (hasText)
              GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child:
                      Icon(Icons.close, color: Colors.grey[500], size: 52.sp),
                ),
              )
            else
              SizedBox(width: 39.w),
          ],
        ),
      ),
    );
  }
}
