import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/models/boycott_data.dart';
import 'package:vegan_app/models/product_scores.dart';
import 'package:vegan_app/models/scan_result.dart';
import 'package:vegan_app/pages/app_pages/Profile/subscription_page.dart';
import 'package:vegan_app/pages/app_pages/Scan/product_info_helper.dart';
import 'package:vegan_app/services/subscription_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/scaner/info_modal.dart';
import 'package:vegan_app/widgets/shared/app_background.dart';
import 'package:vegan_app/widgets/shared/info_box.dart';

/// Full-screen page listing every scanned product, grouped by day.
/// Pushed from the Scan page and from Settings ("Scannés" row).
class ScanHistoryPage extends StatefulWidget {
  final List<Map<String, dynamic>> scanHistory;

  const ScanHistoryPage({super.key, required this.scanHistory});

  @override
  State<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends State<ScanHistoryPage> {
  late List<Map<String, dynamic>> _history;
  bool _showBoycott = true;

  static const _nutriAssets = {
    'a': 'lib/assets/images/nutri-eco-scores/nutriA.webp',
    'b': 'lib/assets/images/nutri-eco-scores/nutriB.webp',
    'c': 'lib/assets/images/nutri-eco-scores/nutriC.webp',
    'd': 'lib/assets/images/nutri-eco-scores/nutriD.webp',
    'e': 'lib/assets/images/nutri-eco-scores/nutriE.webp',
  };

  static const _ecoAssets = {
    'a-plus': 'lib/assets/images/nutri-eco-scores/green-score-a-plus.webp',
    'a': 'lib/assets/images/nutri-eco-scores/green-score-a.webp',
    'b': 'lib/assets/images/nutri-eco-scores/green-score-b.webp',
    'c': 'lib/assets/images/nutri-eco-scores/green-score-c.webp',
    'd': 'lib/assets/images/nutri-eco-scores/green-score-d.webp',
    'e': 'lib/assets/images/nutri-eco-scores/green-score-e.webp',
    'f': 'lib/assets/images/nutri-eco-scores/green-score-f.webp',
  };

  @override
  void initState() {
    super.initState();
    _history = List<Map<String, dynamic>>.from(widget.scanHistory);
    _loadBoycottPref();
  }

  Future<void> _loadBoycottPref() async {
    final value = await PreferencesHelper.getShowBoycottPref();
    if (mounted) setState(() => _showBoycott = value);
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: squircleBorder(radius: 42.r),
        child: Padding(
          padding: EdgeInsets.fromLTRB(40.w, 48.h, 40.w, 40.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(24.w),
                decoration: const BoxDecoration(
                  color: kSecondaryTag,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline,
                    size: 80.sp, color: kAccentYellow),
              ),
              SizedBox(height: 28.h),
              Text(
                'Effacer l\'historique ?',
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: 50.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                  color: kTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text(
                'Tous les produits scannés seront supprimés de votre historique. Cette action est irréversible.',
                style: TextStyle(fontSize: 38.sp, color: Colors.grey[600], height: 1.4),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 36.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: const BorderSide(color: kBorderDefault),
                        padding: EdgeInsets.symmetric(vertical: 18.h),
                        shape: squircleBorder(radius: 42.r),
                      ),
                      child: Text(
                        'Annuler',
                        style: TextStyle(fontSize: 40.sp, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSemanticError,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 18.h),
                        shape: squircleBorder(radius: 42.r),
                      ),
                      child: Text(
                        'Effacer',
                        style: TextStyle(fontSize: 40.sp, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    await PreferencesHelper.clearScanHistory();
    if (mounted) setState(() => _history.clear());
  }

  /// Scores are cached on the history entry at scan time (see
  /// [PreferencesHelper.cacheScanScores]) — the history page never hits
  /// OpenFoodFacts itself; entries scanned before that existed simply show
  /// no score badge.
  ProductScores _cachedScores(Map<String, dynamic> item) => ProductScores(
        nutriscoreGrade: item['nutriscore'] as String?,
        ecoscoreGrade: item['ecoscore'] as String?,
      );

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Produits scannés',
            style: AppTextStyles.baloo22,
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kTextPrimary,
          actions: [
            if (_history.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(right: 24.w),
                child: GestureDetector(
                  onTap: _confirmClearHistory,
                  // Same "surface icon button" spec as the Dashboard header
                  // (47×47, radius 12, white, subtle shadow — ×3 units).
                  child: Container(
                    width: 141.w,
                    height: 141.w,
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: squircleBorder(radius: 36.r),
                      shadows: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.delete_outline,
                        color: Colors.grey[700], size: 72.sp),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: _history.isEmpty ? _buildEmptyState() : _buildList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 60.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'lib/assets/images/sun-off.webp',
              width: 220.w,
              height: 220.w,
            ),
            SizedBox(height: 36.h),
            Text(
              'Aucun produit à afficher',
              style: TextStyle(
                fontFamily: 'Baloo2',
                fontSize: 52.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
                color: kTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'Scannez des produits pour enrichir cette liste.',
              style: TextStyle(fontSize: 40.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 48.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentYellow,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  elevation: 0,
                  shape: squircleBorder(radius: 42.r),
                ),
                child: Text(
                  'Scanner un produit',
                  style: TextStyle(fontSize: 42.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(48.w, 12.h, 48.w, 32.h),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        final barcode = item['barcode'] as String;
        final date = DateTime.parse(item['timestamp'] as String).toLocal();
        final isFirstOfDay = index == 0 ||
            !_isSameDay(
                date,
                DateTime.parse(_history[index - 1]['timestamp'] as String)
                    .toLocal());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFirstOfDay) ...[
              if (index != 0) SizedBox(height: 24.h),
              Padding(
                padding: EdgeInsets.only(bottom: 20.h),
                child: Text(
                  DateFormat('d MMMM yyyy', 'fr_FR').format(date),
                  style: AppTextStyles.baloo22,
                ),
              ),
            ],
            Padding(
              padding: EdgeInsets.only(bottom: 20.h),
              // Name/brand/status come from the local product DB (fast,
              // offline); scores come straight from the cached entry —
              // neither hits the network from this page.
              child: FutureBuilder<ScanResult>(
                future: ProductInfoHelper.getProductInfo(barcode),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return _buildLoadingCard();
                  }
                  final product = snapshot.hasData && !snapshot.hasError
                      ? snapshot.data!
                      : ScanResult(
                          code: barcode,
                          name: 'Erreur',
                          brand: 'Impossible de charger le produit',
                          status: ScanStatus.unknown,
                        );
                  return _buildProductCard(
                    barcode: barcode,
                    product: product,
                    scores: _cachedScores(item),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 180.w,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 36.r,
          side: const BorderSide(color: kBorderDefault),
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  ({IconData icon, Color color, String label}) _statusInfo(
      ScanStatus status, String? problem) {
    switch (status) {
      case ScanStatus.vegan:
        return (icon: Icons.check_circle, color: kSemanticSuccess, label: 'Végane');
      case ScanStatus.notVegan:
        final reason = (problem != null && problem.isNotEmpty) ? ' : $problem' : '';
        return (icon: Icons.cancel, color: kSemanticError, label: 'Non-végane$reason');
      case ScanStatus.pending:
        return (
          icon: Icons.schedule,
          color: kAccentYellow,
          label: 'En attente de vérification'
        );
      case ScanStatus.notFound:
        return (icon: Icons.help_outline, color: Colors.grey, label: 'Introuvable');
      case ScanStatus.alreadyScanned:
        return (
          icon: Icons.info_outline,
          color: Colors.grey,
          label: 'Produit inconnu, déjà signalé'
        );
      case ScanStatus.unknown:
        return (icon: Icons.help_outline, color: Colors.grey, label: 'Statut inconnu');
    }
  }

  /// Real cached badges for subscribers; for everyone else, a blurred
  /// placeholder (real scores if cached, generic ones otherwise) with a
  /// "Débloquer" pill that opens the subscription page — same pattern as
  /// the live scan's score paywall.
  Widget _buildScoreColumn(ProductScores scores) {
    if (SubscriptionService.isSubscribed) {
      if (!scores.hasNutriscore && !scores.hasEcoscore) {
        return const SizedBox.shrink();
      }
      return _scoreImages(scores);
    }

    final displayScores = (scores.hasNutriscore || scores.hasEcoscore)
        ? scores
        : const ProductScores(nutriscoreGrade: 'a', ecoscoreGrade: 'a-plus');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionPage()),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: IgnorePointer(child: _scoreImages(displayScores)),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 14.h),
            decoration: ShapeDecoration(
              color: kAccentYellow,
              shape: squircleBorder(radius: 30.r),
            ),
            child: Text(
              'Débloquer',
              style: TextStyle(
                fontSize: 36.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreImages(ProductScores scores) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (scores.hasNutriscore)
          Image.asset(_nutriAssets[scores.nutriscoreGrade]!,
              width: 200.w, fit: BoxFit.contain),
        if (scores.hasNutriscore && scores.hasEcoscore) SizedBox(height: 10.h),
        if (scores.hasEcoscore)
          Image.asset(_ecoAssets[scores.ecoscoreGrade]!,
              width: 200.w, fit: BoxFit.contain),
      ],
    );
  }

  Widget _buildProductCard({
    required String barcode,
    required ScanResult product,
    required ProductScores scores,
  }) {
    final name = product.name.isNotEmpty ? product.name : product.code;
    final brand = product.brand;
    final isEan8 = barcode.length == 8;
    final BoycottMatch? boycottMatch =
        (brand.isNotEmpty && brand != 'Marque inconnue')
            ? BoycottData.findBrand(brand)
            : null;
    final isBoycotted = boycottMatch != null && _showBoycott;
    final status = _statusInfo(product.status, product.problem);

    return Container(
      padding: EdgeInsets.all(30.w),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 36.r,
          side: const BorderSide(color: kBorderDefault),
        ),
      ),
      child: Column(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 44.sp,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary,
                      ),
                    ),
                    if (brand.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 38.sp, color: Colors.grey[500]),
                      ),
                    ],
                    SizedBox(height: 14.h),
                    Row(
                      children: [
                        Icon(status.icon, size: 40.sp, color: status.color),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            status.label,
                            style: TextStyle(
                              fontSize: 46.sp,
                              fontWeight: FontWeight.w600,
                              color: status.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!SubscriptionService.isSubscribed ||
                  scores.hasNutriscore ||
                  scores.hasEcoscore) ...[
                SizedBox(width: 20.w),
                _buildScoreColumn(scores),
              ],
            ],
          ),
          if (isBoycotted && !(product.status == ScanStatus.notVegan)) ...[
            SizedBox(height: 16.h),
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => InfoModal(
                    description:
                        "Les produits notés 'À éviter' sont des produits de marques qui ont des actions néfastes pour l'environnement, la santé, les droits des animaux ou les droits humains. Nous vous encourageons à boycotter ces marques pour soutenir des pratiques éthiques et responsables.",
                    boycottMatch: boycottMatch,
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.thumb_down, color: kSemanticError, size: 40.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'À éviter',
                    style: AppTextStyles.bodyMedium15.copyWith(color: kSemanticError)
                  ),
                ],
              ),
            ),
          ],
          if (product.biodynamic)
            _buildWarningBox('Agriculture biodynamique'),
          if (isEan8 && product.status != ScanStatus.unknown)
            _buildWarningBox(
                'Code EAN-8 : ce code-barres peut correspondre à plusieurs produits.'),
          if (product.status == ScanStatus.vegan && product.hasNonVeganOldRecipe)
            _buildWarningBox(
                'Ancienne recette non vegan : il se peut qu\'il y ait encore de l\'ancienne recette. Vérifiez les ingrédients.'),
        ],
      ),
    );
  }

  Widget _buildWarningBox(String text) {
    return Padding(
      padding: EdgeInsets.only(top: 16.h),
      child: InfoBox(text: text, symbol: '!'),
    );
  }
}
