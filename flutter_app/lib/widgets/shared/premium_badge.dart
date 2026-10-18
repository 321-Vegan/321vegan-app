import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';

/// Yellow crown marking premium: premium-only features (theme selector)
/// and premium members (next to their nickname on reviews).
class PremiumBadge extends StatelessWidget {
  /// Side in ScreenUtil units; defaults to the settings rows' 54.
  final double? size;

  const PremiumBadge({super.key, this.size});

  @override
  Widget build(BuildContext context) {
    final s = size ?? 54.sp;
    return Semantics(
      label: 'Premium',
      child: Image.asset(
        'lib/assets/images/icons/crown-line.webp',
        width: s,
        height: s,
        color: kAccentYellow,
        colorBlendMode: BlendMode.srcIn,
      ),
    );
  }
}
