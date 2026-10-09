import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/scaner/brand_answer_dialog.dart';
import 'package:vegan_app/widgets/shared/app_card.dart';

/// Shared shell for scan-result cards (vegan / non-vegan / pending
/// validation): colored border, name/brand, status row, optional
/// [scores] and [extraRows].
class ScanResultCard extends StatelessWidget {
  final String name;
  final String brand;
  final Color accentColor;
  final Widget statusIcon;
  final String statusLabel;

  /// Extra detail appended after [statusLabel] (e.g. the reason a product
  /// was rejected) in a smaller size than the label itself.
  final String? statusDetail;
  final Widget? scores;
  final List<Widget> extraRows;

  /// Object-storage key of the brand's reply photo; shows an eye icon next
  /// to the brand that opens it when set.
  final String? brandAnswer;

  const ScanResultCard({
    super.key,
    required this.name,
    required this.brand,
    required this.accentColor,
    required this.statusIcon,
    required this.statusLabel,
    this.statusDetail,
    this.scores,
    this.extraRows = const [],
    this.brandAnswer,
  });

  /// Colored-circle status icon for states without a dedicated asset —
  /// matches the solid-check/solid-close assets' look.
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.baloo22,
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyRegular15
                            .copyWith(color: Colors.grey[500]),
                      ),
                    ),
                    if (brandAnswer != null) ...[
                      SizedBox(width: 12.w),
                      GestureDetector(
                        onTap: () =>
                            showBrandAnswerDialog(context, brandAnswer!),
                        behavior: HitTestBehavior.opaque,
                        child: Icon(Icons.chat_outlined,
                            size: 56.w, color: accentColor),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 16.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    statusIcon,
                    SizedBox(width: 16.w),
                    Expanded(
                      child: statusDetail == null
                          ? Text(
                              statusLabel,
                              style: AppTextStyles.bodyBold22
                                  .copyWith(color: accentColor),
                            )
                          : Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: statusLabel,
                                    style: AppTextStyles.bodyBold22
                                        .copyWith(color: accentColor),
                                  ),
                                  TextSpan(
                                    text: ' : $statusDetail',
                                    style: AppTextStyles.bodyRegular15
                                        .copyWith(color: accentColor),
                                  ),
                                ],
                              ),
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
          ),
          if (scores != null) ...[
            SizedBox(width: 16.w),
            scores!,
          ],
        ],
      ),
    );
  }
}
