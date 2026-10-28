import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/pages/app_pages/home.dart';
import 'package:vegan_app/services/subscription_service.dart';
import 'package:vegan_app/widgets/shared/announcement_sheet.dart';

/// App news shown once each at launch (see [showNextAnnouncement]), oldest
/// first. Add new entries at the end with a fresh id; entries can be removed
/// once they're no longer relevant. [home] drives the buttons that switch
/// tab; null where they're never pressed (e.g. marking all seen).
List<Announcement> appAnnouncements({MyHomePageState? home}) => [
      Announcement(
        id: 'product_ratings',
        badge: 'Nouveau',
        title: 'Notez les produits !',
        message: 'Donnez votre avis sur les produits que vous scannez et '
            'découvrez celui de la communauté.',
        image: 'lib/assets/images/characters/cow-ok.webp',
        features: const [
          'Notez de 1 à 5 étoiles',
          'Ajoutez un commentaire si vous le souhaitez',
          'Consultez les avis des autres utilisateur·ices',
        ],
        note:
            'Scannez un produit ou ouvrez-le depuis le Vegandex ou l\'historique pour le '
            'noter. Retrouvez toutes vos notes dans Paramètres > Notes.',
        primaryLabel: 'Scanner',
        onPrimary: home?.goToScanTab,
      ),
      Announcement(
        id: 'map_places',
        badge: 'Nouveau',
        title: 'Les lieux véganes sont sur la carte !',
        message: 'Restaurants, cafés, boulangeries, glaciers… trouvez où '
            'manger végane près de chez vous ou en voyage.',
        image: 'lib/assets/images/characters/avocado.webp',
        features: const [
          'Lieux 100 % véganes et lieux avec options véganes bien identifiés',
          'Notes, avis et photos de la communauté',
          'Sauvegardez vos lieux préférés et partagez-les',
        ],
        note: 'Sur la carte, passez sur « Lieux » en bas de l\'écran. Un lieu '
            'manque ? Ajoutez-le avec le bouton +.',
        primaryLabel: 'Voir les lieux',
        onPrimary: home == null
            ? null
            : () async {
                await PreferencesHelper.setLastMapLayerPref('restaurants');
                home.goToMapTab();
              },
      ),
    ];

/// Announcements listed in the Dashboard notifications sheet, and their
/// unseen count for the bell badge (plugged into ProfileNotificationService).
class AnnouncementCenter {
  AnnouncementCenter._();

  static final ValueNotifier<int> unseenCount = ValueNotifier<int>(0);

  /// [appAnnouncements] meant for this user (their `shouldShow` passes),
  /// newest first.
  static Future<List<Announcement>> relevant({MyHomePageState? home}) async {
    final all = appAnnouncements(home: home);
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
    required MyHomePageState home,
  }) async {
    await _waitForEntitlement();
    if (!context.mounted) return;
    await showNextAnnouncement(context, appAnnouncements(home: home));
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
