/// A notification sent by the API to the current user (e.g. a response to
/// one of their signalements), as returned by GET /me/notifications.
class AppNotification {
  /// Type of a response to one of the user's error reports.
  static const String errorReportHandled = 'error_report.handled';

  /// Types of a moderation outcome for a place the user created.
  static const String restaurantValidated = 'restaurant.validated';
  static const String restaurantRejected = 'restaurant.rejected';

  /// A user sent the user one of their restaurant selections.
  static const String selectionReceived = 'restaurant_selection.received';

  /// Types of a moderation outcome for an edit suggestion the user sent.
  static const String restaurantSuggestionApproved =
      'restaurant_suggestion.approved';
  static const String restaurantSuggestionRejected =
      'restaurant_suggestion.rejected';

  final int id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;
  final DateTime? readAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.payload = const {},
    this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'])
          : const {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      readAt:
          json['read_at'] != null ? DateTime.tryParse(json['read_at']) : null,
    );
  }

  AppNotification markedRead() => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        payload: payload,
        createdAt: createdAt,
        readAt: readAt ?? DateTime.now(),
      );
}
