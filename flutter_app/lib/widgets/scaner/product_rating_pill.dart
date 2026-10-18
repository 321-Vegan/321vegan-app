import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/widgets/reviews/product_ratings_sheet.dart';
import 'package:vegan_app/widgets/reviews/star_rating.dart';
import 'package:vegan_app/widgets/shared/tag_chip.dart';

/// Tag with a product's average rating as stars + "4,3 (12 avis)", or
/// "Pas encore de note". Tapping it opens the ratings sheet.
///
/// Display only: the caller provides the rating (fetched once at scan time
/// and cached on the scan history entry, like the Nutri-Score) and is told
/// through [onSheetClosed] to refresh it, since the user may have rated.
class ProductRatingPill extends StatelessWidget {
  final String barcode;
  final String? productName;
  final String? brandName;

  /// Approved ratings average and count; null while unknown.
  final double? average;
  final int? count;

  /// When the rating is unknown: hide the tag (scan result, still loading
  /// or offline) or show a "Noter ce produit" tag (scan history entry
  /// scanned before ratings were cached).
  final bool hideWhenUnknown;

  /// Pause/resume the camera around the sheet, like [ReportErrorButton].
  final VoidCallback? onScannerStop;
  final VoidCallback? onScannerStart;
  final VoidCallback? onSheetClosed;

  const ProductRatingPill({
    super.key,
    required this.barcode,
    this.productName,
    this.brandName,
    this.average,
    this.count,
    this.hideWhenUnknown = true,
    this.onScannerStop,
    this.onScannerStart,
    this.onSheetClosed,
  });

  Future<void> _openSheet(BuildContext context) async {
    onScannerStop?.call();
    await showProductRatingsSheet(
      context,
      ean: barcode,
      productName: productName,
      brandName: brandName,
    );
    onScannerStart?.call();
    onSheetClosed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    final average = this.average;

    if (count == null || average == null) {
      if (hideWhenUnknown) return const SizedBox.shrink();
      return _outlinedTag(context, 'Noter ce produit');
    }
    if (count == 0) return _outlinedTag(context, 'Pas encore de note');

    return TagChip(
      leading: StarRating(value: average, size: 36.sp),
      label: '${formatRatingAverage(average)} (${formatRatingCount(count)})',
      color: kAccentYellow,
      backgroundColor: kSecondaryTag,
      onTap: () => _openSheet(context),
    );
  }

  Widget _outlinedTag(BuildContext context, String label) {
    return TagChip(
      icon: Icons.star_outline_rounded,
      label: label,
      color: kAccentYellow,
      backgroundColor: kSecondaryTag,
      onTap: () => _openSheet(context),
    );
  }
}
