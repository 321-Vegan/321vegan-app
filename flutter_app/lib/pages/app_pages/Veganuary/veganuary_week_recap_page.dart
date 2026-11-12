import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../models/veganuary/veganuary_content.dart';
import '../../../models/veganuary/veganuary_progress.dart';
import '../../../themes/app_spacing.dart';
import '../../../themes/app_text_styles.dart';
import '../../../widgets/shared/app_background.dart';
import '../../../widgets/veganuary/veganuary_step_views.dart';

/// Fiches récap' of a week done: the recap cards of each of its days, with
/// the idée reçue picked that day.
class VeganuaryWeekRecapPage extends StatelessWidget {
  final VeganuaryWeek week;
  final VeganuaryProgress progress;

  const VeganuaryWeekRecapPage({
    super.key,
    required this.week,
    required this.progress,
  });

  static Future<void> open(
      BuildContext context, VeganuaryWeek week, VeganuaryProgress progress) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VeganuaryWeekRecapPage(week: week, progress: progress),
    ));
  }

  List<VeganuaryRecapCard> _cardsOf(VeganuaryDay day) {
    final mythId = progress.pickedMyths[day.number];
    final mythRecap = mythId == null ? null : week.mythById(mythId)?.recap;
    return [...day.recap, if (mythRecap != null) mythRecap];
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Semaine ${week.number}', style: AppTextStyles.baloo22),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 8.h,
                AppSpacing.pageHorizontal, 32.h),
            children: [
              for (final day in week.days)
                if (_cardsOf(day).isNotEmpty) ...[
                  Text('Jour ${day.number}', style: AppTextStyles.baloo22),
                  SizedBox(height: AppSpacing.afterTitle),
                  for (final card in _cardsOf(day)) ...[
                    VeganuaryRecapCardView(card: card),
                    SizedBox(height: AppSpacing.item),
                  ],
                  SizedBox(height: AppSpacing.section),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
