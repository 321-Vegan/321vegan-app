import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import '../../models/restaurants/restaurant.dart';
import '../../services/geocoding_service.dart';
import '../../services/restaurant_api_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../restaurants/restaurant_pin.dart';
import '../shared/app_background.dart';
import '../shared/search_field.dart';

/// Full-page search of the map: places/addresses (Nominatim), plus the
/// restaurants matching by name when [includeRestaurants]. Pops with the
/// chosen [PlaceResult] or [Restaurant], or null when left.
class MapSearchPage extends StatefulWidget {
  final String initialQuery;
  final bool includeRestaurants;

  /// Restaurants closest to it come first (the map center).
  final LatLng? center;

  const MapSearchPage({
    super.key,
    this.initialQuery = '',
    this.includeRestaurants = false,
    this.center,
  });

  @override
  State<MapSearchPage> createState() => _MapSearchPageState();
}

class _MapSearchPageState extends State<MapSearchPage> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  List<Restaurant> _restaurants = [];
  List<PlaceResult> _places = [];
  bool _isSearching = false;
  int _requestId = 0;

  // Nominatim asks for at least 3 characters; restaurant names can be short.
  static const _minPlaceLength = 3;
  static const _minRestaurantLength = 2;

  int get _minLength =>
      widget.includeRestaurants ? _minRestaurantLength : _minPlaceLength;

  @override
  void initState() {
    super.initState();
    if (_controller.text.trim().length >= _minLength) _search(_controller.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < _minLength) {
      _requestId++;
      setState(() {
        _restaurants = [];
        _places = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String value) async {
    final requestId = ++_requestId;
    setState(() => _isSearching = true);
    final query = value.trim();
    final (restaurants, places) = await (
      widget.includeRestaurants
          ? RestaurantApiService.searchRestaurants(
              query,
              latitude: widget.center?.latitude,
              longitude: widget.center?.longitude,
            )
          : Future.value(<Restaurant>[]),
      query.length >= _minPlaceLength
          ? GeocodingService.search(query)
          : Future.value(<PlaceResult>[]),
    ).wait;
    // Ignore stale responses from earlier keystrokes
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _restaurants = restaurants ?? [];
      _places = places;
      _isSearching = false;
    });
  }

  /// Splits [text] into plain/highlighted spans around the first
  /// case-insensitive match of the query, so the typed portion stands out
  /// (e.g. "Mar" in "Marseille").
  List<InlineSpan> _highlightedSpans(String text, TextStyle baseStyle) {
    final matchStyle = baseStyle
        .merge(AppTextStyles.bodyBold15.copyWith(color: kAccentYellow));
    final query = _controller.text.trim();
    final matchIndex =
        query.isEmpty ? -1 : text.toLowerCase().indexOf(query.toLowerCase());
    if (matchIndex == -1) return [TextSpan(text: text, style: baseStyle)];

    final matchEnd = matchIndex + query.length;
    return [
      if (matchIndex > 0)
        TextSpan(text: text.substring(0, matchIndex), style: baseStyle),
      TextSpan(text: text.substring(matchIndex, matchEnd), style: matchStyle),
      if (matchEnd < text.length)
        TextSpan(text: text.substring(matchEnd), style: baseStyle),
    ];
  }

  static const double _pinSize = 26;

  /// Same for every row so the texts line up, wide enough for the
  /// restaurant pins (pills with several tags).
  double get _leadingWidth => _restaurants.fold(60.sp,
      (width, r) => math.max(width, RestaurantPin.widthFor(r, _pinSize)));

  Widget _row({
    required Widget leading,
    required String title,
    TextStyle? titleStyle,
    String? subtitle,
    Color? subtitleColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 60.w, vertical: 24.h),
        child: Row(
          children: [
            SizedBox(width: _leadingWidth, child: Center(child: leading)),
            SizedBox(width: 30.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: _highlightedSpans(
                          title, titleStyle ?? AppTextStyles.bodyRegular15),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: AppTextStyles.bodyRegular13
                          .copyWith(color: subtitleColor ?? Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _restaurantRow(Restaurant restaurant) {
    final closed = restaurant.isPermanentlyClosed;
    return _row(
      leading:
          RestaurantPin(restaurant: restaurant, size: _pinSize, shadow: false),
      title: restaurant.name,
      titleStyle: closed
          ? AppTextStyles.bodyRegular15.copyWith(
              color: Colors.grey[500],
              decoration: TextDecoration.lineThrough,
              decorationColor: kSemanticError,
            )
          : null,
      subtitle: [
        if (closed) 'Fermé définitivement',
        if (restaurant.city != null) restaurant.city!,
      ].join(' · ').ifNotEmpty,
      subtitleColor: closed ? kSemanticError : null,
      onTap: () => Navigator.of(context).pop(restaurant),
    );
  }

  Widget _placeRow(PlaceResult place) {
    return _row(
      leading: Icon(Icons.place_outlined, size: 60.sp, color: Colors.grey[600]),
      title: place.displayName,
      onTap: () => Navigator.of(context).pop(place),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = _restaurants.isNotEmpty || _places.isNotEmpty;
    final noResults = !hasResults &&
        !_isSearching &&
        _controller.text.trim().length >= _minLength;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(48.w, 24.h, 48.w, 12.h),
                child: SearchField(
                  controller: _controller,
                  hintText: widget.includeRestaurants
                      ? 'Rechercher un lieu, une adresse...'
                      : 'Rechercher l\'endroit...',
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: _onChanged,
                  onSubmitted: _search,
                  leading: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.arrow_back,
                        size: 60.sp, color: Colors.grey[600]),
                  ),
                  trailing: _isSearching
                      ? Padding(
                          padding: EdgeInsets.all(42.w),
                          child: SizedBox(
                            width: 40.sp,
                            height: 40.sp,
                            child:
                                const CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              Expanded(
                child: noResults
                    ? Padding(
                        padding: EdgeInsets.only(top: 60.h),
                        child: Text(
                          'Aucun résultat',
                          style: AppTextStyles.bodyRegular15
                              .copyWith(color: Colors.grey[600]),
                        ),
                      )
                    : ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).padding.bottom),
                        children: [
                          for (final restaurant in _restaurants)
                            _restaurantRow(restaurant),
                          for (final place in _places) _placeRow(place),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on String {
  String? get ifNotEmpty => isEmpty ? null : this;
}
