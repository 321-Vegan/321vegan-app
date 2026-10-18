import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/app_text_field.dart';
import '../shared/bottom_sheet_shell.dart';
import 'star_rating.dart';

/// What the user entered in [showReviewFormSheet]. [comment] is trimmed,
/// null when left empty.
class ReviewFormResult {
  final int rating;
  final String? comment;

  const ReviewFormResult({required this.rating, this.comment});
}

/// Opens the rate-and-comment form as a bottom sheet and resolves with the
/// entry, or null if dismissed. Sending is left to the caller so the same
/// form serves shop and product reviews.
Future<ReviewFormResult?> showReviewFormSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  int? initialRating,
  String? initialComment,
  String? moderationNotice,
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
    ),
  );
}

class _ReviewFormSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final int? initialRating;
  final String? initialComment;
  final String? moderationNotice;

  const _ReviewFormSheet({
    required this.title,
    this.subtitle,
    this.initialRating,
    this.initialComment,
    this.moderationNotice,
  });

  @override
  State<_ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends State<_ReviewFormSheet> {
  late final TextEditingController _commentController =
      TextEditingController(text: widget.initialComment ?? '');
  late int? _rating = widget.initialRating;

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
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: BottomSheetShell(
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
              SizedBox(height: 48.h),
              Text('Un commentaire ? (facultatif)',
                  style: AppTextStyles.bodyBold15),
              SizedBox(height: 6.h),
              AppTextField(
                controller: _commentController,
                hintText: 'Goût, texture, rapport qualité/prix...',
                textCapitalization: TextCapitalization.sentences,
                maxLength: 1000,
                minLines: 3,
                maxLines: 6,
              ),
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
    );
  }
}
