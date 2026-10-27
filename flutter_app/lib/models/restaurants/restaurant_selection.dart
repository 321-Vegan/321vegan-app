import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'restaurant.dart';

/// Status of a selection sent to the user, mirrors the API share status.
class SelectionShareStatus {
  SelectionShareStatus._();

  static const pending = 'PENDING';
  static const accepted = 'ACCEPTED';

  /// A public selection the user took then removed.
  static const declined = 'DECLINED';
}

/// Orders of the public selections, mirrors the API `sort` values.
class SelectionSort {
  SelectionSort._();

  static const recent = 'recent';
  static const popular = 'popular';
}

/// A restaurant of a selection, with why it is recommended.
class RestaurantSelectionItem {
  final Restaurant restaurant;
  final String? note;

  /// The selection author's review of it, if any: its rating (1-5), and
  /// its id to load it whole.
  final int? authorRating;
  final int? authorReviewId;

  const RestaurantSelectionItem({
    required this.restaurant,
    this.note,
    this.authorRating,
    this.authorReviewId,
  });

  RestaurantSelectionItem copyWith({String? note}) => RestaurantSelectionItem(
      restaurant: restaurant,
      note: note,
      authorRating: authorRating,
      authorReviewId: authorReviewId);

  factory RestaurantSelectionItem.fromJson(Map<String, dynamic> json) =>
      RestaurantSelectionItem(
        restaurant:
            Restaurant.fromJson(json['restaurant'] as Map<String, dynamic>),
        note: json['note'] as String?,
        authorRating: json['author_rating'] as int?,
        authorReviewId: json['author_review_id'] as int?,
      );
}

/// Restaurants a user recommends, in their order, with a title and a
/// description; it can be sent to other users (by email), who accept it to
/// see it with their saved places. A public one is listed for everyone,
/// who can take it without it being sent (for good: it can't be made
/// private again). Lists (GET /restaurant-selections/mine, /received,
/// /public) don't carry the [items], only the [restaurantIds].
class RestaurantSelection {
  final int id;
  final String title;
  final String? description;
  final int ownerId;
  final String ownerNickname;
  final bool isOwner;
  final bool isPublic;
  final DateTime? publishedAt;

  /// Image chosen by the owner, shown instead of [coverPhotos].
  final String? coverPath;

  /// The restaurants the user can see, in order.
  final List<int> restaurantIds;

  /// Featured photos of the first restaurants having one (up to 4).
  final List<RestaurantPhoto> coverPhotos;

  /// Sent to the user, or a public one they took (or removed):
  /// [SelectionShareStatus] value; null for the owner, or a public one the
  /// user doesn't have.
  final String? shareStatus;

  /// Sent to the user: false until they opened their received selections.
  final bool isSeen;

  /// The owner's, or anyone's for a public one: how many users accepted or
  /// took it (have it with their saved places); null otherwise.
  final int? acceptedCount;
  final List<RestaurantSelectionItem> items;

  const RestaurantSelection({
    required this.id,
    required this.title,
    this.description,
    this.ownerId = 0,
    required this.ownerNickname,
    required this.isOwner,
    this.isPublic = false,
    this.publishedAt,
    this.coverPath,
    this.restaurantIds = const [],
    this.coverPhotos = const [],
    this.shareStatus,
    this.isSeen = true,
    this.acceptedCount,
    this.items = const [],
  });

  bool get isPending => shareStatus == SelectionShareStatus.pending;

  /// With the user's saved places: accepted, or taken when public.
  bool get isAccepted => shareStatus == SelectionShareStatus.accepted;

  /// A public selection of someone else the user can add to their places.
  bool get canTake => isPublic && !isOwner && !isAccepted && !isPending;

  String? get coverUrl => coverPath == null
      ? null
      : '${dotenv.env['S3_STORAGE_URL'] ?? ''}/$coverPath';

  /// "3 lieux"
  String get countLabel => switch (restaurantIds.length) {
        0 => 'Aucun lieu',
        1 => '1 lieu',
        final n => '$n lieux',
      };

  /// Under the title: who made it for a recipient. "De Camille · 3 lieux",
  /// "3 lieux" (the owner's [acceptedCount] is shown beside, as an icon).
  String get subtitle =>
      isOwner ? countLabel : 'De $ownerNickname · $countLabel';

  /// Who made it, even for the owner (e.g. among the public selections).
  /// "De Camille · 3 lieux"
  String get subtitleWithOwner => 'De $ownerNickname · $countLabel';

  factory RestaurantSelection.fromJson(Map<String, dynamic> json) =>
      RestaurantSelection(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        ownerId: json['owner_id'] as int? ?? 0,
        ownerNickname: json['owner_nickname'] as String? ?? '',
        isOwner: json['is_owner'] as bool? ?? false,
        isPublic: json['is_public'] as bool? ?? false,
        publishedAt: json['published_at'] is String
            ? DateTime.tryParse(json['published_at'] as String)
            : null,
        coverPath: json['cover_path'] as String?,
        restaurantIds:
            (json['restaurant_ids'] as List<dynamic>? ?? []).cast<int>(),
        coverPhotos: (json['cover_photos'] as List<dynamic>? ?? [])
            .map((e) => RestaurantPhoto.fromJson(e as Map<String, dynamic>))
            .toList(),
        shareStatus: json['share_status'] as String?,
        isSeen: json['is_seen'] as bool? ?? true,
        acceptedCount: json['accepted_count'] as int?,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) =>
                RestaurantSelectionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
