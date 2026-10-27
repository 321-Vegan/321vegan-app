import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../models/restaurants/restaurant_selection.dart';

/// Links to a public selection,
/// https://321vegan.fr/selection/42-mes-restos-a-lyon:
/// the system opens the app with them when it's installed (Universal Links /
/// App Links, set up by the site's /.well-known files), the site's page
/// offers to install it otherwise.
class DeepLinkService {
  DeepLinkService._();

  static const _host = '321vegan.fr';

  /// "42" or "42-mes-restos-a-lyon": only the id is read, so a link keeps
  /// working once the selection is renamed.
  static final _selectionPath = RegExp(r'^(\d+)(-[a-z0-9-]*)?$');

  /// The selection of the last link opened, until the home page opens it
  /// and sets it back to null. Set before the home page exists on a cold
  /// start (or during the onboarding): it reads it once built.
  static final ValueNotifier<int?> selectionId = ValueNotifier<int?>(null);

  static StreamSubscription<Uri>? _subscription;

  /// Listens to the links opened, the one that launched the app included.
  static void init() {
    _subscription ??= AppLinks().uriLinkStream.listen((uri) {
      final id = _selectionIdOf(uri);
      if (id != null) selectionId.value = id;
    });
  }

  /// "/selection/42-mes-restos-a-lyon" → 42; null for any other link.
  static int? _selectionIdOf(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (uri.host != _host ||
        segments.length != 2 ||
        segments[0] != 'selection') {
      return null;
    }
    final match = _selectionPath.firstMatch(segments[1]);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// The link to share for a public selection, its title readable in it.
  static String selectionUrl(RestaurantSelection selection) {
    final slug = _slug(selection.title);
    final path = '${selection.id}${slug.isEmpty ? '' : '-$slug'}';
    return 'https://$_host/selection/$path';
  }

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
