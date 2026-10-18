class ShopReviewSummary {
  final int shopId;
  final int reviewCount;
  final double ratingAvg;

  ShopReviewSummary({
    required this.shopId,
    required this.reviewCount,
    required this.ratingAvg,
  });

  factory ShopReviewSummary.fromJson(Map<String, dynamic> json) {
    return ShopReviewSummary(
      shopId: json['shop_id'] as int,
      reviewCount: json['review_count'] as int,
      ratingAvg: (json['rating_avg'] as num).toDouble(),
    );
  }
}

class ShopReview {
  final int id;
  final int shopId;
  final int userId;
  final String? userNickname;
  final bool userIsPremium;
  final int rating;
  final String? comment;
  final String status;
  final DateTime? createdAt;

  ShopReview({
    required this.id,
    required this.shopId,
    required this.userId,
    this.userNickname,
    this.userIsPremium = false,
    required this.rating,
    this.comment,
    required this.status,
    this.createdAt,
  });

  factory ShopReview.fromJson(Map<String, dynamic> json) {
    return ShopReview(
      id: json['id'] as int,
      shopId: json['shop_id'] as int,
      userId: json['user_id'] as int,
      userNickname: json['user_nickname'] as String?,
      userIsPremium: json['user_is_premium'] == true,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      status: (json['status'] as String? ?? 'pending').toLowerCase(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class ShopReviewPaginated {
  final List<ShopReview> items;
  final int total;
  final int page;
  final int size;
  final int pages;

  ShopReviewPaginated({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
    required this.pages,
  });

  factory ShopReviewPaginated.fromJson(Map<String, dynamic> json) {
    return ShopReviewPaginated(
      items: (json['items'] as List<dynamic>)
          .map((e) => ShopReview.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      size: json['size'] as int,
      pages: json['pages'] as int,
    );
  }
}
