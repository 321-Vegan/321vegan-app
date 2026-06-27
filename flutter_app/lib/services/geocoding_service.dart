import 'dart:convert';
import 'package:http/http.dart' as http;

/// A geocoded place returned by Nominatim (OpenStreetMap).
class PlaceResult {
  final String displayName;
  final double latitude;
  final double longitude;

  PlaceResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    return PlaceResult(
      displayName: json['display_name'] ?? '',
      latitude: double.tryParse(json['lat']?.toString() ?? '') ?? 0,
      longitude: double.tryParse(json['lon']?.toString() ?? '') ?? 0,
    );
  }
}

/// Forward geocoding (place/city/address search) backed by OpenStreetMap's
class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';

  static Future<List<PlaceResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return [];

    try {
      final url = Uri.parse(_baseUrl).replace(queryParameters: {
        'q': trimmed,
        'format': 'json',
        'limit': '5',
        'addressdetails': '0',
      });

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'fr.321vegan.app',
          'Accept-Language': 'fr',
        },
      );

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
}
