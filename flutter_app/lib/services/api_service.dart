import 'dart:convert';
import 'dart:io' show File;
import 'package:dio/dio.dart' as dio_pkg;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vegan_app/models/partners/partners.dart';
import 'auth_service.dart';
import 'dio_client.dart';
import '../models/b12_intake.dart';
import '../models/error_report.dart';
import '../models/product_of_interest.dart';
import '../models/product_category.dart';
import '../models/subscription.dart';
import '../models/shops/shop.dart';
import '../models/shops/shop_scan_summary.dart';
import '../models/shops/shop_review.dart';

class ApiService {
  static String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://api.321vegan.fr';
  static String get _apiKey => dotenv.env['API_KEY'] ?? '';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
      };

  /// Post a product with its vegan status
  /// [ean] - The product's barcode
  /// [status] - One of: "VEGAN", "NON_VEGAN", "MAYBE_VEGAN"
  /// [productName] - Name of the product (optional)
  /// [brand] - Brand of the product (optional)
  /// Returns the product ID on success, or null on failure
  static Future<int?> postProduct({
    required String ean,
    required String status,
    String productName = '',
    String brand = '',
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/products/');

      // Get the current user's ID if logged in
      final userId = AuthService.currentUser?.id;

      final body = json.encode({
        'ean': ean,
        'status': status,
        if (productName.isNotEmpty) 'name': productName,
        // We put brand in description because brand is the ID that we dont have here.
        if (brand.isNotEmpty) 'description': brand,
        if (userId != null) 'user_id': userId,
      });

      final response = await http.post(
        url,
        headers: _headers,
        body: body,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['id'] as int?;
      }
      // 409 means product already exists, which is fine for the user
      if (response.statusCode == 409) return -1;
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Upload a photo for a product using the user's JWT token
  /// [productId] - The product's ID
  /// [photo] - The image file to upload
  static Future<bool> uploadProductImage({
    required int productId,
    required File photo,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final accessToken = AuthService.accessToken;

      final formData = dio_pkg.FormData.fromMap({
        'file': await dio_pkg.MultipartFile.fromFile(
          photo.path,
          filename: photo.path.split('/').last,
        ),
      });

      final response = await dio.post(
        '/products/$productId/image',
        data: formData,
        options: dio_pkg.Options(
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
          contentType: 'multipart/form-data',
        ),
      );

      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } catch (e) {
      return false;
    }
  }

  /// Get a product's ID by its EAN (requires user JWT)
  static Future<int?> getProductIdByEan({required String ean}) async {
    try {
      final dio = await DioClient.getDio();
      final accessToken = AuthService.accessToken;

      final response = await dio.get(
        '/products/ean/$ean',
        options: dio_pkg.Options(
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data['id'] as int?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Post an error report
  /// [ean] - The product's barcode/EAN
  /// [comment] - User's comment about the error
  /// [contact] - User's contact information (email/phone)
  /// Automatically adds the logged-in user's ID to created_by if available
  static Future<bool> postErrorReport({
    required String ean,
    required String comment,
    required String contact,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/error-reports/');

      // Get the current user's ID if logged in
      final userId = AuthService.currentUser?.id;

      final body = json.encode({
        'ean': ean,
        'comment': comment,
        'contact': contact,
        'handled': false,
        if (userId != null) 'created_by': userId,
      });

      final response = await http.post(
        url,
        headers: _headers,
        body: body,
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  /// Get the current user's error reports, most recent first, including the
  /// team's response once handled (requires user JWT).
  static Future<ErrorReportPaginated?> getMyErrorReports({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final accessToken = AuthService.accessToken;

      final response = await dio.get(
        '/me/error-reports',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
        },
        options: dio_pkg.Options(
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300 &&
          response.data != null) {
        return ErrorReportPaginated.fromJson(
            response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get all interesting products (products of interest)
  static Future<List<ProductOfInterest>> getInterestingProducts() async {
    try {
      final url = Uri.parse('$_baseUrl/interesting-products/');

      final response = await http.get(
        url,
        headers: _headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((item) => ProductOfInterest.fromJson(item)).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Post a scan event for a product of interest
  /// [ean] - The product's barcode
  /// [latitude] - User's latitude (optional)
  /// [longitude] - User's longitude (optional)
  /// [userId] - The user who scanned. Queued offline scans must pass the id
  /// captured at scan time: falling back to [AuthService.currentUser] here is
  /// only correct for live scans (on a retry at app startup the profile may
  /// not be loaded yet, and the event would be posted anonymously).
  ///
  /// Returns the parsed response body on success (2xx), or `null` when the
  /// server is reachable but rejects the request (non-2xx). Network/connection
  /// failures (no response received) are rethrown so callers can distinguish
  /// "no internet" from "server said no" — important for retry/queue logic.
  static Future<Map<String, dynamic>?> postScanEvent({
    required String ean,
    double? latitude,
    double? longitude,
    int? userId,
  }) async {
    final url = Uri.parse('$_baseUrl/scan-events/');

    final effectiveUserId = userId ?? AuthService.currentUser?.id;

    final body = json.encode({
      'ean': ean,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (effectiveUserId != null) 'user_id': effectiveUserId,
    });

    // A network error here (SocketException, timeout, etc.) propagates to the
    // caller on purpose — see the doc comment above.
    final response = await http.post(
      url,
      headers: _headers,
      body: body,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    return null;
  }

  /// Record a B12 intake day for the current user (requires user JWT:
  /// the server attributes the intake to the token's user).
  /// [intakeDate] - The day the B12 was taken, formatted 'yyyy-MM-dd'
  /// [frequency] - The supplementation rhythm in effect when it was taken
  /// ("daily", "weekly", "twice_weekly", "biweekly")
  ///
  /// Returns the HTTP status code. 409 means the day is already recorded
  /// server-side and can be treated as synced. Network/connection failures
  /// are rethrown so callers can keep queued intakes for retry.
  static Future<int> postB12Intake({
    required String intakeDate,
    String? frequency,
  }) async {
    final dio = await DioClient.getDio();
    final accessToken = AuthService.accessToken;

    try {
      final response = await dio.post(
        '/b12-intakes/',
        data: {
          'intake_date': intakeDate,
          if (frequency != null) 'frequency': frequency,
        },
        options: dio_pkg.Options(
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      return response.statusCode ?? 0;
    } on dio_pkg.DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null) return status;
      rethrow;
    }
  }

  /// Get all B12 intakes recorded server-side for the current user
  /// (requires user JWT).
  /// Returns the intakes (dates at local midnight, with the frequency
  /// snapshotted at recording time), or null on failure.
  static Future<List<B12Intake>?> getB12Intakes() async {
    try {
      final dio = await DioClient.getDio();
      final accessToken = AuthService.accessToken;

      final response = await dio.get(
        '/me/b12-intakes',
        options: dio_pkg.Options(
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      final data = response.data;
      if (data is List) {
        final intakes = <B12Intake>[];
        for (final item in data) {
          final date = DateTime.tryParse(item['intake_date'] ?? '');
          if (date == null) continue;
          intakes.add(B12Intake(date: date, frequency: item['frequency']));
        }
        return intakes;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Confirm which shop the user is in by osm_id.
  /// Creates the shop in DB if it doesn't exist and links it to the scan event.
  static Future<bool> confirmShop({
    required int scanEventId,
    required String osmId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/scan-events/$scanEventId/confirm-shop');

      final response = await http.post(
        url,
        headers: _headers,
        body: json.encode({'osm_id': osmId}),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  /// Update a scan event.
  /// If [shopId] is provided, updates the shop association.
  /// If [shopId] is null, removes location data and shop association.
  static Future<bool> updateScanEvent({
    required int scanEventId,
    int? shopId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/scan-events/$scanEventId');

      final Map<String, dynamic> bodyMap;
      if (shopId != null) {
        bodyMap = {'shop_id': shopId};
      } else {
        bodyMap = {
          'shop_id': null,
        };
      }

      final response = await http.put(
        url,
        headers: _headers,
        body: json.encode(bodyMap),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  /// Increment the logged-in user's scan counter (requires user JWT).
  /// [count] lets several scans made offline be batched into one request.
  /// Returns the new server-side total, or null on failure.
  static Future<int?> incrementUserScanCount({required int count}) async {
    try {
      final dio = await DioClient.getDio();
      final accessToken = AuthService.accessToken;

      final response = await dio.post(
        '/users/me/scans',
        data: {'count': count},
        options: dio_pkg.Options(
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data['scan_count'] as int?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Seed the logged-in user's scan counter from the app's local total
  /// (requires user JWT). The server only applies it while its counter is
  /// still 0, so an existing account is never overwritten.
  /// Returns the server-side total, or null on failure.
  static Future<int?> initializeUserScanCount({required int count}) async {
    try {
      final dio = await DioClient.getDio();
      final accessToken = AuthService.accessToken;

      final response = await dio.put(
        '/users/me/scans',
        data: {'count': count},
        options: dio_pkg.Options(
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data['scan_count'] as int?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get all product categories
  static Future<List<ProductCategory>> getProductCategories() async {
    try {
      final url = Uri.parse('$_baseUrl/product-categories/');

      final response = await http.get(
        url,
        headers: _headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((item) => ProductCategory.fromJson(item)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  // Get all partners
  static Future<List<Partners>> getPartners() async {
    try {
      final url = Uri.parse(
          '$_baseUrl/partners/search?is_active=true&page_size=100&sortby=display_order&direction=asc');

      final response = await http.get(
        url,
        headers: _headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes));
        return (data['items'] as List<dynamic>)
            .map((item) => Partners.fromJson(item))
            .toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get the total number of active subscriptions
  static Future<int?> getSubscriptionCount() async {
    try {
      final url = Uri.parse('$_baseUrl/subscriptions/count');
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['count'] + 60 as int;
      }
    } catch (_) {}
    return null;
  }

  /// Get shops within a geographic bounding box (for map display)
  static Future<List<Shop>> getShopsInArea({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      final response = await dio.get(
        '/shops/in-area',
        queryParameters: {
          'min_lat': minLat,
          'max_lat': maxLat,
          'min_lng': minLng,
          'max_lng': maxLng,
        },
        options: dio_pkg.Options(
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final List<dynamic> data = response.data;
        return data.map((item) => Shop.fromJson(item)).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get shops that carry at least one of the given EANs (vegandex filter)
  static Future<List<Shop>> getShopsFilteredByProducts({
    required List<String> eans,
    double? minLat,
    double? maxLat,
    double? minLng,
    double? maxLng,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      final response = await dio.get(
        '/shops/search',
        queryParameters: {
          'ean__in': eans.join(','),
          if (minLat != null) 'min_lat': minLat,
          if (maxLat != null) 'max_lat': maxLat,
          if (minLng != null) 'min_lng': minLng,
          if (maxLng != null) 'max_lng': maxLng,
          'page_size': 100,
        },
        options: dio_pkg.Options(
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final raw = response.data;
        final List<dynamic> data =
            raw is List ? raw : (raw as Map<String, dynamic>)['items'] as List<dynamic>;
        return data.map((item) => Shop.fromJson(item)).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get scan summary for a shop (distinct EANs with scan count and last scan date)
  static Future<List<ShopScanSummary>> getShopProducts({
    required int shopId,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      final response = await dio.get(
        '/shops/$shopId/products',
        options: dio_pkg.Options(
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final List<dynamic> data = response.data;
        return data.map((item) => ShopScanSummary.fromJson(item)).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Report a product as not found in a shop
  /// [ean] - The product's barcode
  /// [shopId] - The shop's ID
  /// Returns true on success or if already reported (409)
  static Future<bool> postProductNotFoundReport({
    required String ean,
    required int shopId,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      final response = await dio.post(
        '/product-not-found-reports/',
        data: {'ean': ean, 'shop_id': shopId},
        options: dio_pkg.Options(
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      // 409 means already reported, treat as success
      return response.statusCode != null &&
          (response.statusCode! >= 200 && response.statusCode! < 300 ||
              response.statusCode == 409);
    } on dio_pkg.DioException catch (e) {
      if (e.response?.statusCode == 409) return true;
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Report a product as found in a shop
  /// [ean] - The product's barcode
  /// [shopId] - The shop's ID
  /// Returns true on success or if already reported (409)
  static Future<bool> postProductFoundReport({
    required String ean,
    required int shopId,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      final response = await dio.post(
        '/product-found-reports/',
        data: {'ean': ean, 'shop_id': shopId},
        options: dio_pkg.Options(
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      return response.statusCode != null &&
          (response.statusCode! >= 200 && response.statusCode! < 300 ||
              response.statusCode == 409);
    } on dio_pkg.DioException catch (e) {
      if (e.response?.statusCode == 409) return true;
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get the current user's subscription status
  /// Returns null if no subscription or on error
  static Future<Subscription?> getSubscriptionStatus() async {
    try {
      final dio = await DioClient.getDio();
      final token = AuthService.accessToken;

      final response = await dio.get(
        '/subscriptions/me',
        options: dio_pkg.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return Subscription.fromJson(response.data);
      }
    } on dio_pkg.DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
    return null;
  }

  /// Get the review summary (count + avg rating) for a shop
  static Future<ShopReviewSummary?> getShopReviewSummary({
    required int shopId,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.get('/shop-reviews/shops/$shopId/summary');
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300 &&
          response.data != null) {
        return ShopReviewSummary.fromJson(
            response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get paginated approved reviews for a shop
  static Future<ShopReviewPaginated?> getShopReviews({
    required int shopId,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      final response = await dio.get(
        '/shop-reviews/search',
        queryParameters: {
          'shop_id': shopId,
          'status': 'APPROVED',
          'page': page,
          'page_size': pageSize,
        },
        options: dio_pkg.Options(
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300 &&
          response.data != null) {
        return ShopReviewPaginated.fromJson(
            response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get the current user's review for a shop (null if none)
  static Future<ShopReview?> getMyShopReview({required int shopId}) async {
    try {
      final dio = await DioClient.getDio();
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null) return null;

      final userId = AuthService.currentUser?.id;
      if (userId == null) return null;

      final response = await dio.get(
        '/shop-reviews/search',
        queryParameters: {
          'shop_id': shopId,
          'user_id': userId,
          'page_size': 1,
        },
        options: dio_pkg.Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300 &&
          response.data != null) {
        final paginated = ShopReviewPaginated.fromJson(
            response.data as Map<String, dynamic>);
        return paginated.items.isNotEmpty ? paginated.items.first : null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Post a new shop review
  static Future<ShopReview?> postShopReview({
    required int shopId,
    required int rating,
    String? comment,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null) return null;

      final response = await dio.post(
        '/shop-reviews/',
        data: {
          'shop_id': shopId,
          'rating': rating,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
        options: dio_pkg.Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return ShopReview.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update an existing shop review
  static Future<ShopReview?> updateShopReview({
    required int reviewId,
    required int rating,
    String? comment,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null) return null;

      final response = await dio.put(
        '/shop-reviews/$reviewId',
        data: {
          'rating': rating,
          'comment': comment,
        },
        options: dio_pkg.Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return ShopReview.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Create a new shop
  static Future<bool> postShop({
    required String name,
    required double latitude,
    required double longitude,
    String address = '',
    String city = '',
    String country = '',
    String shopType = 'supermarket',
  }) async {
    try {
      final dio = await DioClient.getDio();
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      final response = await dio.post(
        '/shops/',
        data: {
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
          if (address.isNotEmpty) 'address': address,
          if (city.isNotEmpty) 'city': city,
          if (country.isNotEmpty) 'country': country,
          'shop_type': shopType,
        },
        options: dio_pkg.Options(
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } catch (e) {
      return false;
    }
  }

  /// Verify a purchase receipt with the backend
  /// Returns the subscription if verification succeeded, null otherwise
  static Future<Subscription?> verifySubscription({
    required String platform,
    required String productId,
    String? transactionId,
    String? purchaseToken,
  }) async {
    final dio = await DioClient.getDio();
    final token = AuthService.accessToken;

    final Map<String, dynamic> data = {
      'platform': platform,
      'product_id': productId,
    };

    if (platform == 'apple' && transactionId != null) {
      data['transaction_id'] = transactionId;
    } else if (purchaseToken != null) {
      data['purchase_token'] = purchaseToken;
    }

    final response = await dio.post(
      '/subscriptions/verify',
      data: data,
      options: dio_pkg.Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );

    if (response.statusCode == 200) {
      return Subscription.fromJson(response.data);
    }
    return null;
  }
}
