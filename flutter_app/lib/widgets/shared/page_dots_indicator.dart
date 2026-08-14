import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Carousel page-dots: the active dot stretches into a pill, inactive dots
/// stay small squares. Used below any `PageView` (Dashboard's PromoCarousel,
/// the theme selector) so every swipeable carousel in the app indicates its
/// position the same way.
class PageDotsIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final Color activeColor;
  final Color inactiveColor;

  const PageDotsIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.activeColor,
    this.inactiveColor = const Color(0xFFBDBDBD), // Colors.grey[400]
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(horizontal: 8.w),
          width: isActive ? 66.w : 24.w,
          height: 24.w,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(12.r),
          ),
        );
      }),
    );
  }
}
