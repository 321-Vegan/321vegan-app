import 'package:flutter_test/flutter_test.dart';
import 'package:vegan_app/models/product_rating.dart';

void main() {
  group('ProductRating', () {
    test('fromJson reads the API product review', () {
      final json = {
        'id': 3,
        'product_id': 158663,
        'product': {
          'id': 158663,
          'ean': '3017620422003',
          'name': 'Pâte à tartiner',
          'brand_name': 'Marque',
        },
        'user_id': 12,
        'user_nickname': 'AnneKe',
        'user_is_premium': true,
        'rating': 4,
        'comment': 'Très bon !',
        'status': 'PENDING',
        'created_at': '2026-10-16T15:01:54.313018+0000',
      };

      final rating = ProductRating.fromJson(json);

      expect(rating.id, 3);
      expect(rating.ean, '3017620422003');
      expect(rating.productName, 'Pâte à tartiner');
      expect(rating.brandName, 'Marque');
      expect(rating.userNickname, 'AnneKe');
      expect(rating.userIsPremium, isTrue);
      expect(rating.rating, 4);
      expect(rating.hasComment, isTrue);
      expect(rating.status, ReviewStatus.pending);
      expect(rating.createdAt, isNotNull);
    });

    test('fromJson treats an empty product name as missing', () {
      final rating = ProductRating.fromJson({
        'id': 1,
        'product_id': 1,
        'product': {'ean': '123', 'name': '  '},
        'rating': 5,
        'status': 'APPROVED',
      });

      expect(rating.productName, isNull);
      expect(rating.userIsPremium, isFalse);
      expect(rating.hasComment, isFalse);
      expect(rating.status, ReviewStatus.approved);
    });
  });

  group('ReviewStatus', () {
    test('fromApi is case-insensitive and defaults to pending', () {
      expect(ReviewStatus.fromApi('approved'), ReviewStatus.approved);
      expect(ReviewStatus.fromApi('REJECTED'), ReviewStatus.rejected);
      expect(ReviewStatus.fromApi(null), ReviewStatus.pending);
    });
  });

  group('ProductRatingSummary', () {
    test('fromJson parses the distribution keys', () {
      final summary = ProductRatingSummary.fromJson({
        'product_id': 1,
        'review_count': 3,
        'comment_count': 1,
        'rating_avg': 4.3,
        'rating_distribution': {'0': 0, '3': 1, '5': 2},
      });

      expect(summary.hasRatings, isTrue);
      expect(summary.ratingAvg, 4.3);
      expect(summary.distribution[5], 2);
      expect(summary.distribution[3], 1);
    });

    test('hasRatings is false without approved ratings', () {
      final summary = ProductRatingSummary.fromJson({
        'product_id': 1,
        'review_count': 0,
        'comment_count': 0,
        'rating_avg': 0.0,
        'rating_distribution': {},
      });

      expect(summary.hasRatings, isFalse);
    });
  });
}
