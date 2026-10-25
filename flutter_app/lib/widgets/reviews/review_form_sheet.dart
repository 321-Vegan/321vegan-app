import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/app_text_field.dart';
import '../shared/bottom_sheet_shell.dart';
import '../shared/picked_photos_row.dart';
import 'star_rating.dart';

/// What the user entered in [showReviewFormSheet]. [comment] is trimmed,
/// null when left empty.
class ReviewFormResult {
  final int rating;
  final String? comment;

  /// Detailed ratings by field, null when left empty (restaurants only).
  final Map<String, int?> criteria;

  /// New photos to upload with the review (restaurants only).
  final List<File> photos;

  const ReviewFormResult({
    required this.rating,
    this.comment,
    this.criteria = const {},
    this.photos = const [],
  });
}

/// Entries whose sending failed, by review target (e.g. `product:<ean>`),
/// so the form comes back filled even when reopened from a new sheet. In
/// memory only: lost when the app restarts.
class ReviewDrafts {
  ReviewDrafts._();

  static final Map<String, ReviewFormResult> _drafts = {};

  static ReviewFormResult? get(String key) => _drafts[key];
  static void save(String key, ReviewFormResult entry) => _drafts[key] = entry;
  static void clear(String key) => _drafts.remove(key);
}

/// Opens the rate-and-comment form as a bottom sheet and resolves with the
/// entry, or null if dismissed. Sending is left to the caller so the same
/// form serves shop, product and restaurant reviews.
///
/// [criteria] adds optional detailed ratings as (field, label) pairs (the
/// [lockedCriteria] fields keep their initial value, greyed out), and
/// [maxPhotos] a photo picker (restaurant reviews).
Future<ReviewFormResult?> showReviewFormSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  int? initialRating,
  String? initialComment,
  String? moderationNotice,
  List<(String, String)> criteria = const [],
  Map<String, int?> initialCriteria = const {},
  Set<String> lockedCriteria = const {},
  int maxPhotos = 0,
  List<File> initialPhotos = const [],
  String commentHint = 'Goût, texture, rapport qualité/prix...',
}) {
  return showModalBottomSheet<ReviewFormResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReviewFormSheet(
      title: title,
      subtitle: subtitle,
      initialRating: initialRating,
      initialComment: initialComment,
      moderationNotice: moderationNotice,
      criteria: criteria,
      initialCriteria: initialCriteria,
      lockedCriteria: lockedCriteria,
      maxPhotos: maxPhotos,
      initialPhotos: initialPhotos,
      commentHint: commentHint,
    ),
  );
}

class _ReviewFormSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final int? initialRating;
  final String? initialComment;
  final String? moderationNotice;
  final List<(String, String)> criteria;
  final Map<String, int?> initialCriteria;
  final Set<String> lockedCriteria;
  final int maxPhotos;
  final List<File> initialPhotos;
  final String commentHint;

  const _ReviewFormSheet({
    required this.title,
    this.subtitle,
    this.initialRating,
    this.initialComment,
    this.moderationNotice,
    required this.criteria,
    required this.initialCriteria,
    required this.lockedCriteria,
    required this.maxPhotos,
    required this.initialPhotos,
    required this.commentHint,
  });

  @override
  State<_ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends State<_ReviewFormSheet> {
  late final TextEditingController _commentController =
      TextEditingController(text: widget.initialComment ?? '');
  late int? _rating = widget.initialRating;
  late final Map<String, int?> _criteria = {...widget.initialCriteria};
  late List<File> _photos = [...widget.initialPhotos];
  // Locked values were not entered by the user: no reason to unfold
  late bool _criteriaExpanded = widget.initialCriteria.entries
      .any((e) => e.value != null && !widget.lockedCriteria.contains(e.key));

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    final rating = _rating;
    if (rating == null) return;
    final comment = _commentController.text.trim();
    Navigator.of(context).pop(ReviewFormResult(
      rating: rating,
      comment: comment.isEmpty ? null : comment,
      criteria: {
        for (final (field, _) in widget.criteria) field: _criteria[field],
      },
      photos: _photos,
    ));
  }

  Widget _buildCriteria() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _criteriaExpanded = !_criteriaExpanded),
          child: Row(
            children: [
              Expanded(
                child: Text('Détailler ma note (facultatif)',
                    style: AppTextStyles.bodyBold15),
              ),
              Icon(
                _criteriaExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
        if (_criteriaExpanded)
          for (final (field, label) in widget.criteria)
            Builder(builder: (context) {
              final locked = widget.lockedCriteria.contains(field);
              return Padding(
                padding: EdgeInsets.only(top: 24.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: AppTextStyles.bodyRegular15
                            .copyWith(color: locked ? Colors.grey[500] : null),
                      ),
                    ),
                    // Tapping the current value again clears it
                    for (var star = 1; star <= 5; star++)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: locked
                            ? null
                            : () => setState(() => _criteria[field] =
                                _criteria[field] == star ? null : star),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6.w),
                          child: Icon(
                            (_criteria[field] ?? 0) >= star
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 72.sp,
                            color: locked ? Colors.grey[400] : kAccentYellow,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: BottomSheetShell(
        child: Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: AppTextStyles.baloo22),
                if (widget.subtitle != null) ...[
                  SizedBox(height: 8.h),
                  Text(
                    widget.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyRegular13
                        .copyWith(color: Colors.grey[500]),
                  ),
                ],
                SizedBox(height: 48.h),
                StarRatingInput(
                  value: _rating,
                  onChanged: (value) => setState(() => _rating = value),
                ),
                if (widget.criteria.isNotEmpty) ...[
                  SizedBox(height: 48.h),
                  _buildCriteria(),
                ],
                SizedBox(height: 48.h),
                Text('Un commentaire ? (facultatif)',
                    style: AppTextStyles.bodyBold15),
                SizedBox(height: 6.h),
                AppTextField(
                  controller: _commentController,
                  hintText: widget.commentHint,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 1000,
                  minLines: 3,
                  maxLines: 6,
                ),
                if (widget.maxPhotos > 0) ...[
                  SizedBox(height: 24.h),
                  Text('Des photos ? (facultatif)',
                      style: AppTextStyles.bodyBold15),
                  SizedBox(height: 18.h),
                  PickedPhotosRow(
                    photos: _photos,
                    max: widget.maxPhotos,
                    onChanged: (photos) => setState(() => _photos = photos),
                  ),
                ],
                if (widget.moderationNotice != null) ...[
                  SizedBox(height: 12.h),
                  Text(
                    widget.moderationNotice!,
                    style: AppTextStyles.bodyRegular13
                        .copyWith(color: Colors.grey[500]),
                  ),
                ],
                SizedBox(height: 48.h),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Annuler',
                        backgroundColor: kAccentYellow,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: AppButton(
                        label: 'Envoyer',
                        backgroundColor: kSemanticSuccess,
                        onPressed: _rating == null ? null : _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
