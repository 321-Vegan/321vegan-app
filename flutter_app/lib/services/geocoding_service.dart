import 'dart:convert';
import 'package:http/http.dart' as http;

/// A geocoded place returned by Nominatim (OpenStreetMap). The address parts
/// are only filled when asked for (`addressDetails`).
class PlaceResult {
  final String displayName;
  final double latitude;
  final double longitude;

  /// "12 rue de la Paix"
  final String? street;
  final String? city;
  final String? country;

  PlaceResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.street,
    this.city,
    this.country,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>?;
    String? street;
    String? city;
    String? country;
    if (address != null) {
      final road = (address['road'] ??
          address['pedestrian'] ??
          address['path'] ??
          address['square'] ??
          '') as String;
      final number = (address['house_number'] ?? '') as String;
      final line = (number.isNotEmpty ? '$number $road' : road).trim();
      street = line.isEmpty ? null : line;
      city = (address['city'] ??
          address['town'] ??
          address['village'] ??
          address['municipality']) as String?;
      country = address['country'] as String?;
    }
    return PlaceResult(
      displayName: json['display_name'] ?? '',
      latitude: double.tryParse(json['lat']?.toString() ?? '') ?? 0,
      longitude: double.tryParse(json['lon']?.toString() ?? '') ?? 0,
      street: street,
      city: city,
      country: country,
    );
  }
}

/// Forward geocoding (place/city/address search) and reverse geocoding
/// backed by OpenStreetMap's Nominatim.
class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const Map<String, String> _headers = {
    'User-Agent': 'fr.321vegan.app',
    'Accept-Language': 'fr',
  };

  static Future<List<PlaceResult>> search(
    String query, {
    bool addressDetails = false,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return [];

    try {
      final url = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'q': trimmed,
        'format': 'json',
        'limit': '5',
        'addressdetails': addressDetails ? '1' : '0',
      });

      final response = await http.get(url, headers: _headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data
            .map((item) => PlaceResult.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// The address at a point, null when unknown or on failure.
  static Future<PlaceResult?> reverse(double latitude, double longitude) async {
    try {
      final url = Uri.parse('$_baseUrl/reverse').replace(queryParameters: {
        'lat': '$latitude',
        'lon': '$longitude',
        'format': 'json',
      });
      final response = await http.get(url, headers: _headers);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data is Map<String, dynamic> && data['address'] != null) {
          return PlaceResult.fromJson(data);
        }
      }
    } catch (_) {}
    return null;
  }
}
