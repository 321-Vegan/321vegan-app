import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import 'bottom_sheet_shell.dart';

enum VeganDateAction { save, delete }

/// Result popped by [VeganSinceDateModal]: either a new date to save, or a
/// request to clear the stored date entirely.
class VeganDateResult {
  final VeganDateAction action;
  final DateTime? date;

  const VeganDateResult.save(this.date) : action = VeganDateAction.save;
  const VeganDateResult.delete()
      : action = VeganDateAction.delete,
        date = null;
}

/// Bottom sheet wheel date picker for "Végane depuis", opened from the
/// Dashboard and Settings. Use with:
/// `showModalBottomSheet<VeganDateResult>(context: ..., isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => VeganSinceDateModal(initialDate: ...))`
class VeganSinceDateModal extends StatefulWidget {
  final DateTime? initialDate;
  final bool showDelete;

  const VeganSinceDateModal({
    super.key,
    this.initialDate,
    this.showDelete = true,
  });

  @override
  State<VeganSinceDateModal> createState() => _VeganSinceDateModalState();
}

class _VeganSinceDateModalState extends State<VeganSinceDateModal> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Végane depuis', style: AppTextStyles.baloo22),
          SizedBox(height: 8.h),
          Text(
            'Indiquez la date à laquelle vous avez commencé à être végane '
            'pour lancer le compteur.',
            style: TextStyle(
              fontSize: 42.sp,
              color: Colors.grey[600],
              height: 1.3,
            ),
          ),
          SizedBox(height: 64.h),
          SizedBox(
            height: 350.h,
            child: CupertinoTheme(
              data: CupertinoTheme.of(context).copyWith(
                textTheme: CupertinoTheme.of(context).textTheme.copyWith(
                      dateTimePickerTextStyle: CupertinoTheme.of(context)
                          .textTheme
                          .dateTimePickerTextStyle
                          .copyWith(fontFamily: 'Baloo2'),
                    ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate,
                minimumYear: 1920,
                maximumDate: DateTime.now(),
                onDateTimeChanged: (date) =>
                    setState(() => _selectedDate = date),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              if (widget.showDelete) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context)
                        .pop(const VeganDateResult.delete()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentYellow,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: squircleBorder(radius: 14.r),
                      elevation: 0,
                    ),
                    child: Text(
                      'Supprimer',
                      style: TextStyle(
                        fontSize: 44.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context)
                      .pop(VeganDateResult.save(_selectedDate)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: squircleBorder(radius: 14.r),
                    elevation: 0,
                  ),
                  child: Text(
                    'Enregistrer',
                    style: TextStyle(
                      fontSize: 44.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
