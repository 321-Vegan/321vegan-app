import 'restaurant.dart';

/// Status of a selection sent to the user, mirrors the API share status.
class SelectionShareStatus {
  SelectionShareStatus._();

  static const pending = 'PENDING';
  static const accepted = 'ACCEPTED';
}

/// A restaurant of a selection, with why it is recommended.
class RestaurantSelectionItem {
  final Restaurant restaurant;
  final String? note;

  const RestaurantSelectionItem({required this.restaurant, this.note});

  RestaurantSelectionItem copyWith({String? note}) =>
      RestaurantSelectionItem(restaurant: restaurant, note: note);

  factory RestaurantSelectionItem.fromJson(Map<String, dynamic> json) =>
      RestaurantSelectionItem(
        restaurant:
            Restaurant.fromJson(json['restaurant'] as Map<String, dynamic>),
        note: json['note'] as String?,
      );
}

/// Restaurants a user recommends, in their order, with a title and a
/// description; it can be sent to other users (by email), who accept it to
/// see it with their saved places. Lists (GET /restaurant-selections/mine,
/// /received) don't carry the [items], only the [restaurantIds].
class RestaurantSelection {
  final int id;
  final String title;
  final String? description;
  final String ownerNickname;
  final bool isOwner;

  /// The restaurants the user can see, in order.
  final List<int> restaurantIds;

  /// Featured photos of the first restaurants having one (up to 4).
  final List<RestaurantPhoto> coverPhotos;

  /// Sent to the user: [SelectionShareStatus] value; null for the owner.
  final String? shareStatus;

  /// Sent to the user: false until they opened their received selections.
  final bool isSeen;
  final List<RestaurantSelectionItem> items;

  const RestaurantSelection({
    required this.id,
    required this.title,
    this.description,
    required this.ownerNickname,
    required this.isOwner,
    this.restaurantIds = const [],
    this.coverPhotos = const [],
    this.shareStatus,
    this.isSeen = true,
    this.items = const [],
  });

  bool get isPending => shareStatus == SelectionShareStatus.pending;

  /// "3 lieux"
  String get countLabel => switch (restaurantIds.length) {
        0 => 'Aucun lieu',
        1 => '1 lieu',
        final n => '$n lieux',
      };

  factory RestaurantSelection.fromJson(Map<String, dynamic> json) =>
      RestaurantSelection(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        ownerNickname: json['owner_nickname'] as String? ?? '',
        isOwner: json['is_owner'] as bool? ?? false,
        restaurantIds:
            (json['restaurant_ids'] as List<dynamic>? ?? []).cast<int>(),
        coverPhotos: (json['cover_photos'] as List<dynamic>? ?? [])
            .map((e) => RestaurantPhoto.fromJson(e as Map<String, dynamic>))
            .toList(),
        shareStatus: json['share_status'] as String?,
        isSeen: json['is_seen'] as bool? ?? true,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) =>
                RestaurantSelectionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
