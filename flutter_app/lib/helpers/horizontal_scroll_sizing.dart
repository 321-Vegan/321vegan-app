/// Width an item should have so that [visibleCount] of them (including a
/// partial one, e.g. 2.5) fit in [maxWidth] with [gap] between each.
double itemWidthForVisibleCount(
  double maxWidth, {
  required double visibleCount,
  double gap = 16,
}) {
  final gapCount = visibleCount.floor();
  return (maxWidth - gap * gapCount) / visibleCount;
}
