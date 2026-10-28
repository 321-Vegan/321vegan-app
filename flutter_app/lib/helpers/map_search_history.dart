import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/restaurants/restaurant.dart';
import '../services/geocoding_service.dart';

/// A place or restaurant chosen in the map search, to offer it again.
class MapSearchHistoryEntry {
  /// [PlaceResult] or [Restaurant], as the search page pops it.
  final Object result;

  const MapSearchHistoryEntry(this.result);

  bool get isRestaurant => result is Restaurant;

  String get title => switch (result) {
        Restaurant r => r.name,
        PlaceResult p => p.displayName,
        _ => '',
      };

  /// Same restaurant, or same place name: one entry each.
  String get _key => switch (result) {
        Restaurant r => 'restaurant:${r.id}',
        PlaceResult p => 'place:${p.displayName}',
        _ => '',
      };

  // A restaurant keeps what its pin and the search row need; its page loads
  // the rest
  Map<String, dynamic> toJson() => switch (result) {
        Restaurant r => {
            'kind': 'restaurant',
            'id': r.id,
            'name': r.name,
            'latitude': r.latitude,
            'longitude': r.longitude,
            'city': r.city,
            'tags': r.tags,
            'vegan_status': r.veganStatus,
            'has_storefront': r.hasStorefront,
            'operating_status': r.operatingStatus,
            'validated': r.validated,
          },
        PlaceResult p => {
            'kind': 'place',
            'display_name': p.displayName,
            'latitude': p.latitude,
            'longitude': p.longitude,
          },
        _ => {},
      };

  static MapSearchHistoryEntry? fromJson(Map<String, dynamic> json) {
    switch (json['kind']) {
      case 'restaurant':
        return MapSearchHistoryEntry(Restaurant.fromJson(json));
      case 'place':
        return MapSearchHistoryEntry(PlaceResult(
          displayName: json['display_name'] as String,
          latitude: (json['latitude'] as num).toDouble(),
          longitude: (json['longitude'] as num).toDouble(),
        ));
    }
    return null;
  }
}

/// The last places and restaurants chosen in the map search, newest first,
/// kept on the device.
class MapSearchHistory {
  MapSearchHistory._();

  static const _key = 'map_search_history';
  static const _max = 10;

  static Future<List<MapSearchHistoryEntry>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return [
        for (final item in jsonDecode(raw) as List)
          if (MapSearchHistoryEntry.fromJson(
                  (item as Map).cast<String, dynamic>())
              case final entry?)
            entry,
      ];
    } catch (_) {
      return [];
    }
  }

  /// Puts [result] first (moved up when already there).
  static Future<void> add(Object result) async {
    final entry = MapSearchHistoryEntry(result);
    final entries = [
      entry,
      for (final e in await all())
        if (e._key != entry._key) e,
    ].take(_max).toList();
    await _write(entries);
  }

  static Future<void> remove(MapSearchHistoryEntry entry) async {
    await _write([
      for (final e in await all())
        if (e._key != entry._key) e,
    ]);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> _write(List<MapSearchHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode([for (final e in entries) e.toJson()]));
  }
}
