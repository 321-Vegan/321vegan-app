import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';

/// Shared field/button look for the login, register and forgot-password
/// forms (Figma redesign) so the three stay visually identical.
InputDecoration authFieldDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  required IconData icon,
  Widget? suffixIcon,
}) {
  final radius = BorderRadius.circular(24.r);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, size: 44.sp, color: Colors.grey[500]),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFFF7F6F2),
    border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: kBorderDefault),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: kSemanticError),
    ),
  );
}
