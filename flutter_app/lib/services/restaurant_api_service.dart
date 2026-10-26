import 'dart:io' show File;
import 'package:dio/dio.dart';
import '../models/restaurants/restaurant.dart';
import '../models/restaurants/restaurant_review.dart';
import '../models/restaurants/restaurant_selection.dart';
import '../models/restaurants/restaurant_suggestion.dart';
import 'auth_service.dart';
import 'dio_client.dart';

/// Restaurants, their reviews and the selections (/restaurants,
/// /restaurant-reviews, /restaurant-selections). Every route needs the
/// user's token, like the shops.
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
    bool glutenFreeOptions = false,
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
          if (glutenFreeOptions) 'has_gluten_free_options': true,
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

  /// Restaurants whose name (or city, with [includeCity]) contains [query],
  /// for the map search: open ones first, then name matches, names starting
  /// with it, then the closest to the given point (map center). At most
  /// [limit] (up to 50). Null on failure.
  static Future<List<Restaurant>?> searchRestaurants(
    String query, {
    double? latitude,
    double? longitude,
    bool includeCity = false,
    int limit = 10,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.get(
        '/restaurants/search-name',
        queryParameters: {
          'q': query.trim(),
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (includeCity) 'include_city': true,
          'limit': limit,
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

  // ── Selections ───────────────────────────────────────────────────────────

  static Future<({List<RestaurantSelection> items, int pages})?>
      _getSelections(String path, int page, int pageSize) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.get(
        path,
        queryParameters: {'page': page, 'page_size': pageSize},
        options: _auth,
      );
      if (_isSuccess(response)) {
        final data = response.data as Map<String, dynamic>;
        return (
          items: (data['items'] as List<dynamic>)
              .map((e) =>
                  RestaurantSelection.fromJson(e as Map<String, dynamic>))
              .toList(),
          pages: data['pages'] as int,
        );
      }
    } catch (_) {}
    return null;
  }

  /// The user's selections, last updated first. Null on failure.
  static Future<({List<RestaurantSelection> items, int pages})?>
      getMySelections({int page = 1, int pageSize = 50}) =>
          _getSelections('/restaurant-selections/mine', page, pageSize);

  /// The selections sent to the user that they still have: pending ones
  /// first, then the accepted ones. Null on failure.
  static Future<({List<RestaurantSelection> items, int pages})?>
      getReceivedSelections({int page = 1, int pageSize = 100}) =>
          _getSelections('/restaurant-selections/received', page, pageSize);

  /// Pending selections the user hasn't seen yet. Null on failure.
  static Future<int?> getUnreadSelectionCount() async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.get(
          '/restaurant-selections/received/unread-count',
          options: _auth);
      if (_isSuccess(response)) {
        return (response.data as Map<String, dynamic>)['count'] as int;
      }
    } catch (_) {}
    return null;
  }

  /// Marks every selection sent to the user as seen. False on failure.
  static Future<bool> markReceivedSelectionsSeen() async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.put('/restaurant-selections/received/seen',
          options: _auth);
      return _isSuccess(response);
    } catch (_) {
      return false;
    }
  }

  /// A selection with its restaurants, for its owner or a user it was sent
  /// to. Null on failure (or no longer available).
  static Future<RestaurantSelection?> getSelection(int id) async {
    try {
      final dio = await DioClient.getDio();
      final response =
          await dio.get('/restaurant-selections/$id', options: _auth);
      if (_isSuccess(response)) {
        return RestaurantSelection.fromJson(
            response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  static List<Map<String, dynamic>> _itemsJson(
          List<RestaurantSelectionItem> items) =>
      [
        for (final item in items)
          {
            'restaurant_id': item.restaurant.id,
            if (item.note != null && item.note!.trim().isNotEmpty)
              'note': item.note!.trim(),
          },
      ];

  /// Creates a selection with [items] in their order. On refusal, [error]
  /// carries the API's reason when there is one.
  static Future<({RestaurantSelection? selection, String? error})>
      createSelection({
    required String title,
    String? description,
    List<RestaurantSelectionItem> items = const [],
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.post(
        '/restaurant-selections/',
        data: {
          'title': title,
          'description': description,
          'items': _itemsJson(items),
        },
        options: _auth,
      );
      if (_isSuccess(response)) {
        return (
          selection: RestaurantSelection.fromJson(
              response.data as Map<String, dynamic>),
          error: null,
        );
      }
    } catch (e) {
      return (selection: null, error: _errorMessage(e));
    }
    return (selection: null, error: null);
  }

  /// Replaces the title, description and restaurants (order and notes) of
  /// a selection. On refusal, [error] carries the API's reason.
  static Future<({RestaurantSelection? selection, String? error})>
      updateSelection({
    required int id,
    required String title,
    String? description,
    required List<RestaurantSelectionItem> items,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.put(
        '/restaurant-selections/$id',
        data: {
          'title': title,
          'description': description,
          'items': _itemsJson(items),
        },
        options: _auth,
      );
      if (_isSuccess(response)) {
        return (
          selection: RestaurantSelection.fromJson(
              response.data as Map<String, dynamic>),
          error: null,
        );
      }
    } catch (e) {
      return (selection: null, error: _errorMessage(e));
    }
    return (selection: null, error: null);
  }

  static Future<bool> deleteSelection(int id) async {
    try {
      final dio = await DioClient.getDio();
      final response =
          await dio.delete('/restaurant-selections/$id', options: _auth);
      return _isSuccess(response);
    } catch (_) {
      return false;
    }
  }

  /// Adds the restaurant at the end of the selection, or removes it when
  /// [inSelection] is false. False on failure.
  static Future<bool> setRestaurantInSelection({
    required int selectionId,
    required int restaurantId,
    required bool inSelection,
  }) async {
    final path = '/restaurant-selections/$selectionId/restaurants/$restaurantId';
    try {
      final dio = await DioClient.getDio();
      final response = inSelection
          ? await dio.put(path, options: _auth)
          : await dio.delete(path, options: _auth);
      return _isSuccess(response);
    } catch (_) {
      return false;
    }
  }

  /// Sends the selection to a user, by [email] or by [friendCode]. By
  /// email, the API answers the same whether it has an account or not; by
  /// friend code, [recipientNickname] tells who received it, and an
  /// unknown code is a failure with [notFound]. On refusal, [error] carries
  /// the API's reason when there is one.
  static Future<
      ({
        bool ok,
        String? recipientNickname,
        bool notFound,
        String? error
      })> sendSelection({
    required int id,
    String? email,
    String? friendCode,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.post(
        '/restaurant-selections/$id/send',
        data: {
          if (email != null) 'email': email.trim(),
          if (friendCode != null) 'friend_code': friendCode.trim(),
        },
        options: _auth,
      );
      final data = response.data;
      return (
        ok: _isSuccess(response),
        recipientNickname:
            data is Map ? data['recipient_nickname'] as String? : null,
        notFound: false,
        error: null,
      );
    } catch (e) {
      return (
        ok: false,
        recipientNickname: null,
        notFound: e is DioException && e.response?.statusCode == 404,
        error: _errorMessage(e),
      );
    }
  }

  /// Accepts a selection sent to the user. False on failure.
  static Future<bool> acceptSelection(int id) async {
    try {
      final dio = await DioClient.getDio();
      final response =
          await dio.put('/restaurant-selections/$id/accept', options: _auth);
      return _isSuccess(response);
    } catch (_) {
      return false;
    }
  }

  /// Refuses a selection sent to the user, or removes it once accepted. It
  /// won't come back if sent again. False on failure.
  static Future<bool> removeReceivedSelection(int id) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.delete('/restaurant-selections/$id/received',
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

  /// Creates the user's review ([criteria] by [RestaurantCriterion.field],
  /// [priceRange] a [RestaurantPriceRanges] value).
  static Future<RestaurantReview?> postReview({
    required int restaurantId,
    required int rating,
    Map<String, int?> criteria = const {},
    String? priceRange,
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
          if (priceRange != null) 'price_range': priceRange,
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

  /// Updates the user's review; a null criterion or [priceRange] clears it.
  static Future<RestaurantReview?> updateReview({
    required int reviewId,
    required int rating,
    Map<String, int?> criteria = const {},
    String? priceRange,
    String? comment,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final response = await dio.put(
        '/restaurant-reviews/$reviewId',
        data: {
          'rating': rating,
          ...criteria,
          'price_range': priceRange,
          'comment': comment,
        },
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
    final userId = AuthService.currentUser?.id;
    if (userId == null) return null;
    try {
      final dio = await DioClient.getDio();
      final response = await dio.get(
        '/restaurant-suggestions/search',
        // The API returns everyone's to moderators
        queryParameters: {
          'user_id': userId,
          'page': page,
          'page_size': pageSize,
        },
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
