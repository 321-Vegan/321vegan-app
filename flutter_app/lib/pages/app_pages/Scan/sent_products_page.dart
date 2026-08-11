import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/models/scan_result.dart';
import 'package:vegan_app/pages/app_pages/Scan/product_info_helper.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/widgets/shared/app_background.dart';

/// Full-screen page listing every product the user has submitted.
/// Pushed from the Scan page and from Settings ("Envoyés" row).
class SentProductsPage extends StatefulWidget {
  const SentProductsPage({super.key});

  @override
  State<SentProductsPage> createState() => _SentProductsPageState();
}

class _SentProductsPageState extends State<SentProductsPage> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  int _totalSubmissions = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final codes = await PreferencesHelper.getSuccessfulCodesFromPreferences();
    final total = await PreferencesHelper.getTotalSuccessfulSubmissions();
    await _searchSentCodesInDb(codes.reversed.toList());
    if (mounted) {
      setState(() {
        _totalSubmissions = total;
        _isLoading = false;
      });
    }
  }

  Future<void> _searchSentCodesInDb(List<String> codes) async {
    final Map<String, Map<String, dynamic>> processedCodes = {};

    for (final code in codes) {
      final productInfo = await ProductInfoHelper.getProductInfo(code);

      // Not reviewed yet (not in the local DB): show what the user typed
      // when submitting it instead of a generic "Nom inconnu" placeholder.
      final isNotYetProcessed = productInfo.status == ScanStatus.alreadyScanned ||
          productInfo.status == ScanStatus.unknown;
      final submitted =
          isNotYetProcessed ? await PreferencesHelper.getSubmittedProductInfo(code) : null;

      final name = submitted?['name']?.isNotEmpty == true
          ? submitted!['name']!
          : (productInfo.name.isNotEmpty ? productInfo.name : 'Nom inconnu');
      final brand = submitted?['brand']?.isNotEmpty == true
          ? submitted!['brand']!
          : (productInfo.brand.isNotEmpty ? productInfo.brand : 'Marque inconnue');

      processedCodes[code] = {
        'code': productInfo.code,
        'name': name,
        'brand': brand,
        'status': productInfo.status,
        'problem': productInfo.problem,
      };
    }

    if (mounted) {
      setState(() => _products = processedCodes.values.toList());
    }
  }

  /// Distinct from the scan-history status wording: here "not yet in the
  /// database" (alreadyScanned/unknown) means the submission is still being
  /// processed server-side, separate from "in the database, awaiting
  /// moderation" (pending) — both meaningful states for a submitted product.
  ({IconData icon, Color color, String label}) _statusInfo(
      ScanStatus status, String? problem) {
    switch (status) {
      case ScanStatus.vegan:
        return (icon: Icons.check_circle, color: Colors.green[600]!, label: 'Végane');
      case ScanStatus.notVegan:
        final reason = (problem != null && problem.isNotEmpty) ? ' : $problem' : '';
        return (icon: Icons.cancel, color: Colors.red[400]!, label: 'Non-végane$reason');
      case ScanStatus.pending:
        return (
          icon: Icons.schedule,
          color: kAccentYellow,
          label: 'En attente de vérification'
        );
      case ScanStatus.notFound:
        return (icon: Icons.help_outline, color: Colors.grey, label: 'Introuvable');
      case ScanStatus.alreadyScanned:
      case ScanStatus.unknown:
        return (
          icon: Icons.hourglass_top,
          color: Colors.grey,
          label: 'En cours de traitement'
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Produits envoyés',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kTextPrimary,
        ),
        body: SafeArea(
          top: false,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _products.isEmpty
                  ? _buildEmptyState()
                  : _buildList(),
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
              'Aucun produit envoyé',
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
              'Vos contributions apparaîtront ici.',
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
      itemCount: _products.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: EdgeInsets.only(bottom: 20.h),
            child: Text(
              '$_totalSubmissions produit${_totalSubmissions > 1 ? 's' : ''} envoyé${_totalSubmissions > 1 ? 's' : ''} au total',
              style: TextStyle(
                fontSize: 38.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.only(bottom: 20.h),
          child: _buildProductCard(_products[index - 1]),
        );
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final code = product['code'] as String;
    final name = product['name'] as String;
    final brand = product['brand'] as String;
    final status = _statusInfo(
      product['status'] as ScanStatus,
      product['problem'] as String?,
    );

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
          SizedBox(height: 4.h),
          Text(
            brand,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 38.sp, color: Colors.grey[500]),
          ),
          SizedBox(height: 4.h),
          Text(
            code,
            style: TextStyle(fontSize: 34.sp, color: Colors.grey[400]),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Icon(status.icon, size: 40.sp, color: status.color),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 40.sp,
                    fontWeight: FontWeight.w600,
                    color: status.color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
