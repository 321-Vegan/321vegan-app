import 'package:flutter_test/flutter_test.dart';
import 'package:vegan_app/models/restaurants/restaurant_selection.dart';

Map<String, dynamic> _json(Map<String, dynamic> fields) => {
      'id': 3,
      'title': 'Brunchs à Lyon',
      'owner_id': 12,
      'owner_nickname': 'Camille',
      'is_owner': false,
      'restaurant_ids': [1, 2],
      ...fields,
    };

void main() {
  group('RestaurantSelection.fromJson', () {
    test('public selection with a cover, not taken yet', () {
      final selection = RestaurantSelection.fromJson(_json({
        'is_public': true,
        'published_at': '2026-10-27T10:00:00.000000+0000',
        'cover_path': 'selections/3/cover_abc.jpg',
        'accepted_count': 4,
      }));

      expect(selection.ownerId, 12);
      expect(selection.isPublic, isTrue);
      expect(selection.publishedAt, DateTime.utc(2026, 10, 27, 10));
      expect(selection.coverPath, 'selections/3/cover_abc.jpg');
      expect(selection.acceptedCount, 4);
      expect(selection.isAccepted, isFalse);
      expect(selection.canTake, isTrue);
    });

    test('a public selection already taken cannot be taken again', () {
      final selection = RestaurantSelection.fromJson(
          _json({'is_public': true, 'share_status': 'ACCEPTED'}));

      expect(selection.isAccepted, isTrue);
      expect(selection.canTake, isFalse);
    });

    test('a public selection removed by the user can be taken again', () {
      final selection = RestaurantSelection.fromJson(
          _json({'is_public': true, 'share_status': 'DECLINED'}));

      expect(selection.canTake, isTrue);
    });

    test('the owner cannot take their own public selection', () {
      final selection = RestaurantSelection.fromJson(
          _json({'is_public': true, 'is_owner': true}));

      expect(selection.canTake, isFalse);
    });

    test('items carry the author\'s rating when they reviewed the place', () {
      final selection = RestaurantSelection.fromJson(_json({
        'items': [
          {
            'restaurant': {
              'id': 1,
              'name': 'Vegorilla',
              'latitude': 43.6,
              'longitude': 3.88,
              'vegan_status': 'FULLY_VEGAN',
            },
            'note': 'Les meilleurs burgers',
            'author_rating': 5,
            'author_review_id': 42,
          },
          {
            'restaurant': {
              'id': 2,
              'name': 'KVB',
              'latitude': 43.6,
              'longitude': 3.88,
              'vegan_status': 'FULLY_VEGAN',
            },
          },
        ],
      }));

      expect(selection.items.first.authorRating, 5);
      expect(selection.items.first.authorReviewId, 42);
      final edited = selection.items.first.copyWith(note: 'Autre');
      expect(edited.authorRating, 5);
      expect(edited.authorReviewId, 42);
      expect(selection.items.last.authorRating, isNull);
      expect(selection.items.last.authorReviewId, isNull);
    });

    test('a private selection is not taken, and has no cover', () {
      final selection = RestaurantSelection.fromJson(
          _json({'share_status': 'PENDING'}));

      expect(selection.isPublic, isFalse);
      expect(selection.canTake, isFalse);
      expect(selection.coverPath, isNull);
      expect(selection.coverUrl, isNull);
    });
  });
}
