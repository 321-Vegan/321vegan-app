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
import 'package:vegan_app/helpers/restaurant_drafts.dart';
import 'package:vegan_app/models/restaurants/restaurant.dart';
import 'package:vegan_app/models/shops/shop.dart';
import 'package:vegan_app/pages/app_pages/Profile/saved_restaurants_page.dart';
import 'package:vegan_app/pages/app_pages/Profile/subscription_page.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/services/auth_service.dart';
import 'package:vegan_app/services/restaurant_api_service.dart';
import 'package:vegan_app/services/subscription_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/map/create_shop_sheet.dart';
import 'package:vegan_app/widgets/map/map_access_overlay.dart';
import 'package:vegan_app/widgets/map/map_filter_page.dart';
import 'package:vegan_app/widgets/map/map_search_bar.dart';
import 'package:vegan_app/widgets/map/map_search_page.dart';
import 'package:vegan_app/widgets/map/shop_detail_sheet.dart';
import 'package:vegan_app/widgets/restaurants/create_restaurant_page.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_detail_page.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_drafts_list.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_filter_sheet.dart';
import 'package:vegan_app/widgets/restaurants/restaurant_pin.dart';
import 'package:vegan_app/services/geocoding_service.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';
import 'package:vegan_app/widgets/shared/square_icon_button.dart';

/// Places shown on the map, one kind at a time.
enum _MapLayer { shops, restaurants }

const _compactPinsBelowZoom = 15.0;

/// A bit smaller than the shop pins (40), to make room for the stars.
const double _restaurantPinSize = 34;

