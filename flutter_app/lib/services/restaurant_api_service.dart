import 'dart:io' show File;
import 'package:dio/dio.dart';
import '../models/restaurants/restaurant.dart';
import '../models/restaurants/restaurant_review.dart';
import '../models/restaurants/restaurant_suggestion.dart';
import 'auth_service.dart';
import 'dio_client.dart';

/// Restaurants and their reviews (/restaurants, /restaurant-reviews). Every
/// route needs the user's token, like the shops.
class RestaurantApiService {
  RestaurantApiService._();

  static Options get _auth {
    final accessToken = AuthService.accessToken;
    return Options(headers: {
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    });
  }

  static bool _isSuccess(Response response) =>
      response.statusCode != null &&
      response.statusCode! >= 200 &&
      response.statusCode! < 300;

  /// The API's own message for a refused request (business rules), so the
  /// form can show what to fix.
  static String? _errorMessage(Object error) {
    if (error is! DioException) return null;
    final detail = error.response?.data is Map
        ? (error.response!.data as Map)['detail']
        : null;
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      return detail
          .map((d) => '${d['msg']}'.replaceFirst('Value error, ', ''))
          .join('\n');
    }
    return null;
  }

  // ── Restaurants ──────────────────────────────────────────────────────────

  /// Restaurants to show on the map within a bounding box, with their
  /// rating. Empty on failure.
  static Future<List<Restaurant>> getRestaurantsInArea({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    Set<String> tags = const {},
    Set<String> serviceOptions = const {},
    bool fullyVeganOnly = false,
    bool noPlantMilkSurcharge = false,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.get(
        '/restaurants/in-area',
        queryParameters: {
          'min_lat': minLat,
          'max_lat': maxLat,
          'min_lng': minLng,
          'max_lng': maxLng,
          if (tags.isNotEmpty) 'tags': tags.join(','),
          if (serviceOptions.isNotEmpty)
            'service_options': serviceOptions.join(','),
          if (fullyVeganOnly) 'vegan_status': VeganStatus.fullyVegan,
          if (noPlantMilkSurcharge) 'plant_milk_surcharge__le': 0,
        },
        options: _auth,
      );
      if (_isSuccess(response)) {
        return (response.data as List<dynamic>)
            .map((e) => Restaurant.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Restaurants whose name contains [query], for the map search: open ones
  /// first, then names starting with it, then the closest to the given
  /// point (map center). Null on failure.
  static Future<List<Restaurant>?> searchRestaurants(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.get(
        '/restaurants/search-name',
        queryParameters: {
          'q': query.trim(),
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        },
        options: _auth,
      );
      if (_isSuccess(response)) {
        return (response.data as List<dynamic>)
            .map((e) => Restaurant.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  /// Restaurants (validated or pending) close to a point, closest first, to
  /// spot a duplicate before creating one. Null on failure.
  static Future<List<Restaurant>?> getNearbyRestaurants({
    required double latitude,
    required double longitude,
    int radius = 50,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.get(
        '/restaurants/nearby',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'radius': radius,
        },
        options: _auth,
      );
      if (_isSuccess(response)) {
        return (response.data as List<dynamic>)
            .map((e) => Restaurant.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  /// Full restaurant with its approved place and menu photos (plus the
  /// user's own pending ones). Null on failure.
  static Future<Restaurant?> getRestaurant(int id) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.get('/restaurants/$id', options: _auth);
      if (_isSuccess(response)) {
        return Restaurant.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// Submits a restaurant, pending until a moderator validates it. On
  /// refusal, [error] carries the API's reason when there is one.
  static Future<({Restaurant? restaurant, String? error})> createRestaurant(
    Map<String, dynamic> data,
  ) async {
    try {
      final dio = await DioClient.getDio();
      final response =
          await dio.post('/restaurants/', data: data, options: _auth);
      if (_isSuccess(response)) {
        return (
          restaurant:
              Restaurant.fromJson(response.data as Map<String, dynamic>),
          error: null,
        );
      }
    } catch (e) {
      return (restaurant: null, error: _errorMessage(e));
    }
    return (restaurant: null, error: null);
  }

  /// Why a photo upload failed, in words for the user.
  static String _photoErrorMessage(Object error) {
    if (error is! DioException) return 'Erreur inattendue.';
    switch (error.type) {
      case DioExceptionType.connectionError:
        return 'Pas de connexion internet.';
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connexion trop lente, l\'envoi n\'a pas abouti.';
      default:
        break;
    }
    final status = error.response?.statusCode;
    // Refused by the web server in front of the API (its limit is lower
    // than the API's 5 MB)
    if (status == 413) return 'Photo trop lourde pour le serveur.';
    final detail = _errorMessage(error) ?? '';
    if (detail.contains('format')) {
      return 'Format non pris en charge (JPG, PNG ou WebP).';
    }
    if (detail.contains('too large')) {
      return 'Photo trop lourde (5 Mo maximum).';
    }
    if (detail.contains('more than')) {
      return 'Ce lieu a déjà le nombre maximum de photos de ce type.';
    }
    return status != null
        ? 'Erreur du serveur ($status).'
        : 'Erreur inattendue.';
  }

  /// Adds a place or menu photo ([RestaurantPhoto.kindPlace] /
  /// [RestaurantPhoto.kindMenu]), pending until moderated. On success,
  /// [photoId] is the new photo's; on failure, [error] says why, in words
  /// for the user.
  static Future<({bool ok, String? error, int? photoId})>
      uploadRestaurantPhoto({
    required int restaurantId,
    required String kind,
    required File photo,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final formData = FormData.fromMap({
        'kind': kind,
        'file': await MultipartFile.fromFile(
          photo.path,
          filename: photo.path.split('/').last,
        ),
      });
      final response = await dio.post(
        '/restaurants/$restaurantId/photos',
        data: formData,
        options: _auth.copyWith(contentType: 'multipart/form-data'),
      );
      if (_isSuccess(response)) {
        final data = response.data;
        return (
          ok: true,
          error: null,
          photoId: data is Map ? data['id'] as int? : null,
        );
      }
      return (
        ok: false,
        error: 'Erreur du serveur (${response.statusCode}).',
        photoId: null,
      );
    } catch (e) {
      return (ok: false, error: _photoErrorMessage(e), photoId: null);
    }
  }

  /// Makes a photo the one shown first on the restaurant page (allowed to
  /// the creator while the restaurant is pending). False on failure.
  static Future<bool> featureRestaurantPhoto({
    required int restaurantId,
    required int photoId,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.patch(
        '/restaurants/$restaurantId/photos/$photoId/featured',
        options: _auth,
      );
      return _isSuccess(response);
    } catch (_) {
      return false;
    }
  }

  /// Restaurants created by the user (pending or validated), newest
  /// first. Null on failure.
  static Future<({List<Restaurant> items, int pages})?> getMyRestaurants({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.get(
        '/restaurants/mine',
        queryParameters: {'page': page, 'page_size': pageSize},
        options: _auth,
      );
      if (_isSuccess(response)) {
        final data = response.data as Map<String, dynamic>;
        return (
          items: (data['items'] as List<dynamic>)
              .map((e) => Restaurant.fromJson(e as Map<String, dynamic>))
              .toList(),
          pages: data['pages'] as int,
        );
      }
    } catch (_) {}
    return null;
  }

  // ── Saved ────────────────────────────────────────────────────────────────

  /// Restaurants saved by the user, last saved first. Null on failure.
  static Future<({List<Restaurant> items, int pages})?> getSavedRestaurants({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.get(
        '/restaurants/saved',
        queryParameters: {'page': page, 'page_size': pageSize},
        options: _auth,
      );
      if (_isSuccess(response)) {
        final data = response.data as Map<String, dynamic>;
        return (
          items: (data['items'] as List<dynamic>)
              .map((e) => Restaurant.fromJson(e as Map<String, dynamic>))
              .toList(),
          pages: data['pages'] as int,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Saves the restaurant for the user, or removes it from the saved ones
  /// when [saved] is false. False on failure.
  static Future<bool> setRestaurantSaved(int restaurantId, bool saved) async {
    try {
      final dio = await DioClient.getDio();
      final response = saved
          ? await dio.put('/restaurants/$restaurantId/saved', options: _auth)
          : await dio.delete('/restaurants/$restaurantId/saved',
              options: _auth);
      return _isSuccess(response);
    } catch (_) {
      return false;
    }
  }

  // ── Reviews ──────────────────────────────────────────────────────────────

  static Future<RestaurantReviewSummary?> getReviewSummary(
      int restaurantId) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.get(
        '/restaurant-reviews/restaurants/$restaurantId/summary',
        options: _auth,
      );
      if (_isSuccess(response)) {
        return RestaurantReviewSummary.fromJson(
            response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// Approved reviews of a restaurant, newest first. Null on failure.
  static Future<RestaurantReviewPaginated?> getReviews({
    required int restaurantId,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.get(
        '/restaurant-reviews/search',
        queryParameters: {
          'restaurant_id': restaurantId,
          'status': 'APPROVED',
          'page': page,
          'page_size': pageSize,
        },
        options: _auth,
      );
      if (_isSuccess(response)) {
        return RestaurantReviewPaginated.fromJson(
            response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// Every restaurant review of the user, whatever its status, newest
  /// first. Null on failure.
  static Future<RestaurantReviewPaginated?> getMyReviews({
    int page = 1,
    int pageSize = 20,
  }) async {
    final userId = AuthService.currentUser?.id;
    if (userId == null) return null;
    try {
      final dio = await DioClient.getDio();
      final response = await dio.get(
        '/restaurant-reviews/search',
        queryParameters: {
          'user_id': userId,
          'page': page,
          'page_size': pageSize,
        },
        options: _auth,
      );
      if (_isSuccess(response)) {
        return RestaurantReviewPaginated.fromJson(
            response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// The user's review of a restaurant (null if none or logged out).
  /// Failures are thrown, not turned into null: "couldn't load it" must not
  /// pass for "hasn't reviewed", which would offer a duplicate review.
  static Future<RestaurantReview?> getMyReview(int restaurantId) async {
    final userId = AuthService.currentUser?.id;
    if (AuthService.accessToken == null || userId == null) return null;

    final dio = await DioClient.getDio();
    final response = await dio.get(
      '/restaurant-reviews/search',
      queryParameters: {
        'restaurant_id': restaurantId,
        'user_id': userId,
        'page_size': 1,
      },
      options: _auth,
    );
    final paginated = RestaurantReviewPaginated.fromJson(
        response.data as Map<String, dynamic>);
    return paginated.items.isNotEmpty ? paginated.items.first : null;
  }

  /// Creates the user's review ([criteria] by [RestaurantCriterion.field]).
  static Future<RestaurantReview?> postReview({
    required int restaurantId,
    required int rating,
    Map<String, int?> criteria = const {},
    String? comment,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.post(
        '/restaurant-reviews/',
        data: {
          'restaurant_id': restaurantId,
          'rating': rating,
          ...criteria,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
        options: _auth,
      );
      if (_isSuccess(response)) {
        return RestaurantReview.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// Updates the user's review; a null criterion clears it.
  static Future<RestaurantReview?> updateReview({
    required int reviewId,
    required int rating,
    Map<String, int?> criteria = const {},
    String? comment,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.put(
        '/restaurant-reviews/$reviewId',
        data: {'rating': rating, ...criteria, 'comment': comment},
        options: _auth,
      );
      if (_isSuccess(response)) {
        return RestaurantReview.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// Adds a photo to the user's review, which goes back to moderation.
  static Future<bool> uploadReviewPhoto({
    required int reviewId,
    required File photo,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          photo.path,
          filename: photo.path.split('/').last,
        ),
      });
      final response = await dio.post(
        '/restaurant-reviews/$reviewId/photos',
        data: formData,
        options: _auth.copyWith(contentType: 'multipart/form-data'),
      );
      return _isSuccess(response);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteReviewPhoto({
    required int reviewId,
    required int photoId,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.delete(
        '/restaurant-reviews/$reviewId/photos/$photoId',
        options: _auth,
      );
      return _isSuccess(response);
    } catch (_) {
      return false;
    }
  }

  // ── Suggestions ──────────────────────────────────────────────────────────

  /// Proposes a change of a validated restaurant (see
  /// [RestaurantSuggestion] kinds): [changes] by API field and
  /// [removePhotoIds] for an edit, [duplicateOfId] for a duplicate. It
  /// replaces the user's pending suggestion for the same restaurant. On
  /// refusal, [error] carries the API's reason when there is one.
  static Future<({bool ok, String? error})> createSuggestion({
    required int restaurantId,
    String kind = RestaurantSuggestion.kindEdit,
    Map<String, dynamic> changes = const {},
    List<int> removePhotoIds = const [],
    int? featuredPhotoId,
    int? duplicateOfId,
    String? comment,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.post(
        '/restaurant-suggestions/',
        data: {
          'restaurant_id': restaurantId,
          'kind': kind,
          if (changes.isNotEmpty) 'changes': changes,
          if (removePhotoIds.isNotEmpty) 'remove_photo_ids': removePhotoIds,
          if (featuredPhotoId != null) 'featured_photo_id': featuredPhotoId,
          if (duplicateOfId != null) 'duplicate_of_id': duplicateOfId,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
        options: _auth,
      );
      return (ok: _isSuccess(response), error: null);
    } catch (e) {
      return (ok: false, error: _errorMessage(e));
    }
  }

  /// The user's suggestions, newest first. Null on failure.
  static Future<RestaurantSuggestionPaginated?> getMySuggestions({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.get(
        '/restaurant-suggestions/search',
        queryParameters: {'page': page, 'page_size': pageSize},
        options: _auth,
      );
      if (_isSuccess(response)) {
        return RestaurantSuggestionPaginated.fromJson(
            response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> withdrawSuggestion(int id) async {
    try {
      final dio = await DioClient.getDio();
      final response =
          await dio.delete('/restaurant-suggestions/$id', options: _auth);
      return _isSuccess(response);
    } catch (_) {
      return false;
    }
  }
}
