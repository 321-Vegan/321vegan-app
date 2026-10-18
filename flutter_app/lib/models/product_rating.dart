import 'review_status.dart';

export 'review_status.dart';

/// Aggregated approved ratings of a product (GET
/// /product-reviews/products/ean/{ean}/summary).
class ProductRatingSummary {
  final int productId;
  final int ratingCount;
  final int commentCount;
  final double ratingAvg;

  /// Number of approved ratings per value, 1 to 5.
  final Map<int, int> distribution;

  const ProductRatingSummary({
    required this.productId,
    required this.ratingCount,
    required this.commentCount,
    required this.ratingAvg,
    this.distribution = const {},
  });

  bool get hasRatings => ratingCount > 0;

  factory ProductRatingSummary.fromJson(Map<String, dynamic> json) {
    final rawDistribution = json['rating_distribution'] as Map? ?? const {};
    return ProductRatingSummary(
      productId: json['product_id'] as int,
      ratingCount: json['review_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
      distribution: {
        for (final entry in rawDistribution.entries)
          if (int.tryParse('${entry.key}') case final value?)
            value: (entry.value as num).toInt(),
      },
    );
  }
}

/// A user's rating (1 to 5) of a product, with an optional comment.
/// Backed by the API's product reviews (/product-reviews) — named "rating"
/// app-side so it isn't mistaken for the contributors' product validation
/// (`ProductReviewPage`).
class ProductRating {
  final int id;
  final int productId;
  final String ean;
  final String? productName;
  final String? brandName;
  final int? userId;
  final String? userNickname;
  final bool userIsPremium;
  final int rating;
  final String? comment;
  final ReviewStatus status;
  final DateTime? createdAt;

  const ProductRating({
    required this.id,
    required this.productId,
    required this.ean,
    this.productName,
    this.brandName,
    this.userId,
    this.userNickname,
    this.userIsPremium = false,
    required this.rating,
    this.comment,
    required this.status,
    this.createdAt,
  });

  bool get hasComment => comment != null && comment!.isNotEmpty;

  factory ProductRating.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>? ?? {};
    final name = (product['name'] as String?)?.trim();
    return ProductRating(
      id: json['id'] as int,
      productId: json['product_id'] as int,
      ean: product['ean'] as String? ?? '',
      productName: name == null || name.isEmpty ? null : name,
      brandName: product['brand_name'] as String?,
      userId: json['user_id'] as int?,
      userNickname: json['user_nickname'] as String?,
      userIsPremium: json['user_is_premium'] == true,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      status: ReviewStatus.fromApi(json['status'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
          : null,
    );
  }
}

class ProductRatingPaginated {
  final List<ProductRating> items;
  final int total;
  final int pages;

  const ProductRatingPaginated({
    required this.items,
    required this.total,
    required this.pages,
  });

  factory ProductRatingPaginated.fromJson(Map<String, dynamic> json) {
    return ProductRatingPaginated(
      items: (json['items'] as List<dynamic>)
          .map((e) => ProductRating.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      pages: json['pages'] as int,
    );
  }
}
