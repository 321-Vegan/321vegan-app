import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/models/app_notification.dart';
import 'package:vegan_app/services/app_notification_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/shared/announcement_sheet.dart';
import 'package:vegan_app/widgets/shared/bottom_sheet_shell.dart';

/// Dashboard bell content, in two sections: "Pour vous" (the notifications
/// sent by the API, logged-in only, swipe to delete) and "Nouveautés de l'app" (the announcements hard-coded in the
/// app). Each item opens its own page/sheet.
class NotificationsSheet extends StatelessWidget {
  /// Newest first; see AnnouncementCenter.relevant.
  final List<Announcement> announcements;

  /// Ids among [announcements] the user hasn't opened yet (red dot).
  final Set<String> unseenAnnouncementIds;

  /// Shows the API notifications (AppNotificationService); false when
  /// logged out.
  final bool showInbox;

  final void Function(Announcement announcement) onOpenAnnouncement;
  final void Function(AppNotification notification) onOpenNotification;

  const NotificationsSheet({
    super.key,
    required this.announcements,
    required this.unseenAnnouncementIds,
    required this.showInbox,
    required this.onOpenAnnouncement,
    required this.onOpenNotification,
  });

  @override
  Widget build(BuildContext context) {
    // Rebuilds when a notification is deleted or marked read
    return ValueListenableBuilder<List<AppNotification>>(
      valueListenable: AppNotificationService.items,
      builder: (context, inboxItems, _) =>
          _buildSheet(context, showInbox ? inboxItems : const []),
    );
  }

  Widget _buildSheet(BuildContext context, List<AppNotification> inbox) {
    final hasPersonal = inbox.isNotEmpty;
    final isEmpty = !hasPersonal && announcements.isEmpty;

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
              if (hasPersonal) const _SectionTitle('Pour vous'),
              for (final notification in inbox)
                _DismissibleNotification(
                  key: ValueKey('app-notification-${notification.id}'),
                  onDismissed: () =>
                      AppNotificationService.delete(notification.id),
                  child: _NotificationTile(
                    leading: _IconBadge(
                      icon: _iconFor(notification.type),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: notification.title,
                    subtitle: notification.body,
                    unread: !notification.isRead,
                    // Sheet kept open: its page is pushed above it, so
                    // going back lands here again
                    onTap: () => onOpenNotification(notification),
                  ),
                ),
              if (announcements.isNotEmpty) ...[
                // Spaced from the section above, if any
                if (hasPersonal) SizedBox(height: 24.h),
                const _SectionTitle('Nouveautés de l\'app'),
              ],
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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Text(title, style: AppTextStyles.baloo17),
    );
  }
}

IconData _iconFor(String type) => switch (type) {
      AppNotification.errorReportHandled => Icons.chat,
      AppNotification.restaurantValidated => Icons.check_circle_outline,
      AppNotification.restaurantRejected => Icons.highlight_off,
      AppNotification.selectionReceived => Icons.collections_bookmark,
      AppNotification.restaurantSuggestionApproved ||
      AppNotification.restaurantSuggestionRejected =>
        Icons.edit_note,
      _ => Icons.notifications,
    };

/// Swipe left to delete, over a red background matching the tile's shape.
class _DismissibleNotification extends StatelessWidget {
  final VoidCallback onDismissed;
  final Widget child;

  const _DismissibleNotification({
    super.key,
    required this.onDismissed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Padding(
        // Same bottom gap as _NotificationTile
        padding: EdgeInsets.only(bottom: 24.h),
        child: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.symmetric(horizontal: 48.w),
          decoration: ShapeDecoration(
            color: Colors.red,
            shape: squircleBorder(radius: 36.r),
          ),
          child: Icon(Icons.delete_outline, color: Colors.white, size: 60.sp),
        ),
      ),
      child: child,
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
