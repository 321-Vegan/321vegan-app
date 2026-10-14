import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';
import 'package:vegan_app/widgets/shared/bottom_sheet_shell.dart';
import 'package:vegan_app/widgets/shared/info_box.dart';

class Announcement {
  /// Stable key used to remember it was shown; never reuse one.
  final String id;
  final String title;
  final String message;
  final String image;

  /// Flips [image] horizontally if true.
  final bool mirrorImage;

  /// SYellow chip next to the image.
  final String? badge;

  /// Bullet points (check marks, as on the subscription page).
  final List<String> features;

  /// Highlighted tip shown below [features] in an [InfoBox].
  final String? note;

  final String primaryLabel;

  final VoidCallback? onPrimary;
  final String secondaryLabel;

  final Future<bool> Function()? shouldShow;

  const Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.image,
    this.mirrorImage = false,
    this.badge,
    this.features = const [],
    this.note,
    this.primaryLabel = 'Compris !',
    this.onPrimary,
    this.secondaryLabel = 'Plus tard',
    this.shouldShow,
  });
}

/// Shows the first [announcements] entry with [Announcement.shouldShow]
/// passes. At most one per call so launches never stack sheets. Returns
/// whether one was shown.
Future<bool> showNextAnnouncement(
  BuildContext context,
  List<Announcement> announcements,
) async {
  for (final announcement in announcements) {
    if (await PreferencesHelper.hasSeenAnnouncement(announcement.id)) {
      continue;
    }
    if (announcement.shouldShow != null && !await announcement.shouldShow!()) {
      continue;
    }
    // Checked last, after the async lookups: never pop up over a page the
    // user opened in the meantime.
    if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) {
      return false;
    }

    await showAnnouncementSheet(context, announcement);
    return true;
  }
  return false;
}

/// Marks every entry of [announcements] as seen, e.g. for a fresh install
/// where "what's new" news makes no sense.
Future<void> markAnnouncementsSeen(List<Announcement> announcements) async {
  for (final announcement in announcements) {
    await PreferencesHelper.markAnnouncementSeen(announcement.id);
  }
}

/// Shows [announcement] and marks it seen once the user answers it with one
/// of the buttons; swiping the sheet away or tapping outside leaves it
/// unseen, so it comes back on the next launch.
Future<void> showAnnouncementSheet(
  BuildContext context,
  Announcement announcement,
) async {
  final openedPrimary = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AnnouncementSheet(announcement: announcement),
  );
  if (openedPrimary == null) return;
  await PreferencesHelper.markAnnouncementSeen(announcement.id);
  // Run after the sheet is gone so the action (tab switch, push...) happens
  // on the underlying page.
  if (openedPrimary) announcement.onPrimary?.call();
}

class AnnouncementSheet extends StatelessWidget {
  final Announcement announcement;

  const AnnouncementSheet({super.key, required this.announcement});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hasAction = announcement.onPrimary != null;

    return BottomSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.flip(
                flipX: announcement.mirrorImage,
                child: Image.asset(announcement.image, height: 260.h),
              ),
              if (announcement.badge != null)
                Positioned(
                  top: 0,
                  right: -40.w,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
                    decoration: ShapeDecoration(
                      color: kAccentYellow,
                      shape: squircleBorder(radius: 20.r),
                    ),
                    child: Text(
                      announcement.badge!,
                      style: AppTextStyles.bodyBold11
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 24.h),
          Text(
            announcement.title,
            style: AppTextStyles.baloo26,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          Text(
            announcement.message,
            style: AppTextStyles.bodyRegular15.copyWith(
              color: Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          if (announcement.features.isNotEmpty) ...[
            SizedBox(height: 32.h),
            Center(
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final feature in announcement.features)
                      _FeatureRow(label: feature, color: primary),
                  ],
                ),
              ),
            ),
          ],
          if (announcement.note != null) ...[
            SizedBox(height: 24.h),
            InfoBox(text: announcement.note!),
          ],
          SizedBox(height: 32.h),
          Row(
            children: [
              if (hasAction) ...[
                Expanded(
                  child: AppButton(
                    label: announcement.secondaryLabel,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.grey[700]!,
                    borderColor: kBorderDefault,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                SizedBox(width: 16.w),
              ],
              Expanded(
                child: AppButton(
                  label: announcement.primaryLabel,
                  backgroundColor: primary,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String label;
  final Color color;

  const _FeatureRow({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        children: [
          Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(Icons.check, size: 44.sp, color: Colors.white),
          ),
          SizedBox(width: 24.w),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.bodyRegular15.copyWith(
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
