import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/services/geocoding_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';

/// A search bar that lets the user look up a place/city/address and fly the
/// map there. Geocoding is debounced and backed by OpenStreetMap Nominatim.
class MapSearchBar extends StatefulWidget {
  final ValueChanged<PlaceResult> onPlaceSelected;

  const MapSearchBar({super.key, required this.onPlaceSelected});

  @override
  State<MapSearchBar> createState() => MapSearchBarState();
}

class MapSearchBarState extends State<MapSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  List<PlaceResult> _results = [];
  bool _isSearching = false;
  int _requestId = 0;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_isFocused != _focusNode.hasFocus) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(value));
  }

  Future<void> _search(String value) async {
    final requestId = ++_requestId;
    final results = await GeocodingService.search(value);
    // Ignore stale responses from earlier keystrokes
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  /// Dismiss the results dropdown and keyboard, e.g. when the user interacts
  /// with the map. Keeps the typed text so the query isn't lost.
  void closeResults() {
    if (_results.isEmpty && !_focusNode.hasFocus) return;
    _debounce?.cancel();
    setState(() {
      _results = [];
      _isSearching = false;
    });
    _focusNode.unfocus();
  }

  void _select(PlaceResult place) {
    _controller.text = place.displayName;
    setState(() => _results = []);
    _focusNode.unfocus();
    widget.onPlaceSelected(place);
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _results = [];
      _isSearching = false;
    });
    _focusNode.unfocus();
  }

  /// Splits [text] into plain/highlighted spans around the first
  /// case-insensitive match of [query], so the typed portion stands out in
  /// the suggestions list (e.g. "Mar" in "Marseille").
  List<InlineSpan> _highlightedSpans(String text, String query) {
    final baseStyle = AppTextStyles.bodyRegular15;
    final matchStyle = AppTextStyles.bodyBold15.copyWith(color: kAccentYellow);

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final matchIndex =
        text.toLowerCase().indexOf(trimmedQuery.toLowerCase());
    if (matchIndex == -1) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final matchEnd = matchIndex + trimmedQuery.length;
    return [
      if (matchIndex > 0)
        TextSpan(text: text.substring(0, matchIndex), style: baseStyle),
      TextSpan(text: text.substring(matchIndex, matchEnd), style: matchStyle),
      if (matchEnd < text.length)
        TextSpan(text: text.substring(matchEnd), style: baseStyle),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          // Same height as the square action buttons next to it (map.dart),
          // so the whole top row reads as one line — Figma: 48pt, radius 14.
          height: 144.w,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: squircleBorder(
              radius: 42.r,
              side: BorderSide(
                color: _isFocused ? kAccentYellow : kBorderDefault,
                width: _isFocused ? 1.5 : 1,
              ),
            ),
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(width: 39.w),
              Icon(Icons.search, color: Colors.grey[600], size: 60.sp),
              SizedBox(width: 12.w),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(fontSize: 42.sp),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Rechercher un lieu…',
                    hintStyle:
                        TextStyle(fontSize: 42.sp, color: Colors.grey[500]),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_isSearching)
                Padding(
                  padding: EdgeInsets.only(right: 14.w),
                  child: SizedBox(
                    width: 40.sp,
                    height: 40.sp,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (hasText)
                GestureDetector(
                  onTap: _clear,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child:
                        Icon(Icons.close, color: Colors.grey[500], size: 52.sp),
                  ),
                )
              else
                SizedBox(width: 39.w),
            ],
          ),
        ),
        if (_results.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 6.h),
            constraints: BoxConstraints(maxHeight: 0.4.sh),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: squircleBorder(radius: 16.r),
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(vertical: 4.h),
              itemCount: _results.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey[200]),
              itemBuilder: (context, index) {
                final place = _results[index];
                return InkWell(
                  onTap: () => _select(place),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    child: Row(
                      children: [
                        Icon(Icons.place_outlined,
                            size: 48.sp, color: Colors.grey[500]),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: _highlightedSpans(
                                place.displayName,
                                _controller.text,
                              ),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
