import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/partners/partners.dart';
import '../../pages/app_pages/Partners/partners_page.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_card.dart';

/// Horizontal preview of the partner shops, with a "Voir plus" link to the
/// full list ([PartnersPage]). Replaces the former standalone "Promos" tab.
class SolidarityShopsSection extends StatelessWidget {
  final List<Partners> partners;

  /// Called when the user taps to see the full list, instead of the
  /// default push to [PartnersPage].
  final VoidCallback? onSeeAll;

  const SolidarityShopsSection({
    super.key,
    required this.partners,
    this.onSeeAll,
  });

  void _seeAll(BuildContext context) {
    if (onSeeAll != null) {
      onSeeAll!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PartnersPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (partners.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _seeAll(context),
          child: Row(
            children: [
              Text(
                'Boutiques solidaires',
                style: AppTextStyles.sectionTitle,
              ),
              const Spacer(),
              Icon(Icons.arrow_forward, size: 54.sp, color: Colors.grey[600]),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.afterTitle),
        // IntrinsicHeight sizes the row to its tallest card's natural
        // content height ("hug" in Figma), so it can never overflow
        // regardless of font metrics or text length.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              children: [
                for (int i = 0; i < partners.length; i++) ...[
                  if (i > 0) SizedBox(width: 30.w),
                  _ShopCard(partner: partners[i]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShopCard extends StatelessWidget {
  final Partners partner;

  const _ShopCard({required this.partner});

  Future<void> _openWebsite(BuildContext context) async {
    try {
      await launchUrl(Uri.parse(partner.url),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir le lien'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Figma spec: width hug 154, radius 20, stroke 1 Border/Default,
    // padding 20 (v) / 15 (h), gap 10 — all ×3 for ScreenUtil units.
    return GestureDetector(
      onTap: () => _openWebsite(context),
      child: SizedBox(
        width: 462.w,
        child: AppCard(
          padding: EdgeInsets.symmetric(horizontal: 45.w, vertical: 60.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                partner.discountText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 50.sp,
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary,
                ),
              ),
              Text(
                partner.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 40.sp, color: Colors.grey[600]),
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: ShapeDecoration(
                  color: kAccentYellow.withValues(alpha: 0.15),
                  shape: squircleBorder(radius: 20.r),
                ),
                child: Text(
                  partner.discountCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 40.sp,
                    color: kAccentYellow,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
