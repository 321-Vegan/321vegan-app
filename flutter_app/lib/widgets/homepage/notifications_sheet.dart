import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/shared/announcement_sheet.dart';
import 'package:vegan_app/widgets/shared/bottom_sheet_shell.dart';

/// Dashboard bell content: responses to the user's error reports (logged-in
/// only) and the app announcements, each opening its own page/sheet.
class NotificationsSheet extends StatelessWidget {
  /// Newest first; see AnnouncementCenter.relevant.
  final List<Announcement> announcements;

  /// Ids among [announcements] the user hasn't opened yet (red dot).
  final Set<String> unseenAnnouncementIds;

  /// Null hides the error reports row (logged out).
  final int? unreadErrorResponses;

  /// Restaurant selections sent to the user, not seen yet; the row only
  /// shows when there are some.
  final int unreadSelections;

  final void Function(Announcement announcement) onOpenAnnouncement;
  final VoidCallback onOpenErrorReports;
  final VoidCallback onOpenSelections;

  const NotificationsSheet({
    super.key,
    required this.announcements,
    required this.unseenAnnouncementIds,
    required this.unreadErrorResponses,
    this.unreadSelections = 0,
    required this.onOpenAnnouncement,
    required this.onOpenErrorReports,
    required this.onOpenSelections,
  });

  @override
  Widget build(BuildContext context) {
    final unreadErrors = unreadErrorResponses;
    final isEmpty = announcements.isEmpty &&
        unreadErrors == null &&
        unreadSelections == 0;

    return BottomSheetShell(
      // The shell gives its child unbounded height: cap it below the screen
      // (minus the shell's handle and paddings) so long content scrolls
      // instead of overflowing on small phones.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notifications', style: AppTextStyles.baloo22),
              SizedBox(height: 24.h),
              if (isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 48.h),
                  child: Center(
                    child: Text(
                      'Aucune notification pour le moment',
                      style: AppTextStyles.bodyRegular15
                          .copyWith(color: Colors.grey[600]),
                    ),
                  ),
                ),
              if (unreadSelections > 0)
                _NotificationTile(
                  leading: _IconBadge(
                    icon: Icons.collections_bookmark,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: 'Sélections de lieux reçues',
                  subtitle: unreadSelections == 1
                      ? 'On vous a envoyé 1 sélection'
                      : 'On vous a envoyé $unreadSelections sélections',
                  unread: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    onOpenSelections();
                  },
                ),
              if (unreadErrors != null)
                _NotificationTile(
                  leading: _IconBadge(
                    icon: Icons.chat,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: 'Réponses à vos signalements',
                  subtitle: switch (unreadErrors) {
                    0 => 'Aucune nouvelle réponse',
                    1 => '1 nouvelle réponse',
                    _ => '$unreadErrors nouvelles réponses',
                  },
                  unread: unreadErrors > 0,
                  onTap: () {
                    Navigator.of(context).pop();
                    onOpenErrorReports();
                  },
                ),
              for (final announcement in announcements)
                _NotificationTile(
                  leading: Transform.flip(
                    flipX: announcement.mirrorImage,
                    child: Image.asset(
                      announcement.image,
                      width: 110.w,
                      height: 110.w,
                      fit: BoxFit.contain,
                    ),
                  ),
                  title: announcement.title,
                  subtitle: announcement.message,
                  unread: unseenAnnouncementIds.contains(announcement.id),
                  onTap: () {
                    Navigator.of(context).pop();
                    onOpenAnnouncement(announcement);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bordered white row (same look as SettingsRowTile) with a leading visual,
/// title/subtitle, and a red dot when unread.
class _NotificationTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final bool unread;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Material(
        color: Colors.white,
        shape: squircleBorder(radius: 36.r),
        child: InkWell(
          onTap: onTap,
          customBorder: squircleBorder(radius: 36.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 39.w, vertical: 36.h),
            decoration: ShapeDecoration(
              shape: squircleBorder(
                radius: 36.r,
                side: const BorderSide(color: kBorderDefault),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 110.w,
                  height: 110.w,
                  child: Center(child: leading),
                ),
                SizedBox(width: 30.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.bodyBold15),
                      SizedBox(height: 4.h),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyRegular13
                            .copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 24.w),
                if (unread)
                  Container(
                    width: 30.w,
                    height: 30.w,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96.w,
      height: 96.w,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 52.sp),
    );
  }
}
