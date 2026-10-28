import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vegan_app/helpers/map_search_history.dart';
import 'package:vegan_app/models/restaurants/restaurant.dart';
import 'package:vegan_app/services/geocoding_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps the last choices, newest first, without duplicates', () async {
    final kitchen = Restaurant.fromJson({
      'id': 7,
      'name': 'Le Kitchen',
      'latitude': 45.76,
      'longitude': 4.83,
      'city': 'Lyon',
      'tags': ['restaurant', 'cafe'],
      'vegan_status': 'FULLY_VEGAN',
    });
    final marseille = PlaceResult(
        displayName: 'Marseille', latitude: 43.29, longitude: 5.37);

    await MapSearchHistory.add(kitchen);
    await MapSearchHistory.add(marseille);
    await MapSearchHistory.add(kitchen);

    final history = await MapSearchHistory.all();
    expect(history.map((e) => e.title), ['Le Kitchen', 'Marseille']);
    final restaurant = history.first.result as Restaurant;
    expect(restaurant.id, 7);
    expect(restaurant.city, 'Lyon');
    expect(restaurant.tags, ['restaurant', 'cafe']);
    expect(restaurant.isFullyVegan, isTrue);
    expect((history.last.result as PlaceResult).latitude, 43.29);

    await MapSearchHistory.remove(history.first);
    expect((await MapSearchHistory.all()).map((e) => e.title), ['Marseille']);
  });
}
