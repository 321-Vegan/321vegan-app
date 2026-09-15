import 'package:vegan_app/helpers/database_helper.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/models/scan_result.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:sqflite/sqflite.dart';

class ProductInfoHelper {
  static Future<String?> _getBrandNameFromId(Database db, int brandId) async {
    try {
      List<String> brandHierarchy = [];
      int? currentBrandId = brandId;

      // Tracks visited ids to guard against cyclic parent references.
      Set<int> visitedBrands = {};

      while (
          currentBrandId != null && !visitedBrands.contains(currentBrandId)) {
        visitedBrands.add(currentBrandId);

        final brandResult = await db.query(
          'brands',
          where: 'id = ?',
          whereArgs: [currentBrandId],
        );

        if (brandResult.isEmpty) break;

        final brand = brandResult.first;
        final brandName = brand['name'] as String?;

        if (brandName != null && brandName.isNotEmpty) {
          // Insert at the front so the final order is root -> leaf.
          brandHierarchy.insert(0, brandName);
        }

        currentBrandId = brand['parent_id'] as int?;
      }

      brandHierarchy = brandHierarchy.reversed.toList();
      return brandHierarchy.isNotEmpty ? brandHierarchy.join(', ') : null;
    } catch (e) {
      return null;
    }
  }

  static Future<String> _resolveBrandName(Map<String, dynamic> product) async {
    String? brandName;

    if (product['brand_id'] != null) {
      brandName = await _getBrandNameFromId(
          await DatabaseHelper.instance.database, product['brand_id']);
    }

    if (brandName == null || brandName.isEmpty) {
      brandName = (product['brand'] as String?)?.replaceAll('&quot;', "'");
    }

    return brandName ?? 'Marque inconnue';
  }

  static Future<ScanResult> getProductInfo(String barcode) async {
    final dbResult = await DatabaseHelper.instance.queryProduct(barcode);

    if (dbResult.isEmpty) {
      final isAlreadyScanned =
          await PreferencesHelper.isCodeInPreferences(barcode);
      if (isAlreadyScanned) {
        final submitted =
            await PreferencesHelper.getSubmittedProductInfo(barcode);
        return ScanResult(
          code: barcode,
          name: submitted?['name']?.isNotEmpty == true
              ? submitted!['name']!
              : 'Produit inconnu',
          brand: submitted?['brand']?.isNotEmpty == true
              ? submitted!['brand']!
              : 'Marque inconnue',
          status: ScanStatus.alreadyScanned,
        );
      }
      return ScanResult(
        code: barcode,
        name: barcode,
        brand: 'inconnue',
        status: ScanStatus.unknown,
      );
    }

    final product = dbResult.first;
    final status = product['status'] as String?;

    String productName = ((product['name'] as String?) ?? 'Produit inconnu')
        .replaceAll('&quot;', "'");

    String brandName = await _resolveBrandName(product);

    bool isBiodynamie = product['biodynamie'] == 'Y';

    // R/M/N are the backend's raw status codes; anything else is approved.
    final scanStatus = switch (status) {
      'R' => ScanStatus.notVegan,
      'M' => ScanStatus.pending,
      'N' => ScanStatus.notFound,
      _ => ScanStatus.vegan,
    };

    return ScanResult(
      code: product['code']?.toString() ?? barcode,
      name: productName,
      brand: brandName,
      status: scanStatus,
      hasNonVeganOldRecipe: product['has_non_vegan_old_receipe'] == 1,
      problem: product['problem'] as String?,
      biodynamic: status != 'M' && status != 'N' ? isBiodynamie : false,
    );
  }

  /// Fetches this barcode's product from the API and reconciles any
  /// differing fields into the local database, so the currently displayed
  /// (and future) scans reflect the server's up-to-date data. Returns true
  /// if the local row was created/updated.
  static Future<bool> refreshFromApi(String barcode) async {
    final apiProduct = await ApiService.getProductByEan(ean: barcode);
    if (apiProduct == null) return false;

    // Mirrors the server's export filter (export.py): never let an
    // unpublished/unreviewed state overwrite the local data.
    const publishedStates = {'PUBLISHED', 'NEED_CONTACT', 'WAITING_BRAND_REPLY'};
    if (!publishedStates.contains(apiProduct.state)) return false;

    final status = switch (apiProduct.status) {
      'NON_VEGAN' => 'R',
      'MAYBE_VEGAN' => 'M',
      'NOT_FOUND' => 'N',
      _ => 'V',
    };

    final name = apiProduct.name?.trim();
    final brand = apiProduct.brand?.name ?? apiProduct.description?.trim();
    final problem = status == 'R' ? apiProduct.problemDescription : null;
    final hasNonVeganOldRecipe = apiProduct.hasNonVeganOldReceipe ?? false;

    final existing = await DatabaseHelper.instance.queryProduct(barcode);
    if (existing.isNotEmpty) {
      final row = existing.first;
      final unchanged = row['name'] == name &&
          row['brand'] == brand &&
          row['brand_id'] == null &&
          row['status'] == status &&
          (row['biodynamie'] == 'Y') == apiProduct.biodynamic &&
          row['problem'] == problem &&
          (row['has_non_vegan_old_receipe'] == 1) == hasNonVeganOldRecipe;
      if (unchanged) return false;
    }

    await DatabaseHelper.instance.upsertProduct(
      code: barcode,
      name: name,
      brand: brand,
      status: status,
      biodynamic: apiProduct.biodynamic,
      problem: problem,
      hasNonVeganOldRecipe: hasNonVeganOldRecipe,
    );
    return true;
  }
}
