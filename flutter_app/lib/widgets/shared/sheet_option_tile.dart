import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';

/// One choice of an actions bottom sheet (e.g. the "…" of a restaurant
/// page): tinted icon, title and detail, chevron. With [card], a link
/// standing on its own in a page (e.g. the Veganuary's links to the B12
/// page or the map), on a white bordered card like [AppCard].
class SheetOptionTile extends StatelessWidget {
  final IconData? icon;

  /// Instead of [icon]: an image of the app (e.g. the scan or Vegandex
  /// icon), tinted the same.
  final String? iconAsset;
  final String title;
  final String detail;
  final VoidCallback onTap;

  /// Defaults to the theme's primary color (e.g. red for a deletion).
  final Color? color;

  /// On a white card with the default border, instead of the sheet's
  /// background.
  final bool card;

  const SheetOptionTile({
    super.key,
    this.icon,
    this.iconAsset,
    required this.title,
    required this.detail,
    required this.onTap,
    this.color,
    this.card = false,
  }) : assert((icon == null) != (iconAsset == null),
            'Either an icon or an iconAsset');

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    final cardShape = squircleBorder(
      radius: 60.r,
      side: const BorderSide(color: kBorderDefault),
    );
    final tile = InkWell(
      onTap: onTap,
      customBorder: card ? cardShape : squircleBorder(radius: 30.r),
      child: Padding(
        padding: card
            ? EdgeInsets.all(36.w)
            : EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
        child: Row(
          children: [
            Container(
              width: 110.w,
              height: 110.w,
              decoration: ShapeDecoration(
                color: tint.withValues(alpha: 0.1),
                shape: squircleBorder(radius: 30.r),
              ),
              child: iconAsset == null
                  ? Icon(icon, color: tint, size: 56.sp)
                  : Padding(
                      padding: EdgeInsets.all(27.w),
                      child: Image.asset(iconAsset!,
                          color: tint, colorBlendMode: BlendMode.srcIn),
                    ),
            ),
            SizedBox(width: 30.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyBold15),
                  Text(detail,
                      style: AppTextStyles.bodyRegular13
                          .copyWith(color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
    if (!card) return tile;
    return Material(
      color: Colors.white,
      shape: cardShape,
      clipBehavior: Clip.antiAlias,
      child: tile,
    );
  }
}
