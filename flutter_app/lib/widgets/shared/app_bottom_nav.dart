import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppBottomNavItem {
  final IconData? icon;

  /// Icon shown while selected; falls back to [icon].
  final IconData? activeIcon;

  /// Inactive-state icon image (e.g. Figma export), used instead of [icon]
  /// when set — plain black glyph, tinted like [icon] at render time.
  final String? iconAsset;

  /// Active-state counterpart to [iconAsset]; falls back to [iconAsset].
  final String? activeIconAsset;
  final String label;

  const AppBottomNavItem({
    this.icon,
    this.activeIcon,
    this.iconAsset,
    this.activeIconAsset,
    required this.label,
  }) : assert(icon != null || iconAsset != null,
            'AppBottomNavItem needs either icon or iconAsset');
}

/// Flat bottom navigation bar from the redesign (replaced the convex
/// plugin bar): white background, icon above label, numeric badges.
class AppBottomNav extends StatelessWidget {
  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Item index → unread count; zero or absent hides the badge.
  final Map<int, int> badges;

  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.badges = const {},
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = Colors.grey[600]!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(top: 24.h, bottom: 12.h),
          child: Row(
            children: [
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: _NavItem(
                    item: items[i],
                    isActive: i == currentIndex,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                    badgeCount: badges[i] ?? 0,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final AppBottomNavItem item;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.badgeCount,
    required this.onTap,
  });

  Widget _buildIcon(Color color) {
    final assetPath =
        isActive ? (item.activeIconAsset ?? item.iconAsset) : item.iconAsset;
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        width: 76.sp,
        height: 76.sp,
        color: color,
        colorBlendMode: BlendMode.srcIn,
      );
    }
    return Icon(
      isActive ? (item.activeIcon ?? item.icon) : item.icon,
      size: 76.sp,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildIcon(color),
              if (badgeCount > 0)
                Positioned(
                  right: -10,
                  top: -4,
                  child: Container(
                    padding: EdgeInsets.all(5.w),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        BoxConstraints(minWidth: 44.w, minHeight: 44.w),
                    child: Text(
                      '$badgeCount',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 34.sp,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
