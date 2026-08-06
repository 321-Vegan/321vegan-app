/// Width an item should have so that [visibleCount] of them (including a
/// partial one, e.g. 2.5) fit in [maxWidth] with [gap] between each —
/// used by the Dashboard's horizontal-scroll sections (partner shops,
/// badges) so item size follows the actual screen width instead of a
/// guessed fixed value.
double itemWidthForVisibleCount(
  double maxWidth, {
  required double visibleCount,
  double gap = 16,
}) {
  final gapCount = visibleCount.floor();
  return (maxWidth - gap * gapCount) / visibleCount;
}
