import 'package:flutter/material.dart';
import 'app_shapes.dart';

/// Every SnackBar of the app: floating above the bottom with a margin,
/// squircle corners, bold white text. Plain logical points, not ScreenUtil
/// units: the theme is built before ScreenUtil is initialized.
final SnackBarThemeData appSnackBarTheme = SnackBarThemeData(
  behavior: SnackBarBehavior.floating,
  shape: squircleBorder(radius: 12),
  insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
  contentTextStyle: const TextStyle(
    fontFamily: 'Karla',
    fontSize: 15,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  ),
  actionTextColor: Colors.white,
);
