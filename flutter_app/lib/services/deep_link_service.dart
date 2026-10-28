import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../models/restaurants/restaurant.dart';
import '../models/restaurants/restaurant_selection.dart';

/// What a link opens in the app.
sealed class DeepLink {
  final int id;
  const DeepLink(this.id);

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType && other is DeepLink && other.id == id;

  @override
  int get hashCode => Object.hash(runtimeType, id);
}

/// A public selection: https://321vegan.fr/selection/42-mes-restos-a-lyon
class SelectionLink extends DeepLink {
  const SelectionLink(super.id);
}

/// A restaurant: https://321vegan.fr/restaurant/7-vegorilla
class RestaurantLink extends DeepLink {
  const RestaurantLink(super.id);
}

/// Links to a public selection or a restaurant: the system opens the app
/// with them when it's installed (Universal Links / App Links, set up by the
/// site's /.well-known files), the site's page offers to install it
/// otherwise.
class DeepLinkService {
  DeepLinkService._();

  static const _host = '321vegan.fr';

  /// "42" or "42-mes-restos-a-lyon": only the id is read, so a link keeps
  /// working once the selection or restaurant is renamed.
  static final _idPath = RegExp(r'^(\d+)(-[a-z0-9-]*)?$');

  /// The last link opened, until the home page opens it and sets it back
  /// to null. Set before the home page exists on a cold start (or during
  /// the onboarding): it reads it once built.
  static final ValueNotifier<DeepLink?> pending = ValueNotifier(null);

  static StreamSubscription<Uri>? _subscription;

  /// Listens to the links opened, the one that launched the app included.
  static void init() {
    _subscription ??= AppLinks().uriLinkStream.listen((uri) {
      final link = parse(uri);
      if (link != null) pending.value = link;
    });
  }

  /// "/selection/42-mes-restos-a-lyon" → [SelectionLink] 42,
  /// "/restaurant/7-vegorilla" → [RestaurantLink] 7; null for any other
  /// link.
  @visibleForTesting
  static DeepLink? parse(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (uri.host != _host || segments.length != 2) return null;
    final match = _idPath.firstMatch(segments[1]);
    final id = match == null ? null : int.tryParse(match.group(1)!);
    if (id == null) return null;
    return switch (segments[0]) {
      'selection' => SelectionLink(id),
      'restaurant' => RestaurantLink(id),
      _ => null,
    };
  }

  static String _url(String kind, int id, String title) {
    final slug = _slug(title);
    return 'https://$_host/$kind/$id${slug.isEmpty ? '' : '-$slug'}';
  }

  /// The link to share for a public selection, its title readable in it.
  static String selectionUrl(RestaurantSelection selection) =>
      _url('selection', selection.id, selection.title);

  /// The link to share for a restaurant, its name readable in it.
  static String restaurantUrl(Restaurant restaurant) =>
      _url('restaurant', restaurant.id, restaurant.name);

  static const _accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a', //
    'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
    'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i', 'ñ': 'n', //
    'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o', //
    'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', 'ÿ': 'y', //
    'œ': 'oe', 'æ': 'ae',
  };

  /// "Mes restos à Lyon !" → "mes-restos-a-lyon", at most 60 characters
  /// (emojis and other scripts dropped).
  static String _slug(String title) {
    final ascii = title
        .toLowerCase()
        .split('')
        .map((c) => _accents[c] ?? c)
        .join()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (ascii.length <= 60) return ascii;
    return ascii.substring(0, 60).replaceAll(RegExp(r'-+$'), '');
  }
}
