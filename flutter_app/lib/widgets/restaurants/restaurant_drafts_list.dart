import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../helpers/restaurant_drafts.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/app_card.dart';
import '../shared/app_dialog.dart';
import '../shared/bottom_sheet_shell.dart';

/// A restaurant creation draft in a list: its name (or "Lieu sans nom"),
/// city and date, with a button to delete it.
class RestaurantDraftCard extends StatelessWidget {
  final RestaurantDraft draft;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const RestaurantDraftCard({
    super.key,
    required this.draft,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final date = DateFormat.yMMMd('fr_FR').format(draft.updatedAt);
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        radius: 36.r,
        padding: EdgeInsets.all(30.w),
        child: Row(
          children: [
            Container(
              width: 110.w,
              height: 110.w,
              decoration: ShapeDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: squircleBorder(radius: 30.r),
              ),
              child: Icon(Icons.edit_note, color: primary, size: 60.sp),
            ),
            SizedBox(width: 30.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(draft.name ?? 'Lieu sans nom',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.baloo17),
                  Text(
                    [if (draft.city != null) draft.city!, 'Brouillon du $date']
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLight15,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Supprimer le brouillon',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: kSemanticError),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks before deleting [draft] for good, then deletes it. True once done.
Future<bool> confirmDeleteRestaurantDraft(
    BuildContext context, RestaurantDraft draft) async {
  final confirmed = await AppDialog.confirm(
    context,
    title: 'Supprimer le brouillon ?',
    message: '« ${draft.name ?? 'Lieu sans nom'} » et ses photos seront '
        'effacés de ce téléphone.',
    confirmLabel: 'Supprimer',
    destructive: true,
  );
  if (!confirmed) return false;
  await RestaurantDrafts.delete(draft.id);
  return true;
}

/// What the user chose when adding a restaurant with drafts saved: go on
/// with [draft], or start a new one (null).
typedef RestaurantDraftChoice = ({RestaurantDraft? draft});

/// Offers to go on with a saved draft or to start a new restaurant. Null
/// when dismissed.
Future<RestaurantDraftChoice?> showRestaurantDraftPicker(
    BuildContext context, List<RestaurantDraft> drafts) {
  return showModalBottomSheet<RestaurantDraftChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DraftPicker(drafts: drafts),
  );
}

class _DraftPicker extends StatefulWidget {
  final List<RestaurantDraft> drafts;

  const _DraftPicker({required this.drafts});

  @override
  State<_DraftPicker> createState() => _DraftPickerState();
}

class _DraftPickerState extends State<_DraftPicker> {
  late final List<RestaurantDraft> _drafts = [...widget.drafts];

  Future<void> _delete(RestaurantDraft draft) async {
    if (!await confirmDeleteRestaurantDraft(context, draft) || !mounted) {
      return;
    }
    setState(() => _drafts.remove(draft));
    // Nothing left to resume: straight to a new one
    if (_drafts.isEmpty) Navigator.of(context).pop((draft: null));
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetShell(
      child: Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reprendre un brouillon ?', style: AppTextStyles.baloo22),
              SizedBox(height: 6.h),
              Text(
                'Ces lieux sont en cours d\'ajout sur ce téléphone.',
                style: AppTextStyles.bodyRegular13
                    .copyWith(color: Colors.grey[600]),
              ),
              SizedBox(height: 36.h),
              for (final draft in _drafts) ...[
                RestaurantDraftCard(
                  draft: draft,
                  onTap: () => Navigator.of(context).pop((draft: draft)),
                  onDelete: () => _delete(draft),
                ),
                SizedBox(height: 18.h),
              ],
              SizedBox(height: 18.h),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Ajouter un nouveau lieu',
                  icon: Icons.add_location_alt_outlined,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  onPressed: () => Navigator.of(context).pop((draft: null)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
