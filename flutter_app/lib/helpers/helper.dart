import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../themes/app_shapes.dart';

extension LocalWallClock on DateTime {
  /// Reinterprets this DateTime's calendar/clock fields as local time,
  /// discarding any UTC flag instead of converting.
  ///
  /// The backend serializes already-local timestamps (e.g. "vegan_since")
  /// with an incorrect trailing "Z", so `DateTime.parse` mislabels them as
  /// UTC. Calling `.toLocal()` on that mislabeled value would shift it by
  /// the device's timezone offset *again*, pushing it further into the
  /// future. This keeps the same year/month/day/hour/... fields and just
  /// drops the wrong UTC tag.
  DateTime asLocalWallClock() => isUtc
      ? DateTime(
          year, month, day, hour, minute, second, millisecond, microsecond)
      : this;
}

extension StringCasingExtension on String {
  String toCapitalized() =>
      length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
  String toTitleCase() => replaceAll(RegExp(' +'), ' ')
      .split(' ')
      .map((str) => str.toCapitalized())
      .join(' ');
}

class Helper {
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static void saveLastSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSearch', query);
  }

  static void saveLastSearchCosmetics(String query) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSearchCosmetics', query);
  }

  static void showTopSnackBar(
      BuildContext context, Widget content, Color color) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 60, // Distance from the top
        left: MediaQuery.of(context).size.width * 0,
        width: MediaQuery.of(context).size.width,
        child: Material(
          elevation: 10.0,
          shape: squircleBorder(radius: 10),
          child: Container(
            padding: const EdgeInsets.all(8),
            color: color,
            child: content,
          ),
        ),
      ),
    );
    overlay.insert(overlayEntry);
    // Automatically remove the snack bar after some duration
    Future.delayed(const Duration(seconds: 3))
        .then((value) => overlayEntry.remove());
  }
}
