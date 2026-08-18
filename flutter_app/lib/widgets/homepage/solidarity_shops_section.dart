import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/partners/partners.dart';
import '../../models/seasonal_theme.dart';
import '../../pages/app_pages/Partners/partners_page.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_card.dart';

/// Horizontal preview of the partner shops, with a "Voir plus" link to the
/// full list ([PartnersPage]). Replaces the former standalone "Promos" tab.
class SolidarityShopsSection extends StatefulWidget {
  final List<Partners> partners;

  /// Called when the user taps to see the full list, instead of the
  /// default push to [PartnersPage].
  final VoidCallback? onSeeAll;

  const SolidarityShopsSection({
    super.key,
    required this.partners,
    this.onSeeAll,
  });

  @override
  State<SolidarityShopsSection> createState() =>
      _SolidarityShopsSectionState();
}

class _SolidarityShopsSectionState extends State<SolidarityShopsSection> {
  late Set<int> _icedIndices;

  @override
  void initState() {
    super.initState();
    _icedIndices = _rollIcedIndices(widget.partners.length);
  }

  @override
  void didUpdateWidget(SolidarityShopsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only re-roll when the list itself changed — not on every rebuild
    // (e.g. the dashboard's once-a-minute savings tick), so cards don't
    // jump between iced/plain while the user is looking at them.
    if (oldWidget.partners.length != widget.partners.length) {
      _icedIndices = _rollIcedIndices(widget.partners.length);
    }
  }

  /// Card 1 (the second card) always gets the icicle decoration; after
  /// that, the next iced card is 1-3 cards further along, picked once per
  /// partner list rather than a fixed "every other card".
  Set<int> _rollIcedIndices(int length) {
    if (length < 2) return {};
    final random = Random();
    final indices = <int>{1};
    var i = 1;
    while (true) {
      i += 1 + random.nextInt(3);
      if (i >= length) break;
      indices.add(i);
    }
    return indices;
  }

  void _seeAll(BuildContext context) {
    if (widget.onSeeAll != null) {
      widget.onSeeAll!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PartnersPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partners = widget.partners;
    if (partners.isEmpty) return const SizedBox.shrink();

    final isWinter =
        Theme.of(context).extension<SeasonalTheme>()?.season == Season.winter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _seeAll(context),
          child: Row(
            children: [
              Text(
                'Boutiques solidaires',
                style: AppTextStyles.baloo22,
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
          // Default hard-edge clip on the viewport was cutting off the tip
          // of the winter icicle decoration, which pokes above the card
          // via a negative Positioned top.
          clipBehavior: Clip.none,
          child: IntrinsicHeight(
            child: Row(
              children: [
                for (int i = 0; i < partners.length; i++) ...[
                  if (i > 0) SizedBox(width: AppSpacing.item),
                  _ShopCard(
                    partner: partners[i],
                    showIceDecoration: isWinter && _icedIndices.contains(i),
                  ),
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
  final bool showIceDecoration;

  const _ShopCard({
    required this.partner,
    this.showIceDecoration = false,
  });

  Future<void> _openWebsite(BuildContext context) async {
    try {
      await launchUrl(Uri.parse(partner.url),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir le lien'),
          backgroundColor: kSemanticError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Figma spec: width hug 154, radius 20, stroke 1 Border/Default,
    // padding 20 (v) / 15 (h), gap 10 — all ×3 for ScreenUtil units.
    final card = SizedBox(
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
              style: AppTextStyles.baloo26
            ),
            Text(
              partner.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyRegular15.copyWith(color: Colors.grey[600]),
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
                  fontSize: 39.sp,
                  color: kAccentYellow,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTap: () => _openWebsite(context),
      child: !showIceDecoration
          ? card
          : Stack(
              clipBehavior: Clip.none,
              children: [
                card,
                // Icicles dripping from the card's top edge — clipped only
                // to the top-left corner (like the stat cards' winter
                // icicle) so square image corners don't peek out past that
                // squircle, while the rest hangs past the card's own
                // bounds instead of being boxed in by it.
                Positioned(
                  top: -20.h,
                  left: 140.w,
                  child: IgnorePointer(
                    child: ClipPath(
                      clipper: ShapeBorderClipper(
                        shape: squircleBorderOnly(topLeft: 60.r),
                      ),
                      child: Image.asset(
                        'lib/assets/themes/ice_10.webp',
                        width: 330.w,
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.topLeft,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
