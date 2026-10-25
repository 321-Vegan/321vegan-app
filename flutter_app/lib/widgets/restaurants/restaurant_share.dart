import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/restaurants/restaurant.dart';
import '../../models/restaurants/restaurant_review.dart';
import '../../services/restaurant_api_service.dart';
import '../reviews/star_rating.dart';

/// Opens the system share sheet with the restaurant in a few lines: name,
/// kinds of place and vegan status, reviews average, address, a map link and
/// the app. [context] is the tapped button's, for the iPad popover.
///
/// The full restaurant doesn't carry its reviews stats: pass the [summary]
/// when already loaded, otherwise it is fetched (shared without the rating
/// if that fails).
Future<void> shareRestaurant(
  BuildContext context,
  Restaurant restaurant, {
  RestaurantReviewSummary? summary,
}) async {
  final r = restaurant;
  // Read before the await, while the button is still mounted
  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
  final stats =
      summary ?? await RestaurantApiService.getReviewSummary(restaurant.id);
  final rating = stats != null && stats.reviewCount > 0
      ? '★ ${formatRatingAverage(stats.ratingAvg)} '
          '(${formatRatingCount(stats.reviewCount)})'
      : null;

  final details = [
    ...r.tags.map(RestaurantTags.label),
    r.isFullyVegan ? '100 % végane' : 'Options véganes',
  ].join(' · ');
  // Caterers without storefront have no address to visit
  final location = r.hasStorefront
      ? [r.address, r.city].whereType<String>().join(', ')
      : r.city ?? '';
  final mapUrl = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '${r.latitude},${r.longitude}',
  });

  final text = [
    '${r.name} ($details)',
    if (rating != null) rating,
    if (location.isNotEmpty) location,
    if (r.hasStorefront) mapUrl.toString(),
    '',
    'Trouvé sur l\'application 321 Vegan : https://321vegan.fr',
  ].join('\n');

  await Share.share(
    text,
    subject: r.name,
    // Required for the iPad popover
    sharePositionOrigin: origin,
  );
}
