import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/shared/app_card.dart';

/// Shared shell for scan-result cards (vegan / non-vegan / pending
/// validation): an [AppCard] with a colored border matching [accentColor],
/// product name + brand on the left, optional [scores] (Nutri-Score /
/// Green-score) top-right, a status row (icon + colored label) below, and
/// optional [extraRows] for boycott/biodynamic warnings or extra context.
class ScanResultCard extends StatelessWidget {
  final String name;
  final String brand;
  final Color accentColor;
  final Widget statusIcon;
  final String statusLabel;
  final Widget? scores;
  final List<Widget> extraRows;

  const ScanResultCard({
    super.key,
    required this.name,
    required this.brand,
    required this.accentColor,
    required this.statusIcon,
    required this.statusLabel,
    this.scores,
    this.extraRows = const [],
  });

  /// Colored-circle status icon for states without a dedicated asset
  /// (pending validation) — same visual language as the solid-check/
  /// solid-close assets (colored circle + white glyph).
  static Widget circleIcon(IconData icon, Color color, {double? size}) {
    final s = size ?? 64.w;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: s * 0.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 60.r,
      borderColor: accentColor,
      borderWidth: 3,
      padding: EdgeInsets.all(45.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.baloo22,
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyRegular15
                          .copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              if (scores != null) ...[
                SizedBox(width: 16.w),
                scores!,
              ],
            ],
          ),
          SizedBox(height: 30.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              statusIcon,
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  statusLabel,
                  style: AppTextStyles.bodyBold15.copyWith(color: accentColor),
                ),
              ),
            ],
          ),
          for (final row in extraRows) ...[
            SizedBox(height: 16.h),
            row,
          ],
        ],
      ),
    );
  }
}
