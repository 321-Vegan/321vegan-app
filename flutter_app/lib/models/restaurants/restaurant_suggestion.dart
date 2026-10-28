/// Change of a restaurant proposed by the user (GET
/// /restaurant-suggestions/search), moderated by the team.
class RestaurantSuggestion {
  static const kindEdit = 'EDIT';
  static const kindNoVeganOption = 'NO_VEGAN_OPTION';
  static const kindDuplicate = 'DUPLICATE';

  static const statusPending = 'PENDING';
  static const statusApproved = 'APPROVED';
  static const statusPartiallyApproved = 'PARTIALLY_APPROVED';
  static const statusRejected = 'REJECTED';

  final int id;
  final int restaurantId;
  final String restaurantName;
  final String? restaurantCity;
  final String kind;
  final String status;

  /// Proposed values by restaurant field (edits only).
  final Map<String, dynamic> changes;
  final String? duplicateOfName;
  final String? comment;
  final String? rejectionReason;
  final DateTime? createdAt;

  const RestaurantSuggestion({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    this.restaurantCity,
    required this.kind,
    required this.status,
    this.changes = const {},
    this.duplicateOfName,
    this.comment,
    this.rejectionReason,
    this.createdAt,
  });

  String get kindLabel => switch (kind) {
        kindNoVeganOption => 'Fin des options véganes',
        kindDuplicate => 'Doublon',
        _ => 'Modification',
      };

  factory RestaurantSuggestion.fromJson(Map<String, dynamic> json) {
    final restaurant = json['restaurant'] as Map<String, dynamic>? ?? {};
    final duplicateOf = json['duplicate_of'] as Map<String, dynamic>?;
    return RestaurantSuggestion(
      id: json['id'] as int,
      restaurantId: json['restaurant_id'] as int,
      restaurantName: restaurant['name'] as String? ?? '',
      restaurantCity: restaurant['city'] as String?,
      kind: json['kind'] as String? ?? kindEdit,
      status: json['status'] as String? ?? statusPending,
      changes: (json['changes'] as Map<String, dynamic>?) ?? const {},
      duplicateOfName: duplicateOf?['name'] as String?,
      comment: json['comment'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
