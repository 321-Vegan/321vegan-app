import 'package:flutter/material.dart';
import '../../models/review_status.dart';
import '../../themes/app_colors.dart';
import '../shared/tag_chip.dart';

/// Moderation status of the current user's own review or rating. Labels
/// stay neutral since they apply to both "avis" and "note".
class RatingStatusChip extends StatelessWidget {
  final ReviewStatus status;

  const RatingStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      ReviewStatus.approved => const TagChip(
          label: 'Approuvé',
          color: kSemanticSuccess,
          backgroundColor: kPrimaryTag,
        ),
      ReviewStatus.pending => const TagChip(
          label: 'En attente',
          color: kAccentYellow,
          backgroundColor: kSecondaryTag,
        ),
      ReviewStatus.rejected => const TagChip(
          label: 'Refusé',
          color: kSemanticError,
        ),
    };
  }
}
