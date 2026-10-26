import '../review_status.dart';
import 'restaurant.dart';

export '../review_status.dart';

/// Detailed rating of a restaurant review, besides the overall experience.
class RestaurantCriterion {
  /// Key in the summary's `criteria` map.
  final String key;

  /// Field of the review in the API.
  final String field;
  final String label;

  const RestaurantCriterion(this.key, this.field, this.label);

  static const all = [
    RestaurantCriterion('choice', 'rating_choice', 'Choix végane'),
    RestaurantCriterion('value', 'rating_value', 'Rapport qualité-prix'),
    RestaurantCriterion('taste', 'rating_taste', 'Goût'),
    RestaurantCriterion('service', 'rating_service', 'Accueil'),
  ];
}

/// Price per person in a review, mirrors the API price ranges, cheapest
/// first.
class RestaurantPriceRanges {
  RestaurantPriceRanges._();

  static const all = [
    ('UNDER_10', '< 10 €'),
    ('FROM_10_TO_20', '10 – 20 €'),
    ('FROM_20_TO_30', '20 – 30 €'),
    ('FROM_30_TO_50', '30 – 50 €'),
    ('OVER_50', '> 50 €'),
  ];

  static String label(String value) =>
      all.firstWhere((r) => r.$1 == value, orElse: () => (value, value)).$2;
}

class RestaurantCriterionSummary {
  final double? ratingAvg;
  final int ratingCount;

  const RestaurantCriterionSummary({this.ratingAvg, this.ratingCount = 0});
}

/// Approved reviews stats of a restaurant (GET
/// /restaurant-reviews/restaurants/{id}/summary).
class RestaurantReviewSummary {
  final int reviewCount;
  final double ratingAvg;

  /// Number of approved reviews per overall rating, 1 to 5.
  final Map<int, int> distribution;

  /// By [RestaurantCriterion.key].
  final Map<String, RestaurantCriterionSummary> criteria;

  /// Price per person most chosen in the reviews ([RestaurantPriceRanges]
  /// value), null when no review gave one.
  final String? priceRange;

  /// Number of reviews per price range.
  final Map<String, int> priceRangeDistribution;

  const RestaurantReviewSummary({
    required this.reviewCount,
    required this.ratingAvg,
    this.distribution = const {},
    this.criteria = const {},
    this.priceRange,
    this.priceRangeDistribution = const {},
  });

  factory RestaurantReviewSummary.fromJson(Map<String, dynamic> json) {
    final rawDistribution = json['rating_distribution'] as Map? ?? const {};
    final rawCriteria = json['criteria'] as Map? ?? const {};
    return RestaurantReviewSummary(
      reviewCount: json['review_count'] as int? ?? 0,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
      distribution: {
        for (final entry in rawDistribution.entries)
          if (int.tryParse('${entry.key}') case final value?)
            value: (entry.value as num).toInt(),
      },
      criteria: {
        for (final entry in rawCriteria.entries)
          '${entry.key}': RestaurantCriterionSummary(
            ratingAvg: (entry.value['rating_avg'] as num?)?.toDouble(),
            ratingCount: entry.value['rating_count'] as int? ?? 0,
          ),
      },
      priceRange: json['price_range'] as String?,
      priceRangeDistribution: {
        for (final entry
            in (json['price_range_distribution'] as Map? ?? const {}).entries)
          '${entry.key}': (entry.value as num).toInt(),
      },
    );
  }
}

class RestaurantReview {
  final int id;
  final int restaurantId;

  /// Name and city of the reviewed restaurant (for the user's own list).
  final String? restaurantName;
  final String? restaurantCity;
  final int? userId;
  final String? userNickname;
  final bool userIsPremium;

  /// Overall experience, the rating shown on the map.
  final int rating;

  /// Detailed ratings by [RestaurantCriterion.field], when given.
  final Map<String, int> criteria;

  /// Price per person ([RestaurantPriceRanges] value), when given.
  final String? priceRange;
  final String? comment;
  final ReviewStatus status;
  final List<RestaurantPhoto> photos;
  final DateTime? createdAt;

  const RestaurantReview({
    required this.id,
    required this.restaurantId,
    this.restaurantName,
    this.restaurantCity,
    this.userId,
    this.userNickname,
    this.userIsPremium = false,
    required this.rating,
    this.criteria = const {},
    this.priceRange,
    this.comment,
    required this.status,
    this.photos = const [],
    this.createdAt,
  });

  factory RestaurantReview.fromJson(Map<String, dynamic> json) {
    final restaurant = json['restaurant'] as Map<String, dynamic>?;
    return RestaurantReview(
      id: json['id'] as int,
      restaurantId: json['restaurant_id'] as int,
      restaurantName: restaurant?['name'] as String?,
      restaurantCity: restaurant?['city'] as String?,
      userId: json['user_id'] as int?,
      userNickname: json['user_nickname'] as String?,
      userIsPremium: json['user_is_premium'] == true,
      rating: json['rating'] as int,
      criteria: {
        for (final criterion in RestaurantCriterion.all)
          if (json[criterion.field] case final int value)
            criterion.field: value,
      },
      priceRange: json['price_range'] as String?,
      comment: json['comment'] as String?,
      status: ReviewStatus.fromApi(json['status'] as String?),
      photos: (json['photos'] as List<dynamic>? ?? [])
          .map((e) => RestaurantPhoto.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class RestaurantReviewPaginated {
  final List<RestaurantReview> items;
  final int total;
  final int pages;

  const RestaurantReviewPaginated({
    required this.items,
    required this.total,
    required this.pages,
  });

  factory RestaurantReviewPaginated.fromJson(Map<String, dynamic> json) {
    return RestaurantReviewPaginated(
      items: (json['items'] as List<dynamic>)
          .map((e) => RestaurantReview.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      pages: json['pages'] as int,
    );
  }
}
