import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:upgrader/upgrader.dart';
import '../../themes/app_shapes.dart';

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

    return Dialog(
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
            Container(
              width: 240.w,
              height: 240.w,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset('lib/assets/avatars/lapin.png', fit: BoxFit.contain),
            ),
            SizedBox(height: 24.h),
            // Title
            Text(
              'Mise à jour disponible !',
              style: TextStyle(
                fontSize: 56.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            if (version != null) ...[
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                decoration: ShapeDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: squircleBorder(radius: 20.r),
                ),
                child: Text(
                  'v$version',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 36.sp,
                    fontWeight: FontWeight.w600,
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
                style: TextStyle(
                  fontSize: 42.sp,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
            ],
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: ShapeDecoration(
                color: Colors.blue.shade50,
                shape: squircleBorder(
                  radius: 12.r,
                  side: BorderSide(color: Colors.blue.shade100),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.blue.shade400, size: 42.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Mettre à jour l\'application permet d\'avoir des données à jour, les correctifs de bugs et les nouvelles fonctionnalités !',
                      style: TextStyle(
                        fontSize: 36.sp,
                        color: Colors.blue.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32.h),
            // Buttons
            Row(
              children: [
                if (showLater) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onLater,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        side: BorderSide(color: Colors.grey[300]!, width: 2),
                        padding: EdgeInsets.symmetric(vertical: 20.h),
                        shape: squircleBorder(radius: 12.r),
                      ),
                      child: Text(
                        'Plus tard',
                        style: TextStyle(fontSize: 44.sp, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: onUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      shape: squircleBorder(radius: 12.r),
                    ),
                    child: Text(
                      'Mettre à jour',
                      style: TextStyle(fontSize: 44.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
