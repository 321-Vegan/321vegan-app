import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import '../../services/geocoding_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../map/map_search_bar.dart';
import '../map/map_search_page.dart';
import '../shared/app_button.dart';

/// Full-screen map with a fixed pin at its center: the user moves the map
/// under it (or searches a place/address to jump to it), then confirms.
/// Pops the chosen position, or null.
class PinPickerPage extends StatefulWidget {
  final LatLng initialPosition;

  const PinPickerPage({super.key, required this.initialPosition});

  @override
  State<PinPickerPage> createState() => _PinPickerPageState();
}

class _PinPickerPageState extends State<PinPickerPage> {
  final MapController _mapController = MapController();
  String _searchQuery = '';

  Future<void> _openSearch() async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => MapSearchPage(initialQuery: _searchQuery),
      ),
    );
    if (!mounted || result is! PlaceResult) return;
    setState(() => _searchQuery = result.displayName);
    _mapController.move(LatLng(result.latitude, result.longitude), 18);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Placer le lieu'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: kTextPrimary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialPosition,
              initialZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'fr.321vegan.app',
              ),
              // Above the button (drawn over the map), which would hide it
              // once opened: its offset, plus its height (AppButton's
              // padding and icon). It must stay in the map: it closes when
              // the map moves.
              Padding(
                padding: EdgeInsets.only(bottom: 48.h + 2 * 39.h + 20 + 12.h),
                child: const RichAttributionWidget(
                  showFlutterMapAttribution: false,
                  alignment: AttributionAlignment.bottomLeft,
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ),
            ],
          ),
          // Pin whose tip points at the exact map center
          IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: Icon(Icons.location_on, size: 48, color: primary),
              ),
            ),
          ),
          Positioned(
            top: 24.h,
            left: AppSpacing.pageHorizontal,
            right: AppSpacing.pageHorizontal,
            child: Column(
              children: [
                MapSearchBar(
                  query: _searchQuery,
                  hintText: 'Rechercher un lieu, une adresse...',
                  onTap: _openSearch,
                  onClear: () => setState(() => _searchQuery = ''),
                ),
                SizedBox(height: 24.h),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 30.w, vertical: 15.h),
                  decoration: ShapeDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: squircleBorder(radius: 20.r),
                  ),
                  child: Text(
                    'Déplacez la carte pour placer le pin au milieu du bâtiment',
                    style: TextStyle(fontSize: 36.sp, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 48.h + MediaQuery.of(context).padding.bottom,
            left: 48.w,
            right: 48.w,
            child: AppButton(
              label: 'Valider la position',
              icon: Icons.check,
              backgroundColor: primary,
              onPressed: () =>
                  Navigator.of(context).pop(_mapController.camera.center),
            ),
          ),
        ],
      ),
    );
  }
}
