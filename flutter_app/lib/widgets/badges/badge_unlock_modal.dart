import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/badge.dart' as app_badge;
import '../../themes/app_colors.dart';
import '../shared/app_button.dart';
import '../shared/bottom_sheet_shell.dart';
import '../shared/page_dots_indicator.dart';

class BadgeUnlockModal extends StatefulWidget {
  final List<app_badge.Badge> badges;
  final VoidCallback? onClose;

  const BadgeUnlockModal({
    super.key,
    required this.badges,
    this.onClose,
  });

  @override
  State<BadgeUnlockModal> createState() => _BadgeUnlockModalState();
}

class _BadgeUnlockModalState extends State<BadgeUnlockModal> {
  final PageController _pageController =
      PageController(viewportFraction: 0.5);
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // "New Badge(s) Unlocked" text
          Text(
            widget.badges.length > 1
                ? 'Nouveaux badges débloqués !'
                : 'Nouveau badge débloqué !',
            style: TextStyle(
              fontFamily: 'Baloo2',
              fontSize: 64.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: -1,
              color: kTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 32.h),

          // Horizontal slider: one page per unlocked badge, with
          // neighbouring badges peeking in translucent at the sides
          SizedBox(
            height: 660.w,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.badges.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) {
                final badge = widget.badges[index];
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    final page = _pageController.hasClients &&
                            _pageController.page != null
                        ? _pageController.page!
                        : _page.toDouble();
                    final distance = (page - index).abs();
                    final scale = (1 - distance * 0.22).clamp(0.82, 1.0);
                    final opacity = (1 - distance * 0.55).clamp(0.45, 1.0);

                    return Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 400.w,
                        height: 400.w,
                        child: Image.asset(
                          badge.iconPath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.emoji_events,
                              size: 120.sp,
                              color: Theme.of(context).colorScheme.primary,
                            );
                          },
                        ),
                      ),

                      SizedBox(height: 32.h),

                      // Badge name
                      Text(
                        badge.name,
                        style: TextStyle(
                          fontFamily: 'Baloo2',
                          fontSize: 60.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1,
                          color: kTextPrimary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Badge description
                      Text(
                        badge.description,
                        style: TextStyle(
                          fontSize: 46.sp,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          if (widget.badges.length > 1) ...[
            SizedBox(height: 24.h),
            PageDotsIndicator(
              count: widget.badges.length,
              currentIndex: _page,
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ],

          SizedBox(height: 40.h),

          // Close button
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Super !',
              backgroundColor: Theme.of(context).colorScheme.primary,
              onPressed: () {
                widget.onClose?.call();
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}
