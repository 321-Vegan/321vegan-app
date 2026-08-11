import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/models/product_scores.dart';
import 'package:vegan_app/pages/app_pages/Profile/subscription_page.dart';
import 'package:vegan_app/services/open_food_facts_service.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/widgets/scaner/score_badge.dart';
import 'package:vegan_app/widgets/shared/link_row.dart';

/// Shows Nutriscore + Green-score for vegan products
///
/// - [enabled]: controlled by the parent (scan settings). When false, renders nothing.
/// - [isSubscribed]: if true, fetches and shows scores with an info dialog.
///   If false, non-subscribers get a few free reveals per week (with a
///   remaining-count chip); once exhausted, shows a blurred paywall overlay.
/// - [onDisable]: called when the user taps "Désactiver" in the info dialog.
class ProductScoresSection extends StatefulWidget {
  final String barcode;
  final bool isSubscribed;
  final bool enabled;
  final VoidCallback? onDisable;

  const ProductScoresSection({
    super.key,
    required this.barcode,
    required this.isSubscribed,
    this.enabled = true,
    this.onDisable,
  });

  /// Height reserved above the badges for the free-reveal chip, so the badges
  /// keep the same screen position whether or not the chip is shown. The
  /// parent anchors this section by its bottom, so the strip grows upward
  /// into the camera area without moving the badges.
  static double get extraHeaderHeight => 88.h;

  @override
  State<ProductScoresSection> createState() => _ProductScoresSectionState();
}

class _ProductScoresSectionState extends State<ProductScoresSection> {
  ProductScores? _scores;
  bool _loading = true;
  // Scores visible to a non-subscriber (free reveal granted, or no scores
  // found — nothing to paywall in that case)
  bool _unlocked = false;
  // Whether a free reveal was consumed for this product (drives the chip)
  bool _showChip = false;
  int _freeRevealsLeft = 0;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _initForBarcode();
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void didUpdateWidget(ProductScoresSection old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) return;

