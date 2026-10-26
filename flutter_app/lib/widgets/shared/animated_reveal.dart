import 'package:flutter/material.dart';

/// Shows [child] only when [visible], growing from the top and fading in
/// (and the other way round), for the parts of a form that open from a
/// choice. Once closed, [child] leaves the tree, so its fields are no
/// longer validated.
///
/// Takes the full width: for a vertical layout (Column, ListView).
class AnimatedReveal extends StatelessWidget {
  final bool visible;
  final Widget child;
  final Duration duration;

  const AnimatedReveal({
    super.key,
    required this.visible,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: child,
        ),
      ),
      // From the top, not centered: the content below slides down
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, if (current != null) current],
      ),
      child: visible
          ? SizedBox(
              key: const ValueKey(true), width: double.infinity, child: child)
          : const SizedBox(key: ValueKey(false), width: double.infinity),
    );
  }
}
