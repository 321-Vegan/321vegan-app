import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import 'package:vegan_app/helpers/preference_helper.dart';

class MembershipPromptDialog extends StatefulWidget {
  final VideoPlayerController videoController;
  final VoidCallback onSupport;
  final VoidCallback onLater;

  const MembershipPromptDialog({
    super.key,
    required this.videoController,
    required this.onSupport,
    required this.onLater,
  });

  @override
  State<MembershipPromptDialog> createState() => _MembershipPromptDialogState();
}

class _MembershipPromptDialogState extends State<MembershipPromptDialog> {
  @override
  void dispose() {
    widget.videoController.dispose();
    super.dispose();
  }

  Widget _buildVideo() {
    final size = widget.videoController.value.size;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(widget.videoController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 32.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.r),
        child: SizedBox(
          height: 1200.h,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Video left — fixed width, covers height
              SizedBox(
                width: 600.w,
                child: _buildVideo(),
              ),
              // Content right
              Expanded(
                child: Container(
                  color: Colors.white,
                  padding:
                      EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'lib/assets/avatars/cochon.png',
                        height: 160.h,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'Vous scannez souvent !',
                        style: TextStyle(
                          fontSize: 48.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'Débloquez les Nutri & Eco-scores en illimité, les thèmes et la carte des produits vegan près de vous, tout en soutenant le projet !',
                        style: TextStyle(
                          fontSize: 36.sp,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 20.h),
                      ElevatedButton(
                        onPressed: () async {
                          await PreferencesHelper.snoozeMembershipPrompt();
                          widget.onSupport();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Débloquer ❤️',
                          style: TextStyle(
                            fontSize: 40.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      OutlinedButton(
                        onPressed: () async {
                          await PreferencesHelper.snoozeMembershipPrompt();
                          widget.onLater();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          side: BorderSide(color: Colors.grey[300]!, width: 2),
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Plus tard',
                          style: TextStyle(
                            fontSize: 40.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(height: 14.h),
                      GestureDetector(
                        onTap: () async {
                          await PreferencesHelper
                              .markMembershipPromptDismissed();
                          widget.onLater();
                        },
                        child: Text(
                          'Ne plus afficher',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 34.sp,
                            color: Colors.grey[400],
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
