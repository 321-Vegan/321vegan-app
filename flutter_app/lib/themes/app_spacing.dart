import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Vertical rhythm of the redesigned pages, so every screen spaces its
/// blocks identically. Getters because ScreenUtil resolves at runtime.
class AppSpacing {
  AppSpacing._();

  /// Between two sections (24pt in Figma).
  static double get section => 72.h;

  /// Between a section title and its content (14pt).
  static double get afterTitle => 42.h;

  /// Between repeated cards inside a list/section (12pt).
  static double get item => 36.h;
}
