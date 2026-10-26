import '../models/restaurants/restaurant.dart';
import '../services/geocoding_service.dart';
import 'osm_opening_hours.dart';

/// What an OpenStreetMap place says about itself, in the restaurant form's
/// terms. Each field is null (or empty) when OSM doesn't say.
class OsmPlaceInfo {
  final String? name;
  final Set<String> tags;
  final String? veganStatus;

  /// True when OSM says gluten free food is served (diet:gluten_free).
  final bool glutenFree;
  final Set<String> serviceOptions;
  final List<OpeningSlot>? openingHours;
  final String? phone;
  final String? website;
  final String? facebook;
  final String? instagram;
  final String? menuUrl;

  const OsmPlaceInfo({
    this.name,
    this.tags = const {},
    this.veganStatus,
    this.glutenFree = false,
    this.serviceOptions = const {},
    this.openingHours,
    this.phone,
    this.website,
    this.facebook,
    this.instagram,
    this.menuUrl,
  });

  /// OSM category/type → restaurant tag.
  static const _tagByOsmType = {
    'amenity': {
      'restaurant': 'restaurant',
      'cafe': 'cafe',
      'fast_food': 'fast_food',
      'bar': 'bar',
      'pub': 'bar',
      'ice_cream': 'ice_cream',
      'food_court': 'restaurant',
    },
    'shop': {
      'bakery': 'bakery',
      'pastry': 'bakery',
      'deli': 'grocery',
      'convenience': 'grocery',
      'greengrocer': 'grocery',
      'health_food': 'grocery',
    },
    'tourism': {
      'hotel': 'hotel',
      'guest_house': 'guesthouse',
      'hostel': 'hostel',
    },
  };

  static const _placeClasses = {'amenity', 'shop', 'tourism', 'craft'};

  /// Null when [place] is an address, not a place (a street has a "name"
  /// too).
  static OsmPlaceInfo? from(PlaceResult place) {
    if (!_placeClasses.contains(place.osmClass)) return null;
    final osm = place.tags;
    String? tag(List<String> keys) {
      for (final key in keys) {
        final value = osm[key]?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    final tagValue = _tagByOsmType[place.osmClass]?[place.osmType];
    final takeaway = osm['takeaway'];
    return OsmPlaceInfo(
      name: place.name,
      tags: {if (tagValue != null) tagValue},
      veganStatus: switch (osm['diet:vegan']) {
        'only' => VeganStatus.fullyVegan,
        'yes' || 'limited' => VeganStatus.veganOptions,
        _ => null,
      },
      glutenFree: const {'yes', 'only', 'limited'}
          .contains(osm['diet:gluten_free']),
      serviceOptions: {
        if (takeaway != 'only' &&
            (osm['indoor_seating'] == 'yes' || osm['outdoor_seating'] == 'yes'))
          RestaurantServiceOptions.dineIn,
        if (takeaway == 'yes' || takeaway == 'only')
          RestaurantServiceOptions.takeaway,
        if (osm['delivery'] == 'yes') RestaurantServiceOptions.delivery,
      },
      openingHours: parseOsmOpeningHours(osm['opening_hours']),
      phone: tag(['phone', 'contact:phone']),
      website: tag(['website', 'contact:website']),
      facebook: tag(['contact:facebook', 'facebook']),
      instagram: tag(['contact:instagram', 'instagram']),
      menuUrl: tag(['website:menu', 'menu:url']),
    );
  }
}
