import 'package:flutter/material.dart';
import '../../themes/app_colors.dart';

/// Paints the app's default background gradient behind [child].
/// Wrap a page's whole subtree (including its Scaffold, made transparent)
/// so the gradient also shows through the status-bar and app-bar areas.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kBackgroundGradientTop, kBackgroundGradientBottom],
        ),
      ),
      child: child,
    );
  }
}