    if (old.barcode != widget.barcode) {
      setState(() {
        _scores = null;
        _unlocked = false;
        _showChip = false;
        _loading = true;
      });
      _initForBarcode();
    }
    if (!old.isSubscribed && widget.isSubscribed && _scores == null) {
      setState(() => _loading = true);
      _fetchScores();
    }
    // Fetch if scores were just enabled
    if (!old.enabled && widget.enabled && _scores == null) {
      setState(() => _loading = true);
      _initForBarcode();
    }
  }

  /// Scores cached on a past scan-history entry for this barcode, if any,
  /// so a re-scan of the same product doesn't hit OpenFoodFacts again.
  Future<ProductScores> _getScores(String barcode) async {
    final cached = await PreferencesHelper.getCachedScores(barcode);
    if (cached != null) return cached;
    return OpenFoodFactsService.fetchScores(barcode);
  }

  Future<void> _initForBarcode() async {
    if (widget.isSubscribed) {
      _fetchScores();
      return;
    }
    // Fetch first: products without any score don't consume a free reveal
    // and there is nothing to paywall.
    final scores = await _getScores(widget.barcode);
    if (!mounted) return;
    final hasScores =
        scores.nutriscoreGrade != null || scores.ecoscoreGrade != null;
    if (!hasScores) {
      setState(() {
        _scores = scores;
        _unlocked = true;
        _showChip = false;
        _loading = false;
      });
      return;
    }
    final remaining =
        await PreferencesHelper.useFreeScoreReveal(widget.barcode);
    if (!mounted) return;
    setState(() {
      _scores = scores;
      _unlocked = remaining != null;
      _showChip = remaining != null;
      _freeRevealsLeft = remaining ?? 0;
      _loading = false;
    });
  }

  Future<void> _fetchScores() async {
    final scores = await _getScores(widget.barcode);
    if (mounted) {
      setState(() {
        _scores = scores;
        _loading = false;
      });
    }
  }

  void _openSubscriptionPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionPage()),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => _ScoresInfoDialog(
        onDisable: () {
          Navigator.of(context).pop();
          widget.onDisable?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return Center(
      child: widget.isSubscribed || _unlocked || _loading
          ? _buildScores()
          : _buildLockedOverlay(),
    );
  }

  Widget _buildScores() {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final badges = GestureDetector(
      onTap: _showInfoDialog,
      child: ScoreBadges(
        nutriscoreGrade: _scores?.nutriscoreGrade,
        ecoscoreGrade: _scores?.ecoscoreGrade,
      ),
    );
    if (widget.isSubscribed) return badges;
    // Chip goes in the reserved strip above the badges: the product info card
    // painted after this section in the scan stack covers anything below them.
    // The strip is kept even without the chip so the badges don't move.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: ProductScoresSection.extraHeaderHeight,
          child: _showChip
              ? Align(
                  alignment: Alignment.topCenter,
                  child: _buildFreeRevealChip(),
                )
              : null,
        ),
        badges,
      ],
    );
  }

  Widget _buildFreeRevealChip() {
    final primary = Theme.of(context).colorScheme.primary;
    final label = _freeRevealsLeft == 0
        ? 'Dernier affichage scores gratuit de la semaine'
        : _freeRevealsLeft == 1
            ? '1 affichage score gratuit restant cette semaine'
            : '$_freeRevealsLeft affichage score gratuits restants cette semaine';
    return GestureDetector(
      onTap: _openSubscriptionPage,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: ShapeDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: squircleBorder(
            radius: 12.r,
            side: BorderSide(color: primary.withValues(alpha: 0.4)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_outlined, size: 34.sp, color: primary),
            SizedBox(width: 8.w),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedOverlay() {
    return Padding(
      // Same reserved strip as the free-reveal chip, so the blurred badges
      // stay aligned with the real ones when the parent raises its anchor.
      padding: EdgeInsets.only(top: ProductScoresSection.extraHeaderHeight),
      child: GestureDetector(
        onTap: _openSubscriptionPage,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: const IgnorePointer(
                child:
                    ScoreBadges(nutriscoreGrade: 'a', ecoscoreGrade: 'a-plus'),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              decoration: ShapeDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: squircleBorder(
                  radius: 12.r,
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 40.sp,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: Text(
                          'Affichage scores gratuits épuisés',
                          style: TextStyle(
                            fontSize: 36.sp,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Passez en illimité pour voir tous les scores',
                    style: TextStyle(
                      fontSize: 32.sp,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _ScoresInfoDialog extends StatelessWidget {
  final VoidCallback onDisable;

  const _ScoresInfoDialog({required this.onDisable});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Dialog(
      shape: squircleBorder(radius: 24.r),
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.info_outline, size: 80.sp, color: primary),
            ),
            SizedBox(height: 20.h),
            Text(
              'Nutriscore & Green-score®',
              style: TextStyle(
                fontSize: 52.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'Ces données sont fournies par OpenFoodFacts, une base de données alimentaire collaborative et open source. Elles peuvent être incomplètes ou absentes pour certains produits.',
              style: TextStyle(
                fontSize: 38.sp,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            LinkRow(
              icon: Icons.open_in_new,
              label: 'openfoodfacts.org',
              url: 'https://world.openfoodfacts.org',
              color: primary,
            ),
            SizedBox(height: 6.h),
            LinkRow(
              icon: Icons.open_in_new,
              label: 'En savoir plus sur le Nutriscore',
              url: 'https://fr.openfoodfacts.org/nutriscore',
              color: primary,
            ),
            SizedBox(height: 6.h),
            LinkRow(
              icon: Icons.open_in_new,
              label: 'En savoir plus sur le Green-score®',
              url: 'https://fr.openfoodfacts.org/green-score',
              color: primary,
            ),
            SizedBox(height: 28.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 18.h),
                  shape: squircleBorder(radius: 14.r),
                  elevation: 0,
                ),
                child: Text(
                  'Fermer',
                  style: TextStyle(
                    fontSize: 42.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onDisable,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade500,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                ),
                child: Text(
                  'Désactiver les scores',
                  style: TextStyle(fontSize: 36.sp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