class MapPage extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const MapPage({super.key, this.onLoginSuccess});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  // Last result chosen in the search page, shown in the search bar
  String _searchQuery = '';
  _MapLayer _layer = _MapLayer.shops;
  List<Shop> _shops = [];
  List<Restaurant> _restaurants = [];
  RestaurantMapFilters _restaurantFilters = const RestaurantMapFilters();
  // Drops the answer of a load superseded by a newer one (map moved,
  // layer switched) so it can't overwrite fresher results.
  int _loadId = 0;
  bool _mapReady = false;
  bool _isLoading = true;
  bool _isPicking = false;
  bool _isCentered = false;
  bool _isShowingMembershipPrompt = false;
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
    _restoreLayer();
    _initLocation();
  }

  /// Counts a meaningful map action for non-subscribers and, once enough
  /// have piled up, invites them to subscribe (same flow as the scan page).
  Future<void> _trackMapAction() async {
    if (SubscriptionService.isSubscribed) return;
    final shouldPrompt =
        await PreferencesHelper.incrementMapMembershipActionCount();
    if (shouldPrompt) _showMembershipPromptAfterDelay();
  }

  Future<void> _showMembershipPromptAfterDelay() async {
    if (_isShowingMembershipPrompt) return;
    _isShowingMembershipPrompt = true;
    // Small delay so the result of the action shows first
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) {
      _isShowingMembershipPrompt = false;
      return;
    }

    await PreferencesHelper.snoozeMapMembershipPrompt();
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SubscriptionPage(
            title: 'Vous utilisez souvent la carte,\nsoutenez le projet ?',
          ),
        ),
      );
    }
    _isShowingMembershipPrompt = false;
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
    _positionStreamSub?.cancel();
    super.dispose();
  }

  /// Tracks the user's position so the blue dot follows them; when the map
  /// is centered on the user it keeps following ("follow me").
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
            _loadPlaces();
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

  Future<void> _loadPlaces() async {
    if (!mounted) return;
    // Shop endpoints require an account; the access overlay covers the map
    if (!AuthService.isLoggedIn) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    final loadId = ++_loadId;

    final bounds = _mapController.camera.visibleBounds;

    if (_layer == _MapLayer.restaurants) {
      final filters = _restaurantFilters;
      final restaurants = await RestaurantApiService.getRestaurantsInArea(
        minLat: bounds.south,
        maxLat: bounds.north,
        minLng: bounds.west,
        maxLng: bounds.east,
        tags: filters.tags,
        serviceOptions: filters.serviceOptions,
        fullyVeganOnly: filters.fullyVeganOnly,
        noPlantMilkSurcharge: filters.noPlantMilkSurcharge,
        glutenFreeOptions: filters.glutenFreeOptions,
      );
      if (!mounted || loadId != _loadId) return;
      final now = DateTime.now();
      setState(() {
        _restaurants = restaurants.where((r) => filters.keeps(r, now)).toList();
        _isLoading = false;
      });
      return;
    }

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

    if (mounted && loadId == _loadId) {
      setState(() {
        _shops = shops;
        _isLoading = false;
      });
    }
  }

  void _switchLayer(_MapLayer layer) {
    if (layer == _layer) return;
    setState(() => _layer = layer);
    PreferencesHelper.setLastMapLayerPref(layer.name);
    _loadPlaces();
  }

  /// Back on the layer shown last time. Usually read before the map is
  /// ready; otherwise the places are reloaded for it.
  Future<void> _restoreLayer() async {
    final saved = await PreferencesHelper.getLastMapLayerPref();
    final layer = _MapLayer.values.where((l) => l.name == saved).firstOrNull;
    if (layer == null || layer == _layer || !mounted) return;
    setState(() => _layer = layer);
    if (_mapReady) _loadPlaces();
  }

  int get _activeFilterCount => _layer == _MapLayer.restaurants
      ? _restaurantFilters.count
      : _selectedEans.length;

  Future<void> _openFilters() async {
    if (_layer == _MapLayer.shops) return _openFilterPage();
    final filters =
        await showRestaurantFilterSheet(context, _restaurantFilters);
    if (filters == null || !mounted) return;
    setState(() => _restaurantFilters = filters);
    _loadPlaces();
    if (filters.count > 0) _trackMapAction();
  }

  void _openFilterPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapFilterPage(
          selectedEans: _selectedEans,
          onApply: (newSelection) {
            setState(() => _selectedEans = newSelection);
            _loadPlaces();
            if (newSelection.isNotEmpty) _trackMapAction();
          },
        ),
      ),
    );
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd) {
      // Only mark as not centered when the user manually moves the map
      if (event.source != MapEventSource.mapController && _isCentered) {
        setState(() => _isCentered = false);
      }
      _loadPlaces();
    }
  }

  void _onMapReady() {
    _mapReady = true;
    _loadPlaces();
  }

  Widget _buildMarkerIcon(Shop shop) {
    final isVegan = shop.shopType == 'vegan';
    if (isVegan) {
      return Container(
        decoration: BoxDecoration(
          color: kSemanticSuccess,
          shape: BoxShape.circle,
          border: Border.all(color: kSemanticSuccess, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.eco, color: Colors.white, size: 22),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 12,
          side: const BorderSide(color: kAccentYellow, width: 1),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Image.asset(
        'lib/assets/images/icons/pin-shop.webp',
        color: kAccentYellow,
        colorBlendMode: BlendMode.srcIn,
      ),
    );
  }

  List<Marker> _buildMarkers() {
    if (_layer == _MapLayer.restaurants) {
      // Zoomed out, one icon per pin: wide multi-tag pins crowd the map
      final compact =
          _mapReady && _mapController.camera.zoom < _compactPinsBelowZoom;
      final now = DateTime.now();
      return [
        for (final restaurant in _restaurants)
          for (final (point, dimmed) in _pinPoints(restaurant, now))
            Marker(
              point: point,
              // Widens with several tags; the reviews average sits above
              width: RestaurantPin.widthFor(restaurant, _restaurantPinSize,
                  compact: compact, showRating: true),
              height:
                  RestaurantPin.heightFor(_restaurantPinSize, showRating: true),
              child: GestureDetector(
                onTap: () => _onRestaurantTap(restaurant),
                child: RestaurantPin(
                  restaurant: restaurant,
                  size: _restaurantPinSize,
                  compact: compact,
                  showRating: true,
                  dimmed: dimmed,
                ),
              ),
            ),
      ];
    }
    return [
      for (final shop in _shops)
        Marker(
          point: LatLng(shop.latitude, shop.longitude),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _onShopTap(shop),
            child: _buildMarkerIcon(shop),
          ),
        ),
    ];
  }

  /// Where to pin [restaurant]: its position, or each stop of a food truck,
  /// faded unless it goes there today (so when its days there vary too).
  /// With the "open now" filter, only the stop it is at right now.
  List<(LatLng, bool)> _pinPoints(Restaurant restaurant, DateTime now) {
    if (restaurant.stops.isEmpty) {
      return [(LatLng(restaurant.latitude, restaurant.longitude), false)];
    }
    final today = now.weekday - 1;
    return [
      for (final stop in restaurant.stops)
        if (OpeningState.of(stop.openingHours, now)?.isOpen == true)
          (LatLng(stop.latitude, stop.longitude), false)
        else if (!_restaurantFilters.openNow)
          (LatLng(stop.latitude, stop.longitude), !stop.isOnDay(today)),
    ];
  }

  Future<void> _onRestaurantTap(Restaurant restaurant) async {
    await RestaurantDetailPage.open(context, restaurant);
    if (mounted) _trackMapAction();
  }

  Future<void> _onShopTap(Shop shop) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Transparent so the sheet's own rounded surface shows the map behind
      // its top corners.
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => ShopDetailSheet(shop: shop),
    );
    // Counted once the sheet is closed so the prompt never covers it
    if (mounted) _trackMapAction();
  }

  /// Shops are placed with the pin; restaurants are placed from their
  /// address in the creation form (the pin stays available there).
  void _onAddPlace() {
    if (_layer == _MapLayer.restaurants) {
      _createRestaurant();
      return;
    }
    setState(() => _isPicking = true);
  }

  void _onLoginSuccess() {
    widget.onLoginSuccess?.call();
    if (!mounted) return;
    setState(() {});
    _loadPlaces();
  }

  void _onCreateHere() {
    final coords = _mapController.camera.center;
    setState(() => _isPicking = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateShopSheet(coordinates: coords),
    ).then((created) {
      if (created == true) _loadPlaces();
    });
  }

  /// Opens the creation form, after offering to go on with a draft saved
  /// on this device.
  Future<void> _createRestaurant() async {
    RestaurantDraft? draft;
    final drafts = await RestaurantDrafts.all();
    if (!mounted) return;
    if (drafts.isNotEmpty) {
      final choice = await showRestaurantDraftPicker(context, drafts);
      if (choice == null || !mounted) return;
      draft = choice.draft;
    }
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => CreateRestaurantPage(
            mapCenter: _mapController.camera.center, draft: draft),
      ),
    );
    if (!mounted) return;
    // Already referenced: show where, among the places pins
    if (result is LatLng) {
      _switchLayer(_MapLayer.restaurants);
      setState(() => _isCentered = false);
      _mapController.move(result, 18);
      _loadPlaces();
      return;
    }
    if (result != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Merci ! Le lieu sera visible après '
            'validation.'),
        backgroundColor: kSemanticSuccess,
      ),
    );
    _loadPlaces();
  }

  /// Full-page search: places, plus restaurants by name on the restaurants
  /// layer. Flies the map to the chosen one (and opens a restaurant).
  Future<void> _openSearch() async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => MapSearchPage(
          initialQuery: _searchQuery,
          includeRestaurants: _layer == _MapLayer.restaurants,
          center: _mapController.camera.center,
        ),
      ),
    );
    if (!mounted) return;
    if (result is PlaceResult) {
      setState(() {
        _searchQuery = result.displayName;
        _isCentered = false;
      });
      _mapController.move(LatLng(result.latitude, result.longitude), 14);
    } else if (result is Restaurant) {
      setState(() => _searchQuery = result.name);
      _showRestaurant(result);
      return;
    } else {
      return;
    }
    _loadPlaces();
    _trackMapAction();
  }

  /// Saved places; the chosen one is shown on the map.
  Future<void> _openSaved() async {
    final restaurant = await Navigator.of(context).push<Restaurant>(
      MaterialPageRoute(
          builder: (_) => const SavedRestaurantsPage(pickOnTap: true)),
    );
    if (restaurant != null && mounted) _showRestaurant(restaurant);
  }

  /// Flies the map to [restaurant] on the restaurants layer and opens it.
  void _showRestaurant(Restaurant restaurant) {
    _switchLayer(_MapLayer.restaurants);
    setState(() => _isCentered = false);
    _mapController.move(LatLng(restaurant.latitude, restaurant.longitude), 17);
    _loadPlaces();
    _onRestaurantTap(restaurant);
  }

  void _recenterMap() {
    if (_userLocation != null) {
      setState(() => _isCentered = true);
      _mapController.move(_userLocation!, 16);
      _loadPlaces();
    } else {
      _initLocation();
    }
  }

  Widget _buildLayerToggle() {
    final primary = Theme.of(context).colorScheme.primary;

    Widget segment(
        _MapLayer layer, Widget Function(Color color) icon, String label) {
      final selected = _layer == layer;
      final color = selected ? Colors.white : kTextPrimary;
      return Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: () => _switchLayer(layer),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(horizontal: 42.w, vertical: 21.h),
            decoration: ShapeDecoration(
              color: selected ? primary : Colors.transparent,
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon(color),
                SizedBox(width: 12.w),
                Text(label,
                    style: AppTextStyles.bodyMedium13.copyWith(color: color)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(9.w),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: const StadiumBorder(),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Same icons as the map pins
          segment(
            _MapLayer.shops,
            (color) => Image.asset(
              'lib/assets/images/icons/pin-shop.webp',
              width: 48.sp,
              height: 48.sp,
              color: color,
              colorBlendMode: BlendMode.srcIn,
            ),
            'Magasins',
          ),
          segment(
            _MapLayer.restaurants,
            (color) => Icon(Icons.restaurant, size: 48.sp, color: color),
            'Lieux',
          ),
        ],
      ),
    );
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
              // Keep the map north-up: strip the rotate gesture (twist +
              // ctrl/trackpad) so users can't accidentally spin it.
              // Halve the scroll-wheel/trackpad zoom step (default 0.005) so
              // zooming feels less jumpy.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                scrollWheelVelocity: 0.0025,
              ),
              onMapEvent: _onMapEvent,
              onMapReady: _onMapReady,
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
                  markers: _buildMarkers(),
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        color: _layer == _MapLayer.restaurants
                            ? kSemanticSuccess
                            : kAccentYellow,
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
                    Image.asset(
                      'lib/assets/images/icons/map-marker-plus.webp',
                      color: Theme.of(context).colorScheme.primary,
                      colorBlendMode: BlendMode.srcIn,
                      width: 48,
                      height: 48,
                    ),
                  ],
                ),
              ),
            ),
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
            // "Créer ici" + "Annuler" buttons — same pairing as everywhere
            // else in the app: two AppButtons, the cancel one white/outlined.
            Positioned(
              bottom: 100,
              left: 48.w,
              right: 48.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label: 'Créer le magasin ici',
                    iconAsset: 'lib/assets/images/icons/map-marker-plus.webp',
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    onPressed: _onCreateHere,
                  ),
                  SizedBox(height: 16.h),
                  AppButton(
                    label: 'Annuler',
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.grey[700]!,
                    borderColor: kBorderDefault,
                    onPressed: () => setState(() => _isPicking = false),
                  ),
                ],
              ),
            ),
          ],
          // Bottom-right corner: recenter, and the saved places under it (places
          // layer)
          if (!_isPicking)
            Positioned(
              right: 48.w,
              bottom: 100,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) {
                      final canRecenter = _userLocation != null && !_isCentered;
                      return SquareIconButton.action(
                        icon: Icons.my_location,
                        iconColor: canRecenter ? kTextPrimary : Colors.grey,
                        onTap: canRecenter ? _recenterMap : null,
                      );
                    },
                  ),
                  // Saved places are restaurants: on their layer only
                  if (AuthService.isLoggedIn &&
                      _layer == _MapLayer.restaurants) ...[
                    SizedBox(height: 30.w),
                    Semantics(
                      button: true,
                      label: 'Lieux sauvegardés',
                      child: SquareIconButton.action(
                        icon: Icons.bookmark_border,
                        onTap: _openSaved,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          // Shops / restaurants switch, centered at the very bottom (the
          // bottom nav sits under the map, not over it).
          if (!_isPicking && AuthService.isLoggedIn)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(child: _buildLayerToggle()),
            ),
          // Top row: search bar (opens the search page), filters and
          // create-place buttons.
          if (!_isPicking && AuthService.isLoggedIn)
            Positioned(
              top: MediaQuery.of(context).padding.top + 24,
              left: 48.w,
              right: 48.w,
              child: Row(
                children: [
                  Expanded(
                    child: MapSearchBar(
                      query: _searchQuery,
                      hintText: _layer == _MapLayer.restaurants
                          ? 'Rechercher un lieu, une adresse...'
                          : 'Rechercher l\'adresse',
                      onTap: _openSearch,
                      onClear: () => setState(() => _searchQuery = ''),
                    ),
                  ),
                  SizedBox(width: 30.w),
                  // Active filters: yellow icon + count badge (Figma)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SquareIconButton.action(
                        icon: Icons.tune,
                        iconColor: _activeFilterCount > 0
                            ? kAccentYellow
                            : kTextPrimary,
                        onTap: _openFilters,
                      ),
                      if (_activeFilterCount > 0)
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
                                '$_activeFilterCount',
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
                  SquareIconButton.action(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    onTap: _onAddPlace,
                    child: _layer == _MapLayer.restaurants
                        ? Icon(Icons.add_location_alt_outlined,
                            color: Colors.white, size: 72.sp)
                        : Image.asset(
                            'lib/assets/images/icons/shop-add.webp',
                            width: 72.sp,
                            height: 72.sp,
                            color: Colors.white,
                            colorBlendMode: BlendMode.srcIn,
                          ),
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
          if (!AuthService.isLoggedIn)
            MapAccessOverlay(onLoginSuccess: _onLoginSuccess),
        ],
      ),
    );
  }
}
