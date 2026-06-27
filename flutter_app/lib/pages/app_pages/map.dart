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
import 'package:vegan_app/widgets/map/create_shop_sheet.dart';
import 'package:vegan_app/widgets/map/map_access_overlay.dart';
import 'package:vegan_app/widgets/map/map_filter_sheet.dart';
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
    super.dispose();
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

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: MapFilterSheet(
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
      // Transparent so the sheet can draw its own surface lower down, leaving
      // room above it for the floating itinerary button to stay tappable.
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8.r),
                        boxShadow: [
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
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20.r),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.r),
                      ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!_isPicking)
            Positioned(
              right: 24.w,
              bottom: 100,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _showFilterSheet,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 4.w, vertical: 8.h),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search,
                                color: Theme.of(context).colorScheme.primary,
                                size: 100.sp),
                            SizedBox(height: 2.h),
                            Text('Produits',
                                style: TextStyle(
                                    fontSize: 28.sp,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    Container(
                        height: 1, width: 36.w, color: Colors.grey.shade300),
                    GestureDetector(
                      onTap: _enterPickMode,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 4.w, vertical: 8.h),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_location_alt,
                                color: Theme.of(context).colorScheme.primary,
                                size: 100.sp),
                            SizedBox(height: 2.h),
                            Text('Créer',
                                style: TextStyle(
                                    fontSize: 28.sp,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    Container(
                        height: 1, width: 36.w, color: Colors.grey.shade300),
                    Builder(
                      builder: (context) {
                        final canRecenter =
                            _userLocation != null && !_isCentered;
                        final color = canRecenter
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey;
                        return GestureDetector(
                          onTap: canRecenter ? _recenterMap : null,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 4.w, vertical: 8.h),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.my_location,
                                    color: color, size: 100.sp),
                                SizedBox(height: 2.h),
                                Text('Recentrer',
                                    style: TextStyle(
                                        fontSize: 28.sp,
                                        color: color,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          // Place search bar (fly map to a city/address)
          if (!_isPicking && _hasMapAccess)
            Positioned(
              top: MediaQuery.of(context).padding.top + 32,
              left: 16.w,
              right: MediaQuery.of(context).size.width * 0.45,
              child: MapSearchBar(
                  key: _searchBarKey, onPlaceSelected: _onPlaceSelected),
            ),
          if (_isLoading)
            const Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          if (_selectedEans.isNotEmpty)
            Positioned(
              top: 110,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _showFilterSheet,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
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
                        Icon(Icons.filter_list,
                            size: 42.sp, color: Colors.white),
                        SizedBox(width: 6.w),
                        Text(
                          '${_selectedEans.length} filtre${_selectedEans.length > 1 ? 's' : ''} actif${_selectedEans.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 42.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        GestureDetector(
                          onTap: () {
                            setState(() => _selectedEans = {});
                            _loadShops();
                          },
                          child: Icon(Icons.close,
                              size: 60.sp, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Trial countdown chip
          if (_freeTrialActive && !SubscriptionService.isSubscribed)
            Positioned(
              top: MediaQuery.of(context).padding.top + 36,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                ),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
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
