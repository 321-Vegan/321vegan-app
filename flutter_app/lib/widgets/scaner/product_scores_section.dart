import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/models/product_scores.dart';
import 'package:vegan_app/pages/app_pages/Profile/subscription_page.dart';
import 'package:vegan_app/services/open_food_facts_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/widgets/scaner/score_badge.dart';
import 'package:vegan_app/widgets/shared/link_row.dart';

/// Shows Nutriscore + Green-score inline in a scan-result card.
///
/// - [enabled]: controlled by the parent (scan settings). When false, renders nothing.
/// - [isSubscribed]: if true, fetches and shows scores with an info dialog.
/// - [paywalled]: when true and not subscribed, non-subscribers get a few
///   free reveals per week; once exhausted, shows a blurred "Débloquer"
///   paywall overlay. When false, scores are shown unlocked to everyone
///   (e.g. on non-vegan results, where there's nothing to gate).
/// - [onDisable]: called when the user taps "Désactiver" in the info dialog.
class ProductScoresSection extends StatefulWidget {
  final String barcode;
  final bool isSubscribed;
  final bool enabled;
  final bool paywalled;
  final VoidCallback? onDisable;

  const ProductScoresSection({
    super.key,
    required this.barcode,
    required this.isSubscribed,
    this.enabled = true,
    this.paywalled = true,
    this.onDisable,
  });

  @override
  State<ProductScoresSection> createState() => _ProductScoresSectionState();
}

class _ProductScoresSectionState extends State<ProductScoresSection> {
  ProductScores? _scores;
  bool _loading = true;
  // Scores visible to a non-subscriber (free reveal granted, or no scores
  // found — nothing to paywall in that case)
  bool _unlocked = false;

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
    if (widget.isSubscribed || !widget.paywalled) {
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
    final unlocked =
        widget.isSubscribed || !widget.paywalled || _unlocked || _loading;
    return unlocked ? _buildScores() : _buildLockedOverlay();
  }

  Widget _buildScores() {
    if (_loading) {
      return SizedBox(
        width: 48.w,
        height: 48.w,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return GestureDetector(
      onTap: _showInfoDialog,
      child: ScoreBadges(
        nutriscoreGrade: _scores?.nutriscoreGrade,
        ecoscoreGrade: _scores?.ecoscoreGrade,
        scale: 0.75,
        direction: Axis.vertical,
      ),
    );
  }

  /// Blurred fake badges with a "Débloquer" pill overlaid on top — same
  /// pattern as the scan-history page's score paywall.
  Widget _buildLockedOverlay() {
    return GestureDetector(
      onTap: _openSubscriptionPage,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: const IgnorePointer(
              child: ScoreBadges(
                nutriscoreGrade: 'a',
                ecoscoreGrade: 'a-plus',
                scale: 0.75,
                direction: Axis.vertical,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            decoration: ShapeDecoration(
              color: kAccentYellow,
              shape: squircleBorder(radius: 30.r),
            ),
            child: Text(
              'Débloquer',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
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
