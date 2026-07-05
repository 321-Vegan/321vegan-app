import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/models/scan_result.dart';
import 'package:vegan_app/pages/app_pages/Scan/product_info_helper.dart';

class SentProductsModal extends StatefulWidget {
  const SentProductsModal({super.key});

  @override
  State<SentProductsModal> createState() => _SentProductsModalState();
}

class _SentProductsModalState extends State<SentProductsModal> {
  List<String> sentCodes = [];
  List<Map<String, dynamic>> productDatas = [];
  bool isLoading = true;
  int totalSubmissions = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadSentCodes();
    await _searchSentCodesInDb(sentCodes);
    totalSubmissions = await PreferencesHelper.getTotalSuccessfulSubmissions();
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadSentCodes() async {
    List<String> codes =
        await PreferencesHelper.getSuccessfulCodesFromPreferences();
    sentCodes = codes.reversed.toList();
  }

  Future<void> _searchSentCodesInDb(List<String> codes) async {
    final Map<String, Map<String, dynamic>> processedCodes = {};

    for (String code in codes) {
      // Initialize with default values
      processedCodes[code] = {
        'code': code,
        'name': 'Nom inconnu',
        'brand': 'Marque inconnue',
        'status': 'En cours',
      };

      // Get product info using ProductInfoHelper
      final productInfo = await ProductInfoHelper.getProductInfo(code);

      // Convert the scan status to display status
      final status = switch (productInfo.status) {
        ScanStatus.vegan => 'Vegan',
        ScanStatus.notVegan => 'Pas Vegan',
        ScanStatus.pending => 'En attente',
        ScanStatus.notFound => 'Introuvable',
        ScanStatus.alreadyScanned || ScanStatus.unknown => 'En cours',
      };

      processedCodes[code] = {
        'code': productInfo.code,
        'name': productInfo.name.isNotEmpty ? productInfo.name : 'Nom inconnu',
        'brand':
            productInfo.brand.isNotEmpty ? productInfo.brand : 'Marque inconnue',
        'status': status,
        'problem': productInfo.problem,
      };
    }

    if (mounted) {
      setState(() {
        productDatas = processedCodes.values.toList();
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Vegan':
        return Colors.green;
      case 'En cours':
        return Colors.orange;
      case 'En attente':
        return Colors.purple;
      case 'Pas Vegan':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.switch_access_shortcut_add_outlined,
                  color: Colors.white,
                  size: 40.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mes produits envoyés',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 50.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$totalSubmissions au total',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 35.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 40.sp,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : productDatas.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.w),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 80.sp,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                'Aucun produit envoyé',
                                style: TextStyle(
                                  fontSize: 50.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Scannez des produits pour les voir apparaître ici',
                                style: TextStyle(
                                  fontSize: 40.sp,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16.w),
                        itemCount: productDatas.length,
                        itemBuilder: (context, index) {
                          final product = productDatas[index];
                          final status = product['status'];
                          final brand = product['brand'];
                          final reason = product['problem'];

                          return Card(
                            margin: EdgeInsets.only(bottom: 12.h),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16.w),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product information section
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product['code'],
                                          style: TextStyle(
                                            fontSize: 40.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          product['name'],
                                          style: TextStyle(
                                            fontSize: 40.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          brand,
                                          style: TextStyle(
                                            fontSize: 40.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Status and reason section
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12.w, vertical: 6.h),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 40.sp,
                                          ),
                                        ),
                                      ),
                                      if (reason != null && reason.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(
                                              top: 8.h, right: 8.w),
                                          child: SizedBox(
                                            width: 200.w,
                                            child: Text(
                                              reason,
                                              style: TextStyle(
                                                fontSize: 40.sp,
                                                color: Colors.red,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.right,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
