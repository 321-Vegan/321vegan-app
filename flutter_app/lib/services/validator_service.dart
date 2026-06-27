import 'dart:convert';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:http/http.dart' as http;
import '../models/validator_product.dart';
import 'auth_service.dart';
import 'dio_client.dart';

class ValidatorService {
  static const String _offBaseUrl =
      'https://world.openfoodfacts.org/api/v0/product';

  // GET /products/search?state=CREATED&page=1&page_size=100&sort_by=created_at-asc
  static Future<({List<ValidatorProduct> items, int total})>
      getCreatedProducts() async {
    try {
      final dio = await DioClient.getDio();
      final token = AuthService.accessToken;

      final response = await dio.get(
        '/products/search',
        queryParameters: {
          'state': 'CREATED',
          'page': 1,
          'page_size': 100,
          'sort_by': 'created_at-asc',
        },
        options: dio_pkg.Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final data = response.data as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>)
            .map((e) =>
                ValidatorProduct.fromJson(e as Map<String, dynamic>))
            .toList();
        final total = data['total'] as int? ?? items.length;
        return (items: items, total: total);
      }
      return (items: <ValidatorProduct>[], total: 0);
    } catch (_) {
      return (items: <ValidatorProduct>[], total: 0);
    }
  }

  // GET /products/{id} — fetch the current state of a single product.
  // Returns null on network/parse error so callers can decide to proceed.
  static Future<String?> getProductState(int id) async {
    try {
      final dio = await DioClient.getDio();
      final token = AuthService.accessToken;

      final response = await dio.get(
        '/products/$id',
        options: dio_pkg.Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final data = response.data as Map<String, dynamic>;
        return data['state'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // PUT /products/{id} — set state=WAITING_PUBLISH + validation fields
  static Future<bool> validateProduct({
    required int id,
    required String ean,
    required String state,
    required String status,
    String? name,
    String? description,
    int? brandId,
    String? problemDescription,
    bool biodynamic = false,
    bool hasNonVeganOldRecipe = false,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final token = AuthService.accessToken;

      final body = <String, dynamic>{
        'ean': ean,
        'state': state,
        'status': status,
        if (name != null && name.isNotEmpty) 'name': name,
        if (description != null) 'description': description,
        if (brandId != null) 'brand_id': brandId,
        if (problemDescription != null && problemDescription.isNotEmpty)
          'problem_description': problemDescription,
        'biodynamic': biodynamic,
        'has_non_vegan_old_receipe': hasNonVeganOldRecipe,
      };

      final response = await dio.put(
        '/products/$id',
        data: body,
        options: dio_pkg.Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } catch (_) {
      return false;
    }
  }

  // POST /brands/
  static Future<ValidatorBrand?> createBrand({
    required String name,
    int? parentId,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final token = AuthService.accessToken;
      final response = await dio.post(
        '/brands/',
        data: {
          'name': name,
          if (parentId != null) 'parent_id': parentId,
        },
        options: dio_pkg.Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return ValidatorBrand.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // GET /brands/search/ranked?name={query}
  static Future<List<ValidatorBrand>> searchBrands(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final dio = await DioClient.getDio();
      final token = AuthService.accessToken;

      final response = await dio.get(
        '/brands/search/ranked',
        queryParameters: {'name': query.trim(), 'page_size': 10},
        options: dio_pkg.Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final data = response.data as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>? ?? [])
            .map((e) =>
                ValidatorBrand.fromJson(e as Map<String, dynamic>))
            .toList();
        return items;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // DELETE /products/{id}
  static Future<bool> deleteProduct(int id) async {
    try {
      final dio = await DioClient.getDio();
      final token = AuthService.accessToken;

      final response = await dio.delete(
        '/products/$id',
        options: dio_pkg.Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } catch (_) {
      return false;
    }
  }

  // OpenFoodFacts product data
  static Future<OffProductData> fetchOffData(String ean) async {
    try {
      final uri = Uri.parse('$_offBaseUrl/$ean.json');
      final response = await http
          .get(uri, headers: {'User-Agent': '321Vegan - Flutter App'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return const OffProductData();

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] == 0) return const OffProductData();

      final product = json['product'] as Map<String, dynamic>? ?? {};
      final brands = product['brands'] as String?;
      final productName = product['product_name'] as String?;

      final rawAdditives =
          (product['additives_tags'] as List<dynamic>? ?? [])
              .map((a) => (a as String).replaceAll('en:', '').toUpperCase())
              .toList();

      return OffProductData(
        productName: productName,
        brandName: brands?.split(',').first.trim(),
        ingredients: product['ingredients_text'] as String?,
        imageUrl: product['image_url'] as String?,
        additives: rawAdditives,
      );
    } catch (_) {
      return const OffProductData();
    }
  }
}
