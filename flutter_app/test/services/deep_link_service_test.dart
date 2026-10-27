import 'package:flutter_test/flutter_test.dart';
import 'package:vegan_app/models/restaurants/restaurant.dart';
import 'package:vegan_app/models/restaurants/restaurant_selection.dart';
import 'package:vegan_app/services/deep_link_service.dart';

DeepLink? _parse(String url) => DeepLinkService.parse(Uri.parse(url));

void main() {
  group('DeepLinkService.parse', () {
    test('a selection, with or without its title', () {
      expect(_parse('https://321vegan.fr/selection/42-mes-restos-a-lyon'),
          const SelectionLink(42));
      expect(_parse('https://321vegan.fr/selection/42'),
          const SelectionLink(42));
    });

    test('a restaurant, with or without its name', () {
      expect(_parse('https://321vegan.fr/restaurant/7-vegorilla'),
          const RestaurantLink(7));
      expect(_parse('https://321vegan.fr/restaurant/7/'),
          const RestaurantLink(7));
    });

    test('anything else is ignored', () {
      expect(_parse('https://321vegan.fr/'), isNull);
      expect(_parse('https://321vegan.fr/restaurant/vegorilla'), isNull);
      expect(_parse('https://321vegan.fr/restaurant/7-vegorilla/photos'),
          isNull);
      expect(_parse('https://321vegan.fr/s/42'), isNull);
      expect(_parse('https://example.com/restaurant/7'), isNull);
    });
  });

  group('links to share', () {
    test('a restaurant link carries its name without accents', () {
      const restaurant = Restaurant(
        id: 7,
        name: 'Le Végé d\'à côté !',
        latitude: 45,
        longitude: 4,
        veganStatus: 'FULLY_VEGAN',
      );
      final url = DeepLinkService.restaurantUrl(restaurant);
      expect(url, 'https://321vegan.fr/restaurant/7-le-vege-d-a-cote');
      expect(_parse(url), const RestaurantLink(7));
    });

    test('a selection link opens the same selection', () {
      const selection = RestaurantSelection(
          id: 42, title: 'Mes restos à Lyon', ownerNickname: 'c', isOwner: true);
      final url = DeepLinkService.selectionUrl(selection);
      expect(url, 'https://321vegan.fr/selection/42-mes-restos-a-lyon');
      expect(_parse(url), const SelectionLink(42));
    });
  });
}
