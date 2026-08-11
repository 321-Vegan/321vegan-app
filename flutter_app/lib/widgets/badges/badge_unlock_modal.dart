import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/badge.dart' as app_badge;
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';

class BadgeUnlockModal extends StatefulWidget {
  final app_badge.Badge badge;
  final VoidCallback? onClose;

  const BadgeUnlockModal({
    super.key,
    required this.badge,
    this.onClose,
  });

  @override
  State<BadgeUnlockModal> createState() => _BadgeUnlockModalState();
}

class _BadgeUnlockModalState extends State<BadgeUnlockModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    // Start animations
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dark overlay
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              color: Colors.black.withValues(alpha: 0.7),
            ),
          ),

          // Modal content
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 40.w),
                padding: EdgeInsets.all(32.w),
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: squircleBorder(
                    radius: 42.r,
                    side: const BorderSide(color: kBorderDefault),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // "New Badge Unlocked" text
                    Text(
                      'Nouveau badge débloqué !',
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

                    // Badge icon, plain — no ring/glow
                    SizedBox(
                      width: 400.w,
                      height: 400.w,
                      child: Image.asset(
                        widget.badge.iconPath,
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
                      widget.badge.name,
                      style: TextStyle(
                        fontFamily: 'Baloo2',
                        fontSize: 60.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1,
                        color: kTextPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // Badge description
                    Text(
                      widget.badge.description,
                      style: TextStyle(
                        fontSize: 46.sp,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 40.h),

                    // Close button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onClose?.call();
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 20.h),
                          shape: squircleBorder(radius: 42.r),
                          elevation: 0,
                        ),
                        child: Text(
                          'Super !',
                          style: TextStyle(
                            fontSize: 48.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
