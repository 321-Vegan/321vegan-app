import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/restaurants/restaurant.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../reviews/star_rating.dart';
import 'restaurant_labels.dart';

/// Squircle restaurant pin, as on the map: green for a fully vegan place, orange for
/// vegan options, grey while closed. Holds one white squircle per tag with its
/// icon in the tag color (up to [_maxIcons], then a "+"), so it widens with
/// several tags. Struck through in red when closed for good,
/// and faded while the user's own restaurant is pending, or with [dimmed].
/// With [showRating], [rating] above it ("★ 4,3").
class RestaurantPin extends StatelessWidget {
  final Restaurant restaurant;

  /// Height of the pin (and width with a single tag).
  final double size;
  final bool shadow;

  /// A single icon: the tag's, or [_multipleTagsIcon] with several tags.
  /// For when the map is zoomed out and wide pins would crowd it.
  final bool compact;

  /// [rating] above the pin ("★ 4,3"). The room is kept without one, so
  /// every marker has the same anchor.
  final bool showRating;

  /// Shown with [showRating]: the reviews average on the map, the author's
  /// rating on a selection's map. Nothing when null.
  final double? rating;

  /// Faded, e.g. a food truck's stop where it isn't today.
  final bool dimmed;

  const RestaurantPin({
    super.key,
    required this.restaurant,
    this.size = 40,
    this.shadow = true,
    this.compact = false,
    this.showRating = false,
    this.rating,
    this.dimmed = false,
  });

  static const _maxIcons = 3;
  // Colored frame (and gaps between icons) of 2 px on a 40 px pin, like
  // the border of the shop pins
  static const _discRatio = 0.9;
  static const _gapRatio = 0.05;
  static const _radiusRatio = 0.3;
  // 20 px icons on a 40 px pin, the same weight as the shop pins
  static const _iconRatio = 0.5;
  static const _multipleTagsIcon = Icons.category;
  // "★ 4,3" badge: 11 px text on a 34 px pin
  static const _ratingFontRatio = 0.32;
  static const _ratingPadding = 4.0;
  static const _ratingGap = 2.0;

  /// Enough for a star and "4,3".
  static double _ratingWidth(double size) =>
      size * _ratingFontRatio * 3.4 + 2 * _ratingPadding;
  static double _ratingHeight(double size) => size * _ratingFontRatio * 1.3 + 2;

  /// Tags without any: a caterer when there is no storefront.
  static List<String> _tags(Restaurant restaurant) => restaurant.tags.isNotEmpty
      ? restaurant.tags
      : [restaurant.hasStorefront ? 'restaurant' : RestaurantTags.caterer];

  /// Number of discs: the tag icons, plus the "+" when some don't fit.
  static int _discCount(Restaurant restaurant, bool compact) =>
      compact ? 1 : math.min(_tags(restaurant).length, _maxIcons + 1);

  static double _pinWidth(Restaurant restaurant, double size, bool compact) {
    final count = _discCount(restaurant, compact);
    final disc = size * _discRatio;
    final padding = size - disc;
    return padding + count * disc + (count - 1) * size * _gapRatio;
  }

  /// Width of the pin for [restaurant], e.g. for its map Marker.
  static double widthFor(Restaurant restaurant, double size,
      {bool compact = false, bool showRating = false}) {
    final pin = _pinWidth(restaurant, size, compact);
    return showRating ? math.max(pin, _ratingWidth(size)) : pin;
  }

  /// Height of the pin, e.g. for its map Marker.
  static double heightFor(double size, {bool showRating = false}) =>
      showRating ? size + _ratingGap + _ratingHeight(size) : size;

  @override
  Widget build(BuildContext context) {
    final closed = restaurant.isClosedNow;
    final background = closed
        ? Colors.grey
        : restaurant.isFullyVegan
            ? kSemanticSuccess
            : kVeganOptionsOrange;
    final tags = _tags(restaurant);
    final multipleCompact = compact && tags.length > 1;
    final shown = multipleCompact
        ? const <String>[]
        : tags.length > _maxIcons
            ? tags.take(_maxIcons).toList()
            : tags;
    final hasMore = !compact && tags.length > shown.length;
    final disc = size * _discRatio;
    final width = _pinWidth(restaurant, size, compact);
    // Concentric corners: the pin's radius is the discs' plus their margin
    final discRadius = disc * _radiusRatio;
    final pinRadius = discRadius + (size - disc) / 2;

    Widget discOf(Widget child) => Container(
          width: disc,
          height: disc,
          decoration: ShapeDecoration(
            // Lets the pin color show through a little
            color: Colors.white.withValues(alpha: 0.85),
            shape: squircleBorder(radius: discRadius),
          ),
          child: Center(child: child),
        );

    final pin = SizedBox(
      width: width,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: width,
            height: size,
            decoration: ShapeDecoration(
              color: background,
              shape: squircleBorder(radius: pinRadius),
              shadows: [
                if (shadow)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (index, tag) in shown.indexed) ...[
                  if (index > 0) SizedBox(width: size * _gapRatio),
                  discOf(Icon(
                    restaurantTagIcon(tag),
                    color: closed ? Colors.grey : restaurantTagColor(tag),
                    size: size * _iconRatio,
                  )),
                ],
                if (multipleCompact)
                  discOf(Icon(_multipleTagsIcon,
                      color: closed ? Colors.grey : kTextPrimary,
                      size: size * _iconRatio)),
                if (hasMore) ...[
                  SizedBox(width: size * _gapRatio),
                  discOf(Icon(Icons.add,
                      color: Colors.grey[700], size: size * _iconRatio)),
                ],
              ],
            ),
          ),
          if (restaurant.isPermanentlyClosed)
            Transform.rotate(
              angle: -math.atan2(size, width),
              child: Container(
                width: math.sqrt(width * width + size * size),
                height: size / 10,
                decoration: ShapeDecoration(
                  color: kSemanticError,
                  shape: squircleBorder(
                    radius: size / 20,
                    side: const BorderSide(color: Colors.white, width: 1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Opacity(
      opacity: (restaurant.validated ? 1 : 0.6) * (dimmed ? 0.5 : 1),
      child: !showRating
          ? pin
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: _ratingHeight(size),
                  child: rating != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: _ratingPadding),
                          decoration: ShapeDecoration(
                            color: Colors.white,
                            shape:
                                squircleBorder(radius: _ratingHeight(size) / 2),
                            shadows: [
                              if (shadow)
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded,
                                  size: size * _ratingFontRatio * 1.1,
                                  color: kAccentYellow),
                              const SizedBox(width: 1),
                              Text(
                                formatRatingAverage(rating!),
                                // Sized to fit the marker, like the icons
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  fontSize: size * _ratingFontRatio,
                                  fontWeight: FontWeight.w700,
                                  color: kTextPrimary,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: _ratingGap),
                pin,
              ],
            ),
    );
  }
}
