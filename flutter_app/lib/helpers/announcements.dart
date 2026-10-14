import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/services/subscription_service.dart';
import 'package:vegan_app/widgets/shared/announcement_sheet.dart';

/// App news shown once each at launch (see [showNextAnnouncement]), oldest
/// first. Add new entries at the end with a fresh id; entries can be removed
/// once they're no longer relevant.
List<Announcement> appAnnouncements({VoidCallback? goToMapTab}) => [
      Announcement(
        id: 'map_open_to_all',
        badge: 'Nouveau',
        title: 'La carte est ouverte à toustes !',
        message:
            'Vous pouvez maintenant trouver tous les produits du vegandex autour de vous.',
        image: 'lib/assets/themes/cards/poule-summer.webp',
        mirrorImage: true,
        features: const [
          'Trouvez tous les produits en magasin',
          'Filtrez par produit recherché',
          'Ajoutez des magasins et donnez votre avis',
        ],
        note: 'Les produits de la carte sont ceux du Vegandex : '
            'scannez-les en magasin pour aider les autres utilisateur·ices '
            'à les trouver !',
        primaryLabel: 'Voir la carte',
        onPrimary: goToMapTab,
        // Unknown status (offline, slow backend) counts as no: better skip
        // it once than show it to a subscriber.
        shouldShow: () async =>
            SubscriptionService.isEntitlementDetermined &&
            !SubscriptionService.isSubscribed,
      ),
    ];

/// Announcements listed in the Dashboard notifications sheet, and their
/// unseen count for the bell badge (plugged into ProfileNotificationService).
class AnnouncementCenter {
  AnnouncementCenter._();

  static final ValueNotifier<int> unseenCount = ValueNotifier<int>(0);

  /// [appAnnouncements] meant for this user (their `shouldShow` passes),
  /// newest first.
  static Future<List<Announcement>> relevant({VoidCallback? goToMapTab}) async {
    final all = appAnnouncements(goToMapTab: goToMapTab);
    final checks = await Future.wait([
      for (final a in all) a.shouldShow?.call() ?? Future.value(true),
    ]);
    return [
      for (var i = all.length - 1; i >= 0; i--)
        if (checks[i]) all[i],
    ];
  }

  /// Ids among [announcements] the user hasn't seen yet.
  static Future<Set<String>> unseenIds(List<Announcement> announcements) async {
    return {
      for (final a in announcements)
        if (!await PreferencesHelper.hasSeenAnnouncement(a.id)) a.id,
    };
  }

  static Future<void> refreshUnseenCount() async {
    unseenCount.value = (await unseenIds(await relevant())).length;
  }

  /// Launch-time display: waits for the subscription status (audience
  /// checks depend on it), shows the next unseen announcement, then syncs
  /// the bell badge.
  static Future<void> showNext(
    BuildContext context, {
    VoidCallback? goToMapTab,
  }) async {
    await _waitForEntitlement();
    if (!context.mounted) return;
    await showNextAnnouncement(
      context,
      appAnnouncements(goToMapTab: goToMapTab),
    );
    await refreshUnseenCount();
  }
}

/// Waits (briefly) for the cold-start subscription check to settle.
Future<void> _waitForEntitlement() async {
  if (SubscriptionService.isEntitlementDetermined) return;
  final completer = Completer<void>();
  void listener() {
    if (SubscriptionService.isEntitlementDetermined && !completer.isCompleted) {
      completer.complete();
    }
  }

  SubscriptionService.revision.addListener(listener);
  try {
    await completer.future
        .timeout(const Duration(seconds: 5), onTimeout: () {});
  } finally {
    SubscriptionService.revision.removeListener(listener);
  }
}
