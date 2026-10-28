import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import '../../models/restaurants/restaurant.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../restaurants/restaurant_detail_page.dart';
import '../restaurants/restaurant_labels.dart';
import '../restaurants/restaurant_list_card.dart';
import '../shared/app_background.dart';
import '../shared/empty_state_view.dart';
import '../shared/tag_chip.dart';

/// The restaurants shown on the map (its area, with its filters) as a list,
/// closest first: to the user when [userLocation] is known (with the
/// distance), else to the map [center]. A place opens its page over the
/// list, so going back returns to it.
class MapRestaurantListPage extends StatelessWidget {
  final List<Restaurant> restaurants;
  final LatLng center;
  final LatLng? userLocation;

  const MapRestaurantListPage({
    super.key,
    required this.restaurants,
    required this.center,
    this.userLocation,
  });

  static Future<void> open(
    BuildContext context, {
    required List<Restaurant> restaurants,
    required LatLng center,
    LatLng? userLocation,
  }) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MapRestaurantListPage(
        restaurants: restaurants,
        center: center,
        userLocation: userLocation,
      ),
    ));
  }

  static const _distance = Distance();

  /// "250 m", "1,2 km", "12 km"
  static String _formatDistance(double meters) {
    if (meters < 1000) return '${(meters / 10).round() * 10} m';
    final km = meters / 1000;
    return km < 10
        ? '${km.toStringAsFixed(1).replaceAll('.', ',')} km'
        : '${km.round()} km';
  }

  @override
  Widget build(BuildContext context) {
    final from = userLocation ?? center;
    double distanceTo(Restaurant r) => _distance.as(
        LengthUnit.Meter, from, LatLng(r.latitude, r.longitude));
    final sorted = [...restaurants]
      ..sort((a, b) => distanceTo(a).compareTo(distanceTo(b)));
    final count = sorted.length;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            switch (count) {
              0 => 'Aucun lieu ici',
              1 => '1 lieu ici',
              _ => '$count lieux ici',
            },
            style: AppTextStyles.baloo22,
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kTextPrimary,
        ),
        body: SafeArea(
          top: false,
          child: count == 0
              ? const EmptyStateView(
                  title: 'Aucun lieu dans cette zone',
                  subtitle: 'Déplacez ou dézoomez la carte, ou changez les '
                      'filtres, pour en voir plus.',
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(AppSpacing.pageHorizontal,
                      24.h, AppSpacing.pageHorizontal, 32.h),
                  itemCount: count,
                  separatorBuilder: (_, __) =>
                      SizedBox(height: AppSpacing.item),
                  itemBuilder: (context, index) {
                    final r = sorted[index];
                    return RestaurantListCard(
                      restaurant: r,
                      onTap: () => RestaurantDetailPage.open(context, r),
                      badges: [
                        if (userLocation != null)
                          TagChip(
                            label: _formatDistance(distanceTo(r)),
                            color: kTextPrimary,
                            icon: Icons.near_me_outlined,
                          ),
                        if (r.isPermanentlyClosed)
                          const TagChip(
                            label: 'Fermé définitivement',
                            color: kSemanticError,
                          )
                        else if (r.isClosedNow)
                          const TagChip(
                            label: 'Fermé temporairement',
                            color: kVeganOptionsOrange,
                          ),
                        VeganStatusChip(isFullyVegan: r.isFullyVegan),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}
