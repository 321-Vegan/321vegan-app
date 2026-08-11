import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../helpers/horizontal_scroll_sizing.dart';
import '../../models/badge.dart' as app_badge;
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../../models/user.dart';

/// Grid of every badge (unlocked first), with a tap-to-detail dialog.
/// Extracted from the former profile page so it can be reused as a
/// standalone Dashboard section.
class BadgesGrid extends StatelessWidget {
  final User? user;

  const BadgesGrid({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    final productsSent = user?.nbProductsSent ?? 0;
    final veganSince = user?.veganSince;
    final supporterLevel = user?.supporterLevel ?? 0;
    final errorReports = user?.nbErrorReports ?? 0;

    // Supporter badge always first, then unlocked before locked.
    final sortedBadges = List<app_badge.Badge>.from(app_badge.Badges.all);
    sortedBadges.sort((a, b) {
      if (a.type == app_badge.BadgeType.supporter) return -1;
      if (b.type == app_badge.BadgeType.supporter) return 1;

      final aUnlocked = a.isUnlocked(
        productsSent: productsSent,
        veganSince: veganSince,
        supporterLevel: supporterLevel,
        errorSolved: errorReports,
      );
      final bUnlocked = b.isUnlocked(
        productsSent: productsSent,
        veganSince: veganSince,
        supporterLevel: supporterLevel,
        errorSolved: errorReports,
      );
      if (aUnlocked && !bUnlocked) return -1;
      if (!aUnlocked && bUnlocked) return 1;
      return 0;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _showAllBadges(context, sortedBadges),
          child: Row(
            children: [
              Text(
                'Badges',
                style: AppTextStyles.baloo22,
              ),
              const Spacer(),
              Icon(Icons.arrow_forward, size: 54.sp, color: Colors.grey[600]),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.afterTitle),
        // Badge size follows the available width (~3.3 visible) instead
        // of a fixed guess, same approach as the partner-shop cards.
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 24.0;
            final size = itemWidthForVisibleCount(
              constraints.maxWidth,
              visibleCount: 3.0,
              gap: gap,
            );
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < sortedBadges.length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    _buildBadgeItem(
                      context,
                      badge: sortedBadges[i],
                      size: size,
                      productsSent: productsSent,
                      veganSince: veganSince,
                      supporterLevel: supporterLevel,
                      errorReports: errorReports,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// Bottom sheet listing every badge in a grid ("voir tout").
  void _showAllBadges(BuildContext context, List<app_badge.Badge> badges) {
    final productsSent = user?.nbProductsSent ?? 0;
    final veganSince = user?.veganSince;
    final supporterLevel = user?.supporterLevel ?? 0;
    final errorReports = user?.nbErrorReports ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: squircleBorderOnly(topLeft: 28.r, topRight: 28.r),
        ),
        padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 32.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Badges',
              style: TextStyle(
                fontSize: 52.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 24.h),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 24.0;
                  final size = (constraints.maxWidth - gap * 2) / 3 - 1;
                  return SingleChildScrollView(
                    child: Wrap(
                      spacing: gap,
                      runSpacing: 24.h,
                      children: [
                        for (final badge in badges)
                          _buildBadgeItem(
                            context,
                            badge: badge,
                            size: size,
                            productsSent: productsSent,
                            veganSince: veganSince,
                            supporterLevel: supporterLevel,
                            errorReports: errorReports,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeItem(
    BuildContext context, {
    required app_badge.Badge badge,
    required double size,
    required int productsSent,
    required DateTime? veganSince,
    required int supporterLevel,
    required int errorReports,
  }) {
    final isUnlocked = badge.isUnlocked(
      productsSent: productsSent,
      veganSince: veganSince,
      supporterLevel: supporterLevel,
      errorSolved: errorReports,
    );
    return _BadgeItem(
      badge: badge,
      isUnlocked: isUnlocked,
      size: size,
      onTap: () => _showBadgeDetails(context, badge, isUnlocked),
    );
  }

  void _showBadgeDetails(
      BuildContext context, app_badge.Badge badge, bool isUnlocked) {
    final progress = badge.getProgress(
      productsSent: user?.nbProductsSent ?? 0,
      veganSince: user?.veganSince,
      supporterLevel: user?.supporterLevel ?? 0,
      errorSolved: user?.nbErrorReports ?? 0,
    );
    final progressText = badge.getProgressText(
      productsSent: user?.nbProductsSent ?? 0,
      veganSince: user?.veganSince,
      supporterLevel: user?.supporterLevel ?? 0,
      errorSolved: user?.nbErrorReports ?? 0,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: squircleBorder(radius: 20.r),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BadgeIcon(badge: badge, isUnlocked: isUnlocked, size: 200.w),
            SizedBox(height: 24.h),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 56.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 44.sp, color: Colors.grey[600]),
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: ShapeDecoration(
                color: isUnlocked
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                shape: squircleBorder(
                  radius: 12.r,
                  side: BorderSide(
                    color: isUnlocked ? Colors.green : Colors.orange,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUnlocked ? Icons.check_circle : Icons.lock_outline,
                    size: 44.sp,
                    color: isUnlocked ? Colors.green : Colors.orange,
                  ),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: Text(
                      isUnlocked
                          ? 'Badge débloqué !'
                          : badge.getRequirementText(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 40.sp,
                        fontWeight: FontWeight.w600,
                        color:
                            isUnlocked ? Colors.green[700] : Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isUnlocked && progressText != null) ...[
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    progressText,
                    style: TextStyle(
                      fontSize: 40.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()} %',
                    style: TextStyle(
                      fontSize: 40.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: progress),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 20.h,
                    backgroundColor: Colors.grey[200],
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.orange[700]!),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final app_badge.Badge badge;
  final bool isUnlocked;
  final double size;
  final VoidCallback onTap;

  const _BadgeItem({
    required this.badge,
    required this.isUnlocked,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BadgeIcon(badge: badge, isUnlocked: isUnlocked, size: size),
          ],
        ),
      ),
    );
  }
}

/// Badge illustration: full-color when unlocked, greyscale otherwise.
class _BadgeIcon extends StatelessWidget {
  final app_badge.Badge badge;
  final bool isUnlocked;
  final double size;

  const _BadgeIcon({
    required this.badge,
    required this.isUnlocked,
    required this.size,
  });

  static const _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ColorFiltered(
        colorFilter: isUnlocked
            ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
            : _greyscale,
        child: Opacity(
          opacity: isUnlocked ? 1.0 : 0.6,
          child: Image.asset(
            badge.iconPath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.emoji_events,
              size: size * 0.6,
              color: isUnlocked ? Colors.amber[700] : Colors.grey[500],
            ),
          ),
        ),
      ),
    );
  }
}
