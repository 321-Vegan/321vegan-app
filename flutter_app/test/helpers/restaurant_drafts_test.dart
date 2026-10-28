import 'package:flutter_test/flutter_test.dart';
import 'package:vegan_app/helpers/restaurant_drafts.dart';

void main() {
  group('RestaurantDraft', () {
    test('stores photo file names and rebuilds their paths', () {
      final draft = RestaurantDraft(
        id: '42',
        updatedAt: DateTime(2026, 10, 25, 18),
        fields: const {'name': ' Le Kitchen ', 'city': ''},
        menuPhotos: const ['/old/docs/restaurant_drafts/42/menu.jpg'],
        placePhotos: const [
          '/old/docs/restaurant_drafts/42/a.jpg',
          '/old/docs/restaurant_drafts/42/b.jpg',
        ],
        mainPhoto: '/old/docs/restaurant_drafts/42/b.jpg',
      );

      final json = draft.toJson();
      expect(json['place_photos'], ['a.jpg', 'b.jpg']);
      expect(json['main_photo'], 'b.jpg');

      // The documents folder moved (iOS app update)
      final restored =
          RestaurantDraft.fromJson(json, (id) => '/new/docs/drafts/$id');
      expect(restored.menuPhotos, ['/new/docs/drafts/42/menu.jpg']);
      expect(restored.placePhotos.last, '/new/docs/drafts/42/b.jpg');
      expect(restored.mainPhoto, '/new/docs/drafts/42/b.jpg');
      expect(restored.updatedAt, DateTime(2026, 10, 25, 18));
      expect(restored.name, 'Le Kitchen');
      expect(restored.city, isNull);
    });
  });
}
