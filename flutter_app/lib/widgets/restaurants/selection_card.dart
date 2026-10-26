import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/restaurants/restaurant_selection.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/app_card.dart';
import '../shared/tag_chip.dart';

/// Cover of a selection: the featured photos of its first restaurants, as
/// a 2×2 mosaic when there are 4, else the first one.
class SelectionCover extends StatelessWidget {
  final RestaurantSelection selection;
  final double size;

  const SelectionCover(
      {super.key, required this.selection, required this.size});

  Widget _placeholder(double side) => Container(
        width: side,
        height: side,
        color: Colors.grey[100],
        child: Icon(Icons.collections_bookmark_outlined,
            color: Colors.grey[400], size: side * 0.4),
      );

  Widget _photo(String url, double side) => CachedNetworkImage(
        imageUrl: url,
        width: side,
        height: side,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _placeholder(side),
      );

  @override
  Widget build(BuildContext context) {
    final photos = selection.coverPhotos;
    final Widget content;
    if (photos.length >= 4) {
      final side = (size - 3.w) / 2;
      content = SizedBox(
        width: size,
        height: size,
        child: Wrap(
          spacing: 3.w,
          runSpacing: 3.w,
          children: [for (final p in photos.take(4)) _photo(p.url, side)],
        ),
      );
    } else if (photos.isNotEmpty) {
      content = _photo(photos.first.url, size);
    } else {
      content = _placeholder(size);
    }
    return ClipSmoothRect(radius: squircleRadius(24.r), child: content);
  }
}

/// [RestaurantSelection.subtitle], then for the owner a paper plane with how
/// many people accepted it (when some did).
class SelectionSubtitle extends StatelessWidget {
  final RestaurantSelection selection;
  final int? maxLines;

  const SelectionSubtitle({super.key, required this.selection, this.maxLines});

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.bodyLight15;
    final accepted = selection.isOwner ? selection.acceptedCount ?? 0 : 0;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: selection.subtitle),
        if (accepted > 0) ...[
          const TextSpan(text: '  ·  '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(Icons.send_rounded,
                size: style.fontSize, color: style.color),
          ),
          TextSpan(text: ' $accepted'),
        ],
      ]),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// Selection in a list: cover, title, who made it and how many places.
/// A selection sent to the user and not answered yet gets the accept and
/// refuse buttons.
class SelectionCard extends StatelessWidget {
  final RestaurantSelection selection;
  final VoidCallback onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onRefuse;

  const SelectionCard({
    super.key,
    required this.selection,
    required this.onTap,
    this.onAccept,
    this.onRefuse,
  });

  @override
  Widget build(BuildContext context) {
    final s = selection;
    final showAnswer = s.isPending && onAccept != null && onRefuse != null;

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        radius: 36.r,
        padding: EdgeInsets.all(30.w),
        borderColor: s.isPending ? kAccentYellow : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SelectionCover(selection: s, size: 165.w),
                SizedBox(width: 30.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.baloo17),
                      SelectionSubtitle(selection: s, maxLines: 1),
                      if (s.isPending) ...[
                        SizedBox(height: 12.h),
                        TagChip(
                          label: s.isSeen ? 'À accepter' : 'Nouvelle',
                          color: kVeganOptionsOrange,
                          icon: Icons.mark_email_unread_outlined,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!showAnswer)
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
            if (showAnswer) ...[
              SizedBox(height: 30.h),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Refuser',
                      backgroundColor: Colors.white,
                      foregroundColor: kTextPrimary,
                      borderColor: kBorderDefault,
                      onPressed: onRefuse,
                    ),
                  ),
                  SizedBox(width: 24.w),
                  Expanded(
                    child: AppButton(
                      label: 'Accepter',
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      onPressed: onAccept,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
