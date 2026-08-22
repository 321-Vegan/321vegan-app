import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../themes/app_shapes.dart';

extension LocalWallClock on DateTime {
  /// Reinterprets this DateTime's fields as local time instead of converting.
  /// The backend serializes local timestamps (e.g. "vegan_since") with an
  /// incorrect trailing "Z", so `.toLocal()` would shift them again.
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
        top: 60,
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
    Future.delayed(const Duration(seconds: 3))
        .then((value) => overlayEntry.remove());
  }
}
