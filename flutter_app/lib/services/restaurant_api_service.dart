import 'dart:io' show File;
import 'package:dio/dio.dart';
import '../models/restaurants/restaurant.dart';
import '../models/restaurants/restaurant_review.dart';
import '../models/restaurants/restaurant_selection.dart';
import '../models/restaurants/restaurant_suggestion.dart';
import 'auth_service.dart';
import 'dio_client.dart';

/// One page of a list, and the total number of pages.
typedef Paged<T> = ({List<T> items, int pages});

typedef _Request = Future<Response> Function(Dio dio);

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

  static Options get _multipartAuth =>
      _auth.copyWith(contentType: 'multipart/form-data');

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

  // ── Requests ─────────────────────────────────────────────────────────────

  /// Runs [request] and parses the response body. Null on failure.
  static Future<T?> _fetch<T>(
      _Request request, T Function(dynamic data) parse) async {
    try {
      final response = await request(await DioClient.getDio());
      if (_isSuccess(response)) return parse(response.data);
    } catch (_) {}
    return null;
  }

  /// Runs [request]. False on failure.
  static Future<bool> _ok(_Request request) async {
    try {
      return _isSuccess(await request(await DioClient.getDio()));
    } catch (_) {
      return false;
    }
  }

  /// Like [_fetch], with the reason of a refusal ([errorOf]).
  static Future<({T? value, String? error})> _submit<T>(
    _Request request,
    T Function(dynamic data) parse, {
    String? Function(Object error) errorOf = _errorMessage,
  }) async {
    try {
      final response = await request(await DioClient.getDio());
      if (_isSuccess(response)) {
        return (value: parse(response.data), error: null);
      }
    } catch (e) {
      return (value: null, error: errorOf(e));
    }
    return (value: null, error: null);
  }

  static Future<MultipartFile> _file(File file) =>
      MultipartFile.fromFile(file.path, filename: file.path.split('/').last);

  // ── Parsing ──────────────────────────────────────────────────────────────

  static Restaurant _restaurant(dynamic json) =>
      Restaurant.fromJson(json as Map<String, dynamic>);

  static List<Restaurant> _restaurants(dynamic data) =>
      (data as List<dynamic>).map(_restaurant).toList();

  static RestaurantSelection _selection(dynamic json) =>
      RestaurantSelection.fromJson(json as Map<String, dynamic>);

  static RestaurantReview _review(dynamic json) =>
      RestaurantReview.fromJson(json as Map<String, dynamic>);

  static Paged<T> _page<T>(dynamic data, T Function(dynamic json) parse) {
    final json = data as Map<String, dynamic>;
    return (
      items: (json['items'] as List<dynamic>).map(parse).toList(),
      pages: json['pages'] as int,
    );
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
  }) async =>
      await _fetch(
        (dio) => dio.get(
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
        ),
        _restaurants,
      ) ??
      [];

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
  }) =>
      _fetch(
        (dio) => dio.get(
          '/restaurants/search-name',
          queryParameters: {
            'q': query.trim(),
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
            if (includeCity) 'include_city': true,
            'limit': limit,
          },
          options: _auth,
        ),
        _restaurants,
      );

  /// Restaurants (validated or pending) close to a point, closest first, to
  /// spot a duplicate before creating one. Null on failure.
  static Future<List<Restaurant>?> getNearbyRestaurants({
    required double latitude,
    required double longitude,
    int radius = 50,
  }) =>
      _fetch(
        (dio) => dio.get(
          '/restaurants/nearby',
          queryParameters: {
            'latitude': latitude,
            'longitude': longitude,
            'radius': radius,
          },
          options: _auth,
        ),
        _restaurants,
      );

  /// Full restaurant with its approved place and menu photos (plus the
  /// user's own pending ones). Null on failure.
  static Future<Restaurant?> getRestaurant(int id) =>
      _fetch((dio) => dio.get('/restaurants/$id', options: _auth), _restaurant);

  /// Submits a restaurant, pending until a moderator validates it. On
  /// refusal, [error] carries the API's reason when there is one.
  static Future<({Restaurant? restaurant, String? error})> createRestaurant(
    Map<String, dynamic> data,
  ) async {
    final result = await _submit(
      (dio) => dio.post('/restaurants/', data: data, options: _auth),
      _restaurant,
    );
    return (restaurant: result.value, error: result.error);
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
      final response = await dio.post(
        '/restaurants/$restaurantId/photos',
        data: FormData.fromMap({'kind': kind, 'file': await _file(photo)}),
        options: _multipartAuth,
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
  }) =>
      _ok((dio) => dio.patch(
            '/restaurants/$restaurantId/photos/$photoId/featured',
            options: _auth,
          ));

  /// Restaurants created by the user (pending or validated), newest
  /// first. Null on failure.
  static Future<Paged<Restaurant>?> getMyRestaurants({
    int page = 1,
    int pageSize = 20,
  }) =>
      _fetch(
        (dio) => dio.get(
          '/restaurants/mine',
          queryParameters: {'page': page, 'page_size': pageSize},
          options: _auth,
        ),
        (data) => _page(data, _restaurant),
      );

  // ── Saved ────────────────────────────────────────────────────────────────

  /// Restaurants saved by the user, last saved first. Null on failure.
  static Future<Paged<Restaurant>?> getSavedRestaurants({
    int page = 1,
    int pageSize = 20,
  }) =>
      _fetch(
        (dio) => dio.get(
          '/restaurants/saved',
          queryParameters: {'page': page, 'page_size': pageSize},
          options: _auth,
        ),
        (data) => _page(data, _restaurant),
      );

  /// Saves the restaurant for the user, or removes it from the saved ones
  /// when [saved] is false. False on failure.
  static Future<bool> setRestaurantSaved(int restaurantId, bool saved) {
    final path = '/restaurants/$restaurantId/saved';
    return _ok((dio) => saved
        ? dio.put(path, options: _auth)
        : dio.delete(path, options: _auth));
  }

  // ── Selections ───────────────────────────────────────────────────────────

  static Future<Paged<RestaurantSelection>?> _getSelections(
          String path, int page, int pageSize,
          [Map<String, dynamic> query = const {}]) =>
      _fetch(
        (dio) => dio.get(
          path,
          queryParameters: {'page': page, 'page_size': pageSize, ...query},
          options: _auth,
        ),
        (data) => _page(data, _selection),
      );

  /// A selection sent back by the API, or the reason of a refusal
  /// ([errorOf]).
  static Future<({RestaurantSelection? selection, String? error})>
      _submitSelection(
    _Request request, {
    String? Function(Object error) errorOf = _errorMessage,
  }) async {
    final result = await _submit(request, _selection, errorOf: errorOf);
    return (selection: result.value, error: result.error);
  }

  /// The user's selections, last updated first. Null on failure.
  static Future<Paged<RestaurantSelection>?> getMySelections(
          {int page = 1, int pageSize = 50}) =>
      _getSelections('/restaurant-selections/mine', page, pageSize);

  /// The selections sent to the user that they still have: pending ones
  /// first, then the accepted ones. Null on failure.
  static Future<Paged<RestaurantSelection>?> getReceivedSelections(
          {int page = 1, int pageSize = 100}) =>
      _getSelections('/restaurant-selections/received', page, pageSize);

  /// The public selections having a place, that the user can take:
  /// [SelectionSort.recent] (last published first) or
  /// [SelectionSort.popular] (most taken first), those whose title contains
  /// [search] when given. Null on failure.
  static Future<Paged<RestaurantSelection>?> getPublicSelections({
    String sort = SelectionSort.recent,
    String search = '',
    int page = 1,
    int pageSize = 20,
  }) =>
      _getSelections('/restaurant-selections/public', page, pageSize, {
        'sort': sort,
        if (search.isNotEmpty) 'search': search,
      });

  /// Pending selections the user hasn't seen yet. Null on failure.
  static Future<int?> getUnreadSelectionCount() => _fetch(
        (dio) => dio.get('/restaurant-selections/received/unread-count',
            options: _auth),
        (data) => (data as Map<String, dynamic>)['count'] as int,
      );

  /// Marks every selection sent to the user as seen. False on failure.
  static Future<bool> markReceivedSelectionsSeen() => _ok(
      (dio) => dio.put('/restaurant-selections/received/seen', options: _auth));

  /// A selection with its restaurants, for its owner, a user it was sent
  /// to, or anyone when public. Null on failure (or no longer available).
  static Future<RestaurantSelection?> getSelection(int id) => _fetch(
      (dio) => dio.get('/restaurant-selections/$id', options: _auth),
      _selection);

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

  /// Creates a selection with [items] in their order, public for good
  /// with [isPublic]. On refusal, [error] carries the API's reason when
  /// there is one.
  static Future<({RestaurantSelection? selection, String? error})>
      createSelection({
    required String title,
    String? description,
    List<RestaurantSelectionItem> items = const [],
    bool isPublic = false,
  }) =>
          _submitSelection((dio) => dio.post(
                '/restaurant-selections/',
                data: {
                  'title': title,
                  'description': description,
                  'items': _itemsJson(items),
                  'is_public': isPublic,
                },
                options: _auth,
              ));

  /// Replaces the title, description and restaurants (order and notes) of
  /// a selection; [makePublic] publishes it, for good. On refusal, [error]
  /// carries the API's reason.
  static Future<({RestaurantSelection? selection, String? error})>
      updateSelection({
    required int id,
    required String title,
    String? description,
    required List<RestaurantSelectionItem> items,
    bool makePublic = false,
  }) =>
          _submitSelection((dio) => dio.put(
                '/restaurant-selections/$id',
                data: {
                  'title': title,
                  'description': description,
                  'items': _itemsJson(items),
                  if (makePublic) 'is_public': true,
                },
                options: _auth,
              ));

  /// Sets the cover image of the user's selection, replacing the previous
  /// one. On failure, [error] says why, in words for the user.
  static Future<({RestaurantSelection? selection, String? error})>
      uploadSelectionCover({required int id, required File image}) =>
          _submitSelection(
            (dio) async => dio.put(
              '/restaurant-selections/$id/cover',
              data: FormData.fromMap({'file': await _file(image)}),
              options: _multipartAuth,
            ),
            errorOf: _photoErrorMessage,
          );

  /// Removes the cover image of the user's selection: the photos of its
  /// places show instead. False on failure.
  static Future<bool> removeSelectionCover(int id) => _ok(
      (dio) => dio.delete('/restaurant-selections/$id/cover', options: _auth));

  static Future<bool> deleteSelection(int id) =>
      _ok((dio) => dio.delete('/restaurant-selections/$id', options: _auth));

  /// Adds the restaurant at the end of the selection, or removes it when
  /// [inSelection] is false. False on failure.
  static Future<bool> setRestaurantInSelection({
    required int selectionId,
    required int restaurantId,
    required bool inSelection,
  }) {
    final path =
        '/restaurant-selections/$selectionId/restaurants/$restaurantId';
    return _ok((dio) => inSelection
        ? dio.put(path, options: _auth)
        : dio.delete(path, options: _auth));
  }

  /// Sends the selection to a user, by [email] or by [friendCode]. By
  /// email, the API answers the same whether it has an account or not; by
  /// friend code, [recipientNickname] tells who received it, and an
  /// unknown code is a failure with [notFound]. On refusal, [error] carries
  /// the API's reason when there is one.
  static Future<
          ({bool ok, String? recipientNickname, bool notFound, String? error})>
      sendSelection({
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

  /// Accepts a selection sent to the user, or takes a public one: it shows
  /// with their saved places. False on failure.
  static Future<bool> acceptSelection(int id) => _ok(
      (dio) => dio.put('/restaurant-selections/$id/accept', options: _auth));

  /// Refuses a selection sent to the user, or removes it once accepted. It
  /// won't come back if sent again. False on failure.
  static Future<bool> removeReceivedSelection(int id) => _ok((dio) =>
      dio.delete('/restaurant-selections/$id/received', options: _auth));

  // ── Reviews ──────────────────────────────────────────────────────────────

  static Future<RestaurantReviewSummary?> getReviewSummary(int restaurantId) =>
      _fetch(
        (dio) => dio.get(
          '/restaurant-reviews/restaurants/$restaurantId/summary',
          options: _auth,
        ),
        (data) =>
            RestaurantReviewSummary.fromJson(data as Map<String, dynamic>),
      );

  /// Approved reviews of a restaurant, newest first. Null on failure.
  static Future<Paged<RestaurantReview>?> getReviews({
    required int restaurantId,
    int page = 1,
    int pageSize = 10,
  }) =>
      _fetch(
        (dio) => dio.get(
          '/restaurant-reviews/search',
          queryParameters: {
            'restaurant_id': restaurantId,
            'status': 'APPROVED',
            'page': page,
            'page_size': pageSize,
          },
          options: _auth,
        ),
        (data) => _page(data, _review),
      );

  /// Every restaurant review of the user, whatever its status, newest
  /// first. Null on failure.
  static Future<Paged<RestaurantReview>?> getMyReviews({
    int page = 1,
    int pageSize = 20,
  }) async {
    final userId = AuthService.currentUser?.id;
    if (userId == null) return null;
    return _fetch(
      (dio) => dio.get(
        '/restaurant-reviews/search',
        queryParameters: {
          'user_id': userId,
          'page': page,
          'page_size': pageSize,
        },
        options: _auth,
      ),
      (data) => _page(data, _review),
    );
  }

  /// A review by its id (approved, or the user's own). Null on failure.
  static Future<RestaurantReview?> getReview(int id) => _fetch(
      (dio) => dio.get('/restaurant-reviews/$id', options: _auth), _review);

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
    final items = _page(response.data, _review).items;
    return items.isNotEmpty ? items.first : null;
  }

  /// Creates the user's review ([criteria] by [RestaurantCriterion.field],
  /// [priceRange] a [RestaurantPriceRanges] value).
  static Future<RestaurantReview?> postReview({
    required int restaurantId,
    required int rating,
    Map<String, int?> criteria = const {},
    String? priceRange,
    String? comment,
  }) =>
      _fetch(
        (dio) => dio.post(
          '/restaurant-reviews/',
          data: {
            'restaurant_id': restaurantId,
            'rating': rating,
            ...criteria,
            if (priceRange != null) 'price_range': priceRange,
            if (comment != null && comment.isNotEmpty) 'comment': comment,
          },
          options: _auth,
        ),
        _review,
      );

  /// Updates the user's review; a null criterion or [priceRange] clears it.
  static Future<RestaurantReview?> updateReview({
    required int reviewId,
    required int rating,
    Map<String, int?> criteria = const {},
    String? priceRange,
    String? comment,
  }) =>
      _fetch(
        (dio) => dio.put(
          '/restaurant-reviews/$reviewId',
          data: {
            'rating': rating,
            ...criteria,
            'price_range': priceRange,
            'comment': comment,
          },
          options: _auth,
        ),
        _review,
      );

  /// Adds a photo to the user's review, which goes back to moderation.
  static Future<bool> uploadReviewPhoto({
    required int reviewId,
    required File photo,
  }) =>
      _ok((dio) async => dio.post(
            '/restaurant-reviews/$reviewId/photos',
            data: FormData.fromMap({'file': await _file(photo)}),
            options: _multipartAuth,
          ));

  static Future<bool> deleteReviewPhoto({
    required int reviewId,
    required int photoId,
  }) =>
      _ok((dio) => dio.delete(
            '/restaurant-reviews/$reviewId/photos/$photoId',
            options: _auth,
          ));

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
  static Future<Paged<RestaurantSuggestion>?> getMySuggestions({
    int page = 1,
    int pageSize = 20,
  }) async {
    final userId = AuthService.currentUser?.id;
    if (userId == null) return null;
    return _fetch(
      (dio) => dio.get(
        '/restaurant-suggestions/search',
        // The API returns everyone's to moderators
        queryParameters: {
          'user_id': userId,
          'page': page,
          'page_size': pageSize,
        },
        options: _auth,
      ),
      (data) => _page(
          data,
          (json) =>
              RestaurantSuggestion.fromJson(json as Map<String, dynamic>)),
    );
  }

  static Future<bool> withdrawSuggestion(int id) =>
      _ok((dio) => dio.delete('/restaurant-suggestions/$id', options: _auth));
}
