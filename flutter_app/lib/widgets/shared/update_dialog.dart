import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:upgrader/upgrader.dart';
import '../../helpers/theme_helper.dart';
import '../../models/seasonal_theme.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import 'app_button.dart';
import 'info_box.dart';

/// Seasonal "poule" illustration (same asset family as the dashboard's
/// "Animaux épargnés" stat card, see `stat_card.dart`), keyed by the actual
/// calendar season ([ThemeHelper.getCurrentSeason]) rather than the user's
/// selected/purchased theme — most users are on the default (non-seasonal)
/// theme, so reading `Theme.of(context).extension<SeasonalTheme>()` here
/// would show "basic" year-round regardless of the date.
String _seasonalPouleAsset(Season season) {
  final suffix = switch (season) {
    Season.autumn => 'autumn',
    Season.summer => 'summer',
    Season.spring => 'spring',
    Season.winter => 'winter',
    Season.defaultTheme => 'basic',
  };
  return 'lib/assets/themes/cards/poule-$suffix.webp';
}

class CustomUpgradeAlert extends UpgradeAlert {
  CustomUpgradeAlert({
    super.key,
    required super.upgrader,
    super.child,
    super.showIgnore = false,
    super.showLater = true,
  });

  @override
  UpgradeAlertState createState() => _CustomUpgradeAlertState();
}

class _CustomUpgradeAlertState extends UpgradeAlertState {
  @override
  void showTheDialog({
    Key? key,
    required BuildContext context,
    required String? title,
    required String message,
    required String? releaseNotes,
    required bool barrierDismissible,
    required UpgraderMessages messages,
  }) {
    if (!context.mounted) return;
    widget.upgrader.saveLastAlerted();

    final isBlocked = widget.upgrader.blocked();
    final canLater = !isBlocked && widget.showLater;

    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => PopScope(
        canPop: onCanPop(),
        child: _UpdateDialog(
          key: key,
          message: message,
          releaseNotes: releaseNotes,
          showLater: canLater,
          onUpdate: () => onUserUpdated(ctx, !isBlocked),
          onLater: () => onUserLater(ctx, true),
        ),
      ),
    );
  }
}

class _UpdateDialog extends StatelessWidget {
  final String message;
  final String? releaseNotes;
  final bool showLater;
  final VoidCallback onUpdate;
  final VoidCallback onLater;

  const _UpdateDialog({
    super.key,
    required this.message,
    required this.releaseNotes,
    required this.showLater,
    required this.onUpdate,
    required this.onLater,
  });

  String? _extractVersion() {
    final match = RegExp(r'La version (\d[\d.]+\d)').firstMatch(message);
    return match?.group(1);
  }

  @override
  Widget build(BuildContext context) {
    final version = _extractVersion();
    final hasNotes = releaseNotes != null && releaseNotes!.isNotEmpty;
    final primary = Theme.of(context).colorScheme.primary;
    final season = ThemeHelper.getCurrentSeason();

    return Dialog(
      backgroundColor: Colors.white,
      shape: squircleBorder(radius: 28.r),
      child: Container(
        padding: EdgeInsets.all(32.w),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: squircleBorder(radius: 28.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar
            SizedBox(
              width: 400.w,
              height: 400.w,
              child: Image.asset(
                _seasonalPouleAsset(season),
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 24.h),
            // Title
            Text(
              'Mise à jour disponible !',
              style: AppTextStyles.baloo22,
              textAlign: TextAlign.center,
            ),
            if (version != null) ...[
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                decoration: ShapeDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: squircleBorder(radius: 20.r),
                ),
                child: Text(
                  'v$version',
                  style: AppTextStyles.bodyBold13.copyWith(
                    color: primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
            SizedBox(height: 16.h),
            // Body text
            if (hasNotes) ...[
              Text(
                releaseNotes!,
                style: AppTextStyles.bodyRegular15.copyWith(
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
            ],
            const InfoBox(
              text:
                  'Mettre à jour l\'application permet d\'avoir des données à jour, les correctifs de bugs et les nouvelles fonctionnalités !',
            ),
            SizedBox(height: 32.h),
            // Buttons — a single full-width primary CTA plus a lighter text
            // link for the secondary action, rather than two pill buttons
            // squeezed side by side (AppButton's padding is sized for one
            // full-width button, and doesn't leave room for "Mettre à jour"
            // next to another pill in this dialog's narrower width).
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Mettre à jour',
                backgroundColor: primary,
                onPressed: onUpdate,
              ),
            ),
            if (showLater) ...[
              SizedBox(height: 8.h),
              TextButton(
                onPressed: onLater,
                child: Text(
                  'Plus tard',
                  style: AppTextStyles.bodyMedium15.copyWith(color: Colors.grey[600]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
