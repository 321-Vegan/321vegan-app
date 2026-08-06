import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/api_service.dart';
import '../themes/app_colors.dart';

/// Community goal progress shown on the premium page (designed for its
/// green background): yellow bar with the bee marker at the current
/// progress, and a caption with the supporter count.
class SubscriptionGoalWidget extends StatefulWidget {
  final int goal;
  final VoidCallback? onTap;

  const SubscriptionGoalWidget({
    super.key,
    this.goal = 1000,
    this.onTap,
  });

  @override
  State<SubscriptionGoalWidget> createState() => _SubscriptionGoalWidgetState();
}

class _SubscriptionGoalWidgetState extends State<SubscriptionGoalWidget>
    with SingleTickerProviderStateMixin {
  int? _count;
  bool _loaded = false;
  late AnimationController _animController;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _fetchCount();
  }

  Future<void> _fetchCount() async {
    final count = await ApiService.getSubscriptionCount();
    if (count != null && mounted) {
      final progress = (count / widget.goal).clamp(0.0, 1.0);
      setState(() {
        _count = count;
        _loaded = true;
        _progressAnim = Tween<double>(begin: 0, end: progress).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
      });
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final count = _count!;
    final goal = widget.goal;
    final beeSize = 96.w;

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        children: [
          SizedBox(
            // Room for the bee overflowing above/below the slim bar.
            height: beeSize + 0.02.sh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth;
                return AnimatedBuilder(
                  animation: _progressAnim,
                  builder: (context, _) {
                    final progress = _progressAnim.value;
                    final beeLeft = (barWidth * progress - beeSize / 2)
                        .clamp(0.0, barWidth - beeSize);
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 24.h,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        Container(
                          height: 24.h,
                          width: barWidth * progress,
                          decoration: BoxDecoration(
                            color: kAccentYellow,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        Positioned(
                          left: beeLeft,
                          top: -0.0002.sh,
                          child: 
                          Transform.scale(
                            scaleX: -1,
                            child:
                              Image.asset(
                                'lib/assets/images/buy-premium/bee.webp',
                                width: beeSize,
                                height: beeSize,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.emoji_nature,
                                  size: beeSize,
                                  color: kAccentYellow,
                                ),
                              ),
                          )
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '$count/$goal soutiens pour être à temps plein sur l\'app',
            style: TextStyle(
              fontSize: 34.sp,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
