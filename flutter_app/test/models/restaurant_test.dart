import 'package:flutter_test/flutter_test.dart';
import 'package:vegan_app/models/restaurants/restaurant.dart';
import 'package:vegan_app/models/restaurants/restaurant_review.dart';

/// 2026-10-26 is a monday.
DateTime monday(int hour, [int minute = 0]) =>
    DateTime(2026, 10, 26, hour, minute);

OpeningSlot slot(int day, String open, String close) =>
    OpeningSlot(day: day, open: open, close: close);

void main() {
  group('OpeningState', () {
    final lunchAndDinner = [
      slot(0, '12:00', '14:30'),
      slot(0, '19:00', '23:00'),
      slot(2, '12:00', '14:30'),
    ];

    test('unknown when there is no slot', () {
      expect(OpeningState.of([], monday(12)), isNull);
    });

    test('open during a slot, with its closing time', () {
      final state = OpeningState.of(lunchAndDinner, monday(13))!;
      expect(state.isOpen, isTrue);
      expect(state.detail, 'ferme à 14:30');
    });

    test('closed between two slots, opening later today', () {
      final state = OpeningState.of(lunchAndDinner, monday(15))!;
      expect(state.isOpen, isFalse);
      expect(state.detail, 'ouvre à 19:00');
    });

    test('closing time itself is closed', () {
      expect(OpeningState.of(lunchAndDinner, monday(14, 30))!.isOpen, isFalse);
    });

    test('next opening on another day', () {
      final state = OpeningState.of(lunchAndDinner, monday(23, 30))!;
      expect(state.detail, 'ouvre mercredi à 12:00');
    });

    test('next opening tomorrow', () {
      final state = OpeningState.of([slot(1, '09:00', '18:00')], monday(20))!;
      expect(state.detail, 'ouvre demain à 09:00');
    });

    test('a slot past midnight is open early the next day', () {
      // Sunday 22:00 → monday 02:00
      final slots = [slot(6, '22:00', '02:00')];
      final state = OpeningState.of(slots, monday(1, 30))!;
      expect(state.isOpen, isTrue);
      expect(state.detail, 'ferme à 02:00');
      expect(OpeningState.of(slots, monday(2, 30))!.isOpen, isFalse);
    });

    test('a slot past midnight is open late on its own day', () {
      expect(
          OpeningState.of([slot(0, '18:00', '02:00')], monday(23))!.isOpen,
          isTrue);
    });
  });

  group('OpeningSlot.anyOverlap', () {
    test('two separate slots on the same day', () {
      expect(
          OpeningSlot.anyOverlap(
              [slot(0, '12:00', '14:30'), slot(0, '19:00', '23:00')]),
          isFalse);
    });

    test('overlapping slots on the same day', () {
      expect(
          OpeningSlot.anyOverlap(
              [slot(0, '12:00', '15:00'), slot(0, '14:00', '18:00')]),
          isTrue);
    });

    test('a slot past midnight overlapping the next day', () {
      expect(
          OpeningSlot.anyOverlap(
              [slot(4, '18:00', '02:00'), slot(5, '01:00', '03:00')]),
          isTrue);
    });

    test('sunday night overlapping monday morning', () {
      expect(
          OpeningSlot.anyOverlap(
              [slot(6, '22:00', '02:00'), slot(0, '01:00', '03:00')]),
          isTrue);
    });
  });

  group('Restaurant.fromJson', () {
    test('map pin with rating stats', () {
      final restaurant = Restaurant.fromJson({
        'id': 1,
        'name': 'Le Végé',
        'latitude': 45.75,
        'longitude': 4.83,
        'vegan_status': 'FULLY_VEGAN',
        'tags': ['restaurant', 'cafe'],
        'service_options': ['dine_in', 'takeaway'],
        'has_storefront': true,
        'plant_milk_surcharge': 0.5,
        'opening_hours': [
          {'day': 0, 'open': '12:00', 'close': '14:30'}
        ],
        'operating_status': 'OPEN',
        'is_closed_now': false,
        'validated': true,
        'rating_avg': 4.5,
        'review_count': 2,
        'featured_photo': {
          'id': 7,
          'kind': 'PLACE',
          'path': 'restaurants/1/place_a.jpg',
          'status': 'APPROVED',
          'is_featured': true,
        },
      });

      expect(restaurant.isFullyVegan, isTrue);
      expect(restaurant.tags, ['restaurant', 'cafe']);
      expect(restaurant.serviceOptions, ['dine_in', 'takeaway']);
      expect(RestaurantServiceOptions.label('takeaway'), 'À emporter');
      expect(restaurant.plantMilkSurcharge, 0.5);
      expect(restaurant.openingHours.single.label, '12:00 – 14:30');
      expect(restaurant.ratingAvg, 4.5);
      expect(restaurant.photos, isEmpty);
      expect(restaurant.featuredPhoto!.isFeatured, isTrue);
      expect(restaurant.featuredPhoto!.path, 'restaurants/1/place_a.jpg');
    });

    test('closed for a period has no opening state', () {
      final restaurant = Restaurant.fromJson({
        'id': 1,
        'name': 'Le Végé',
        'latitude': 45.75,
        'longitude': 4.83,
        'vegan_status': 'VEGAN_OPTIONS',
        'opening_hours': [
          {'day': 0, 'open': '12:00', 'close': '14:30'}
        ],
        'operating_status': 'TEMPORARILY_CLOSED',
        'closed_until': '2026-11-15',
        'is_closed_now': true,
      });

      expect(restaurant.openingStateAt(monday(13)), isNull);
      expect(restaurant.closedUntil, DateTime(2026, 11, 15));
    });
  });

  group('RestaurantReview.fromJson', () {
    test('keeps only the detailed ratings given', () {
      final review = RestaurantReview.fromJson({
        'id': 3,
        'restaurant_id': 1,
        'rating': 4,
        'rating_choice': 5,
        'rating_value': null,
        'status': 'PENDING',
        'photos': [
          {'id': 9, 'review_id': 3, 'path': 'restaurants/1/reviews/3_a.jpg',
           'status': 'PENDING'}
        ],
      });

      expect(review.criteria, {'rating_choice': 5});
      expect(review.status, ReviewStatus.pending);
      expect(review.photos.single.reviewId, 3);
    });
  });

  group('RestaurantReviewSummary.fromJson', () {
    test('parses distribution and criteria', () {
      final summary = RestaurantReviewSummary.fromJson({
        'restaurant_id': 1,
        'review_count': 2,
        'comment_count': 1,
        'rating_avg': 3.5,
        'rating_distribution': {'1': 0, '2': 1, '3': 0, '4': 0, '5': 1},
        'criteria': {
          'choice': {'rating_avg': 4.0, 'rating_count': 2},
          'value': {'rating_avg': null, 'rating_count': 0},
        },
      });

      expect(summary.distribution[2], 1);
      expect(summary.criteria['choice']!.ratingAvg, 4.0);
      expect(summary.criteria['value']!.ratingCount, 0);
    });
  });
}
