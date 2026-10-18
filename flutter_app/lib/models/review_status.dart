/// Moderation state of a shop review or product rating. A product rating
/// without comment is approved straight away by the backend; anything with
/// a comment waits for a moderator.
enum ReviewStatus {
  pending,
  approved,
  rejected;

  static ReviewStatus fromApi(String? value) => switch (value?.toUpperCase()) {
        'APPROVED' => ReviewStatus.approved,
        'REJECTED' => ReviewStatus.rejected,
        _ => ReviewStatus.pending,
      };
}
