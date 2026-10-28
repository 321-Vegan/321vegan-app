import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] outside the app (browser, phone, mail...), with [errorText]
/// in a snack bar when nothing can open it.
Future<void> openExternalUrl(
  BuildContext context,
  Uri url, {
  String errorText = 'Impossible d\'ouvrir le lien.',
}) async {
  final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorText, style: TextStyle(fontSize: 44.sp))),
    );
  }
}

/// Google Maps directions to a point.
Future<void> openItinerary(
        BuildContext context, double latitude, double longitude) =>
    openExternalUrl(
      context,
      Uri.parse('https://www.google.com/maps/dir/?api=1'
          '&destination=$latitude,$longitude'),
      errorText: 'Impossible d\'ouvrir l\'itinéraire.',
    );
