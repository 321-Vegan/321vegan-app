import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/restaurants/restaurant_selection.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../shared/tag_chip.dart';
import 'restaurant_detail_page.dart';
import 'restaurant_labels.dart';
import 'restaurant_list_card.dart';
import 'restaurant_pin.dart';
import 'selection_author_review.dart';

const double _pinSize = 34;

/// Street level, where a place picked in the carousel is shown.
const double _placeZoom = 16;

/// Map of a selection's places only, framed on them, with the places in a
/// carousel at the bottom, in the selection's order. Swiping the carousel
/// moves the map to the place shown; tapping a pin brings its place in the
/// carousel. Tapping a place opens its page, and going back returns here.
class SelectionMapPage extends StatefulWidget {
  /// Loaded with its items.
  final RestaurantSelection selection;

  const SelectionMapPage({super.key, required this.selection});

  static Future<void> open(
      BuildContext context, RestaurantSelection selection) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SelectionMapPage(selection: selection),
    ));
  }

  @override
  State<SelectionMapPage> createState() => _SelectionMapPageState();
}

class _SelectionMapPageState extends State<SelectionMapPage>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();
  final _pageController = PageController(viewportFraction: 0.9);
  late final _moveController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  CachedTileProvider? _tileProvider;

  /// Place shown in the carousel, highlighted on the map.
  int _current = 0;

  List<RestaurantSelectionItem> get _items => widget.selection.items;

  /// Height of the carousel cards, all alike: photo, name, city and one
  /// chip.
  double get _carouselHeight => 285.h;
  double get _overlayHeight =>
      _carouselHeight + MediaQuery.of(context).padding.bottom + 36.h;

  @override
  void initState() {
    super.initState();
    _moveController.addListener(_onMoveTick);
    _initTileCache();
  }

  @override
  void dispose() {
    _moveController.dispose();
    _pageController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Same tile cache as the main map.
  Future<void> _initTileCache() async {
    final dir = await getTemporaryDirectory();
    final store =
        FileCacheStore('${dir.path}${Platform.pathSeparator}MapTiles');
    if (mounted) {
      setState(() {
        _tileProvider = CachedTileProvider(
          maxStale: const Duration(days: 30),
          store: store,
        );
      });
    }
  }

  LatLng _point(int index) {
    final r = _items[index].restaurant;
    return LatLng(r.latitude, r.longitude);
  }

  /// Map center at the start and end of the current move, in pixels at
  /// [_toZoom], and the zooms it goes between.
  Offset _moveFrom = Offset.zero;
  Offset _moveTarget = Offset.zero;
  double _fromZoom = 0;
  double _toZoom = 0;

  void _onMoveTick() {
    final t = Curves.easeInOut.transform(_moveController.value);
    final position = Offset.lerp(_moveFrom, _moveTarget, t)!;
    _mapController.move(
      _mapController.camera.unprojectAtZoom(position, _toZoom),
      _fromZoom + (_toZoom - _fromZoom) * t,
    );
  }

  /// Slides the map and zooms in to street level (or stays closer), so the
  /// place sits in the middle of the part the carousel leaves visible.
  void _moveTo(int index) {
    final camera = _mapController.camera;
    _fromZoom = camera.zoom;
    _toZoom = math.max(camera.zoom, _placeZoom);
    _moveFrom = camera.projectAtZoom(camera.center, _toZoom);
    _moveTarget = camera.projectAtZoom(_point(index), _toZoom) +
        Offset(0, _overlayHeight / 2);
    _moveController.forward(from: 0);
  }

  void _onPageChanged(int index) {
    setState(() => _current = index);
    _moveTo(index);
  }

  void _onPinTap(int index) {
    if (index == _current) {
      _moveTo(index);
      return;
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  /// With the author's rating above it, as the reviews average on the map.
  Marker _marker(int index) {
    final item = _items[index];
    final r = item.restaurant;
    final size = index == _current ? _pinSize * 1.25 : _pinSize;
    return Marker(
      point: _point(index),
      width: RestaurantPin.widthFor(r, size, showRating: true),
      height: RestaurantPin.heightFor(size, showRating: true),
      child: GestureDetector(
        onTap: () => _onPinTap(index),
        child: RestaurantPin(
          restaurant: r,
          size: size,
          showRating: true,
          rating: item.authorRating?.toDouble(),
        ),
      ),
    );
  }

  /// Without the note, so every card has the same height; the author's
  /// rating beside the status chip, opening their review.
  Widget _buildCard(RestaurantSelectionItem item) {
    final r = item.restaurant;
    final author =
        widget.selection.isOwner ? null : widget.selection.ownerNickname;
    return RestaurantListCard(
      restaurant: r,
      onTap: () => RestaurantDetailPage.open(
        context,
        r,
        selectionNote: item.note,
        selectionNoteAuthor: author,
      ),
      badges: [
        if (r.isPermanentlyClosed)
          const TagChip(label: 'Fermé définitivement', color: kSemanticError)
        else
          VeganStatusChip(isFullyVegan: r.isFullyVegan),
        if (item.authorRating != null)
          AuthorRatingPill(
            rating: item.authorRating!,
            onTap: item.authorReviewId == null
                ? null
                : () => showAuthorReviewSheet(
                      context,
                      reviewId: item.authorReviewId!,
                      restaurant: r,
                      authorNickname: author,
                    ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final overlay = _overlayHeight;
    final points = [for (var i = 0; i < _items.length; i++) _point(i)];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selection.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.baloo22),
        centerTitle: true,
        backgroundColor: kBackgroundGradientTop,
        elevation: 0,
        foregroundColor: kTextPrimary,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // Every place visible above the carousel
              initialCameraFit: CameraFit.coordinates(
                coordinates: points,
                padding: EdgeInsets.fromLTRB(60, 60, 60, overlay + 30),
                maxZoom: 16,
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                scrollWheelVelocity: 0.0025,
              ),
              // The user takes over: no move fighting the gesture
              onPointerDown: (_, __) => _moveController.stop(),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'fr.321vegan.app',
                tileProvider: _tileProvider,
              ),
              MarkerLayer(markers: [
                // The current pin drawn last, above the others
                for (var i = 0; i < _items.length; i++)
                  if (i != _current) _marker(i),
                if (_items.isNotEmpty) _marker(_current),
              ]),
              // Above the carousel, which covers the bottom of the map, and
              // the pins, which would hide it once opened
              Padding(
                padding: EdgeInsets.only(bottom: overlay),
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
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 36.h,
            height: _carouselHeight,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _items.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (_, index) => Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                // Fills the carousel height, its content centered
                child: _buildCard(_items[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
