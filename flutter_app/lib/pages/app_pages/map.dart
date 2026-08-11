import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/models/shops/shop.dart';
import 'package:vegan_app/pages/app_pages/Profile/subscription_page.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/services/auth_service.dart';
import 'package:vegan_app/services/subscription_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/widgets/map/create_shop_sheet.dart';
import 'package:vegan_app/widgets/map/map_access_overlay.dart';
import 'package:vegan_app/widgets/map/map_filter_page.dart';
import 'package:vegan_app/widgets/map/map_search_bar.dart';
import 'package:vegan_app/widgets/map/shop_detail_sheet.dart';
import 'package:vegan_app/services/geocoding_service.dart';

class MapPage extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const MapPage({super.key, this.onLoginSuccess});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final GlobalKey<MapSearchBarState> _searchBarKey =
      GlobalKey<MapSearchBarState>();
  List<Shop> _shops = [];
  bool _isLoading = true;
  bool _isPicking = false;
  bool _isCentered = false;
  // One-time 6-hour free trial of the map
  DateTime? _trialEndsAt;
  Timer? _trialTimer;
  Set<String> _selectedEans = {};
  LatLng? _initialCenter;
  LatLng? _userLocation;
  StreamSubscription<Position>? _positionStreamSub;
  CachedTileProvider? _tileProvider;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 8, end: 20).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _initTileCache();
    _initLocation();
    _loadFreeTrial();
  }

  Future<void> _loadFreeTrial() async {
    final endsAt = await PreferencesHelper.getMapFreeTrialEnd();
    if (mounted && endsAt != null && DateTime.now().isBefore(endsAt)) {
      setState(() => _trialEndsAt = endsAt);
      _startTrialTicker();
    }
  }

  // Refresh the countdown chip and re-lock the map once the trial expires
  void _startTrialTicker() {
    _trialTimer?.cancel();
    if (_trialEndsAt == null) return;
    _trialTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {
        if (!_freeTrialActive) {
          _trialEndsAt = null;
          _trialTimer?.cancel();
        }
      });
    });
  }

  bool get _freeTrialActive =>
      _trialEndsAt != null && DateTime.now().isBefore(_trialEndsAt!);

  // Map is interactive when the access overlay is not showing
  bool get _hasMapAccess =>
      (AuthService.isLoggedIn && SubscriptionService.isSubscribed) ||
      _freeTrialActive;

  String _formatTrialRemaining() {
    final remaining = _trialEndsAt!.difference(DateTime.now());
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h${minutes.toString().padLeft(2, '0')}';
    return '$minutes min';
  }

  Future<void> _initTileCache() async {
    final dir = await getTemporaryDirectory();
    final store = FileCacheStore(
      '${dir.path}${Platform.pathSeparator}MapTiles',
    );
    if (mounted) {
      setState(() {
        _tileProvider = CachedTileProvider(
          maxStale: const Duration(days: 30),
          store: store,
        );
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _trialTimer?.cancel();
    _positionStreamSub?.cancel();
    super.dispose();
  }

  /// Continuously track the user's position so the blue dot follows them as
  /// they move. When the map is currently centered on the user, keep it
  /// centered ("follow me"); otherwise just update the dot in place.
  void _startPositionStream() {
    _positionStreamSub?.cancel();
    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (position) {
        if (!mounted) return;
        final pos = LatLng(position.latitude, position.longitude);
        setState(() => _userLocation = pos);
        if (_isCentered) {
          // Guard against the map not being ready yet (move() throws before
          // onMapReady fires).
          try {
            _mapController.move(pos, _mapController.camera.zoom);
          } catch (_) {}
        }
      },
      onError: (_) {},
    );
  }

  Future<void> _initLocation() async {
    const LatLng franceFallback = LatLng(46.231604072873, 2.495977205153891);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        // Track the position continuously so the blue dot follows the user.
        _startPositionStream();

        // Fast path: last known position renders the map immediately
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          final pos = LatLng(lastKnown.latitude, lastKnown.longitude);
          final wasAlreadyRendered = _initialCenter != null;
          setState(() {
            _userLocation = pos;
            _isCentered = true;
            _initialCenter ??= pos;
          });
          if (wasAlreadyRendered) {
            _mapController.move(pos, 16);
          }
          // Refine with accurate GPS in background without blocking the map
          _fetchAccuratePosition();
          return;
        }

        // No last known — wait for GPS (first launch or cleared cache)
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
        if (mounted) {
          final pos = LatLng(position.latitude, position.longitude);
          final wasAlreadyRendered = _initialCenter != null;
          setState(() {
            _userLocation = pos;
            _isCentered = true;
            _initialCenter ??= pos;
          });
          if (wasAlreadyRendered) {
            _mapController.move(pos, 16);
            _loadShops();
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted && _initialCenter == null) {
      setState(() => _initialCenter = franceFallback);
    }
  }

  Future<void> _fetchAccuratePosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      final pos = LatLng(position.latitude, position.longitude);
      setState(() => _userLocation = pos);
      if (_isCentered) {
        _mapController.move(pos, _mapController.camera.zoom);
      }
    } catch (_) {}
  }

  Future<void> _loadShops() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final bounds = _mapController.camera.visibleBounds;
    final List<Shop> shops;

    if (_selectedEans.isNotEmpty) {
      shops = await ApiService.getShopsFilteredByProducts(
        eans: _selectedEans.toList(),
        minLat: bounds.south,
        maxLat: bounds.north,
        minLng: bounds.west,
        maxLng: bounds.east,
      );
    } else {
      shops = await ApiService.getShopsInArea(
        minLat: bounds.south,
        maxLat: bounds.north,
        minLng: bounds.west,
        maxLng: bounds.east,
      );
    }

    if (mounted) {
      setState(() {
        _shops = shops;
        _isLoading = false;
      });
    }
  }

  void _openFilterPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapFilterPage(
          selectedEans: _selectedEans,
          onApply: (newSelection) {
            setState(() => _selectedEans = newSelection);
            _loadShops();
          },
        ),
      ),
    );
  }

  void _onMapEvent(MapEvent event) {
    // Dismiss the place-search dropdown as soon as the user moves the map.
    if (event is MapEventMoveStart) {
      _searchBarKey.currentState?.closeResults();
    }
    if (event is MapEventMoveEnd) {
      // Only mark as not centered when the user manually moves the map
      if (event.source != MapEventSource.mapController && _isCentered) {
        setState(() => _isCentered = false);
      }
      _loadShops();
    }
  }

  void _onMapReady() {
    _loadShops();
  }

  Widget _buildMarkerIcon(Shop shop) {
    final isVegan = shop.shopType == 'vegan';
    return Container(
      decoration: BoxDecoration(
        color: isVegan ? Colors.green : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isVegan
              ? Colors.green.shade700
              : Theme.of(context).colorScheme.primary,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          isVegan ? Icons.eco : Icons.storefront,
          color: isVegan ? Colors.white : Theme.of(context).colorScheme.primary,
          size: 22,
        ),
      ),
    );
  }

  void _onShopTap(Shop shop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Transparent so the sheet's own rounded surface shows the map behind
      // its top corners.
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => ShopDetailSheet(shop: shop),
    );
  }

  void _enterPickMode() {
    setState(() => _isPicking = true);
  }

  void _onCreateHere() {
    final coords = _mapController.camera.center;
    setState(() => _isPicking = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: squircleBorderOnly(topLeft: 20, topRight: 20),
      builder: (_) => CreateShopSheet(coordinates: coords),
    ).then((created) {
      if (created == true) _loadShops();
    });
  }

  void _onPlaceSelected(PlaceResult place) {
    setState(() => _isCentered = false);
    _mapController.move(LatLng(place.latitude, place.longitude), 14);
    _loadShops();
  }

  void _recenterMap() {
    if (_userLocation != null) {
      setState(() => _isCentered = true);
      _mapController.move(_userLocation!, 16);
      _loadShops();
    } else {
      _initLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialCenter == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter!,
              initialZoom: 16,
              onMapEvent: _onMapEvent,
              onMapReady: _onMapReady,
              onTap: (_, __) => _searchBarKey.currentState?.closeResults(),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'fr.321vegan.app',
                tileProvider: _tileProvider,
              ),
              const RichAttributionWidget(
                showFlutterMapAttribution: false,
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
              if (_userLocation != null)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, _) => CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _userLocation!,
                        radius: _pulseAnimation.value,
                        color: Theme.of(context).colorScheme.primary.withValues(
                              alpha:
                                  0.3 * (1 - (_pulseAnimation.value - 8) / 12),
                            ),
                        borderStrokeWidth: 0,
                      ),
                      CircleMarker(
                        point: _userLocation!,
                        radius: 7,
                        color: Theme.of(context).colorScheme.primary,
                        borderColor: Colors.white,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 80,
                  size: const Size(40, 40),
                  showPolygon: false,
                  markers: _shops.map((shop) {
                    return Marker(
                      point: LatLng(shop.latitude, shop.longitude),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _onShopTap(shop),
                        child: _buildMarkerIcon(shop),
                      ),
                    );
                  }).toList(),
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (_isPicking) ...[
            // Fixed pin at map center — tip points at the exact center
            Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: ShapeDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: squircleBorder(radius: 8.r),
                        shadows: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        'Sélectionnez le milieu du bâtiment',
                        style:
                            TextStyle(fontSize: 32.sp, color: Colors.black87),
                      ),
                    ),
                    Icon(
                      Icons.location_pin,
                      color: Theme.of(context).colorScheme.primary,
                      size: 48,
                    ),
                  ],
                ),
              ),
            ),
            // Instruction label
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                  decoration: ShapeDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: squircleBorder(radius: 20.r),
                  ),
                  child: Text(
                    'Déplacez la carte pour positionner le magasin',
                    style: TextStyle(fontSize: 34.sp, color: Colors.white),
                  ),
                ),
              ),
            ),
            // "Créer ici" + "Annuler" buttons
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() => _isPicking = false),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: EdgeInsets.symmetric(
                          horizontal: 20.w, vertical: 12.h),
                      shape: squircleBorder(radius: 24.r),
                    ),
                    child: Text('Annuler',
                        style: TextStyle(
                            fontSize: 36.sp, color: Colors.grey.shade700)),
                  ),
                  SizedBox(width: 12.w),
                  ElevatedButton.icon(
                    onPressed: _onCreateHere,
                    icon: const Icon(Icons.add_location_alt, size: 20),
                    label: Text('Créer ici',
                        style: TextStyle(
                            fontSize: 36.sp, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          horizontal: 20.w, vertical: 12.h),
                      shape: squircleBorder(radius: 24.r),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Recenter button, alone in the bottom-right corner (Figma)
          if (!_isPicking)
            Positioned(
              right: 48.w,
              bottom: 100,
              child: Builder(
                builder: (context) {
                  final canRecenter = _userLocation != null && !_isCentered;
                  return _MapActionButton(
                    icon: Icons.my_location,
                    iconColor: canRecenter ? kTextPrimary : Colors.grey,
                    onTap: canRecenter ? _recenterMap : null,
                  );
                },
              ),
            ),
          // Top row: place search bar (fly map to a city/address), product
          // filter and create-shop buttons.
          if (!_isPicking && _hasMapAccess)
            Positioned(
              top: MediaQuery.of(context).padding.top + 24,
              left: 48.w,
              right: 48.w,
              child: Row(
                // The search bar grows a results dropdown below itself; keep
                // the buttons pinned to the first line.
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MapSearchBar(
                        key: _searchBarKey, onPlaceSelected: _onPlaceSelected),
                  ),
                  SizedBox(width: 30.w),
                  // Active filters: yellow icon + count badge (Figma)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _MapActionButton(
                        icon: Icons.tune,
                        iconColor: _selectedEans.isNotEmpty
                            ? kAccentYellow
                            : kTextPrimary,
                        onTap: _openFilterPage,
                      ),
                      if (_selectedEans.isNotEmpty)
                        Positioned(
                          top: -16.w,
                          right: -16.w,
                          child: Container(
                            width: 66.w,
                            height: 66.w,
                            decoration: const BoxDecoration(
                              color: kAccentYellow,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${_selectedEans.length}',
                                style: TextStyle(
                                  fontSize: 36.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 30.w),
                  _MapActionButton(
                    icon: Icons.add,
                    background: Theme.of(context).colorScheme.primary,
                    iconColor: Colors.white,
                    onTap: _enterPickMode,
                  ),
                ],
              ),
            ),
          if (_isLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 24 + 144.w + 24.h,
              left: 0,
              right: 0,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          // Trial countdown chip, below the search/filter/create row
          if (_freeTrialActive && !SubscriptionService.isSubscribed)
            Positioned(
              top: MediaQuery.of(context).padding.top + 24 + 144.w + 24.h,
              right: 48.w,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                ),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: squircleBorder(radius: 20.r),
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 42.sp,
                          color: Theme.of(context).colorScheme.primary),
                      SizedBox(width: 6.w),
                      Text(
                        'Essai gratuit : ${_formatTrialRemaining()}',
                        style: TextStyle(
                          fontSize: 38.sp,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if ((!AuthService.isLoggedIn || !SubscriptionService.isSubscribed) &&
              !_freeTrialActive)
            MapAccessOverlay(
              onAccessGranted: () => setState(() {}),
              onLoginSuccess: widget.onLoginSuccess,
              onFreeTrial: () {
                setState(() {
                  _trialEndsAt = DateTime.now()
                      .add(PreferencesHelper.mapFreeTrialDuration);
                });
                _startTrialTicker();
              },
            ),
        ],
      ),
    );
  }
}

/// Square floating button overlaid on the map (filter, create, recenter).
/// Figma spec: 48×48, radius 14, white or primary fill, soft shadow — ×3
/// for ScreenUtil units. Must stay the same height as the MapSearchBar so
/// the top row reads as one line.
class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color? background;
  final VoidCallback? onTap;

  const _MapActionButton({
    required this.icon,
    required this.iconColor,
    this.background,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 144.w,
        height: 144.w,
        decoration: ShapeDecoration(
          color: background ?? Colors.white,
          shape: squircleBorder(radius: 42.r),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(child: Icon(icon, color: iconColor, size: 72.sp)),
      ),
    );
  }
}
