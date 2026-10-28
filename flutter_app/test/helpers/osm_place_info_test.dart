import 'package:flutter_test/flutter_test.dart';
import 'package:vegan_app/helpers/osm_place_info.dart';
import 'package:vegan_app/models/restaurants/restaurant.dart';
import 'package:vegan_app/services/geocoding_service.dart';

PlaceResult place({
  String? osmClass,
  String? osmType,
  String? name,
  Map<String, String> tags = const {},
}) =>
    PlaceResult(
      displayName: 'x',
      latitude: 45.75,
      longitude: 4.83,
      name: name,
      osmClass: osmClass,
      osmType: osmType,
      tags: tags,
    );

void main() {
  group('OsmPlaceInfo.from', () {
    test('an address is not a place', () {
      expect(
          OsmPlaceInfo.from(place(
              osmClass: 'highway', osmType: 'residential', name: 'Rue X')),
          isNull);
      expect(OsmPlaceInfo.from(place(osmClass: 'place', osmType: 'house')),
          isNull);
    });

    test('a vegan café with its OSM tags', () {
      final info = OsmPlaceInfo.from(place(
        osmClass: 'amenity',
        osmType: 'cafe',
        name: 'Le Kitchen',
        tags: {
          'diet:vegan': 'only',
          'opening_hours': 'Mo-Fr 08:00-18:30',
          'contact:phone': '+33 6 03 36 42 75',
          'website': 'https://www.lekitchenlyon.com/',
          'contact:instagram': 'lekitchenlyon',
          'takeaway': 'yes',
          'outdoor_seating': 'yes',
        },
      ))!;
      expect(info.name, 'Le Kitchen');
      expect(info.tags, {'cafe'});
      expect(info.veganStatus, VeganStatus.fullyVegan);
      expect(info.serviceOptions, {'dine_in', 'takeaway'});
      expect(info.openingHours!.length, 5);
      expect(info.phone, '+33 6 03 36 42 75');
      expect(info.website, 'https://www.lekitchenlyon.com/');
      expect(info.instagram, 'lekitchenlyon');
      expect(info.facebook, isNull);
    });

    test('vegan options, takeaway only, unknown hours', () {
      final info = OsmPlaceInfo.from(place(
        osmClass: 'amenity',
        osmType: 'fast_food',
        tags: {
          'diet:vegan': 'yes',
          'takeaway': 'only',
          'outdoor_seating': 'yes',
          'opening_hours': 'Mo-Fr 11:00-14:00; PH off',
        },
      ))!;
      expect(info.veganStatus, VeganStatus.veganOptions);
      expect(info.serviceOptions, {'takeaway'});
      expect(info.openingHours, isNull);
      expect(info.tags, {'fast_food'});
    });

    test('a hotel, no vegan info', () {
      final info = OsmPlaceInfo.from(
          place(osmClass: 'tourism', osmType: 'guest_house'))!;
      expect(info.tags, {'guesthouse'});
      expect(info.veganStatus, isNull);
      expect(info.serviceOptions, isEmpty);
    });
  });
}
