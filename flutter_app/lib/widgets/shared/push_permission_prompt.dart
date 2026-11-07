import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/push_notification_service.dart';
import 'app_dialog.dart';
import 'icon_snack_bar.dart';

/// After a signalement: offers the pushes in our own dialog before the OS
/// one, which iOS only shows once — a reflex refusal there is final.
/// "Plus tard" (or an OS refusal) snoozes the offer for a while, since the
/// settings switch can't silence it then (shown off already). Already
/// allowed: just registers the device.
Future<void> offerPushNotifications(BuildContext context) async {
  if (!await PushNotificationService.needsPermission()) {
    await PushNotificationService.registerDevice();
    return;
  }
  if (await PushNotificationService.isOfferSnoozed() || !context.mounted) {
    return;
  }
  final accepted = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialog(
      image: 'lib/assets/images/characters/cow-ok.webp',
      title: 'Être notifié quand l\'équipe répond ?',
      message:
          'Vous recevrez une notification dès que votre signalement est traité.',
      primaryLabel: 'Oui',
      onPrimary: () => Navigator.of(ctx).pop(true),
      secondaryLabel: 'Plus tard',
      onSecondary: () => Navigator.of(ctx).pop(false),
    ),
  );
  if (accepted != true) {
    await PushNotificationService.snoozeOffer();
    return;
  }
  if (await PushNotificationService.registerDevice(prompt: true)) return;
  await PushNotificationService.snoozeOffer();
  if (context.mounted) showPushBlockedSnackBar(context);
}

/// The OS permission is refused: only the phone settings can give it back
/// (the OS no longer shows its prompt).
void showPushBlockedSnackBar(BuildContext context) {
  // Not looked up on tap: [context] may be gone by then (closed sheet)
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(iconSnackBar(
      icon: Icons.notifications_off_outlined,
      message: 'Notifications bloquées dans les réglages du téléphone',
      color: Colors.grey.shade800,
      actionLabel: 'Réglages',
      onAction: () {
        messenger.hideCurrentSnackBar();
        openAppSettings();
      },
    ));
}
