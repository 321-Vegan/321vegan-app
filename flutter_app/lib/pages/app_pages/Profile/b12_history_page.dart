import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../services/b12_reminder_service.dart';
import '../../../themes/app_colors.dart';
import '../../../themes/app_shapes.dart';
import '../../../themes/app_spacing.dart';
import '../../../themes/app_text_styles.dart';
import '../../../widgets/b12/next_reminder_banner.dart';
import '../../../widgets/shared/app_background.dart';
import '../../../widgets/shared/app_button.dart';
import '../../../widgets/shared/app_card.dart';

/// Streak, monthly/total counts and a month-grouped intake list — the B12
/// tracking view that lived on the pre-redesign profile page, now reached
/// from the "Historique B12" row in Paramètres.
class B12HistoryPage extends StatefulWidget {
  const B12HistoryPage({super.key});

  @override
  State<B12HistoryPage> createState() => _B12HistoryPageState();
}

class _B12HistoryPageState extends State<B12HistoryPage> {
  bool _isLoading = true;
  List<DateTime> _history = [];
  int _streak = 0;
  DateTime? _nextIntake;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final history = await B12ReminderService.getB12IntakeHistory();
    final streak = await B12ReminderService.getB12Streak();
    final next = await B12ReminderService.getNextExpectedIntakeDate();
    if (!mounted) return;
    setState(() {
      _history = history;
      _streak = streak;
      _nextIntake = next;
      _isLoading = false;
    });
  }

  bool get _takenToday {
    if (_history.isEmpty) return false;
    final today = DateTime.now();
    final last = _history.first;
    return last.year == today.year &&
        last.month == today.month &&
        last.day == today.day;
  }

  Future<void> _markAsTaken() async {
    await B12ReminderService.recordB12Intake();
    await _load();
  }

  String _capitalizeFr(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthCount = _history
        .where((d) => d.year == now.year && d.month == now.month)
        .length;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Historique B12',
            style: AppTextStyles.baloo22,
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: SafeArea(
          top: false,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 32.h),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _statTile('🔥', '$_streak', 'jours d\'affilée',
                              highlighted: _streak >= 2),
                        ),
                        SizedBox(width: AppSpacing.item),
                        Expanded(
                          child: _statTile('📅', '$monthCount', 'ce mois-ci'),
                        ),
                        SizedBox(width: AppSpacing.item),
                        Expanded(
                          child:
                              _statTile('✅', '${_history.length}', 'au total'),
                        ),
                      ],
                    ),
                    if (_nextIntake != null) ...[
                      SizedBox(height: AppSpacing.item),
                      B12NextReminderBanner(
                        date: _nextIntake!,
                        label: 'Prochaine prise',
                      ),
                    ],
                    SizedBox(height: AppSpacing.item),
                    _buildMarkTakenButton(context),
                    SizedBox(height: AppSpacing.section),
                    if (_history.isEmpty)
                      _buildEmptyState()
                    else
                      _buildHistoryList(today),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _statTile(String emoji, String value, String label,
      {bool highlighted = false}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 8.w),
      decoration: ShapeDecoration(
        color: highlighted
            ? kAccentYellow.withValues(alpha: 0.15)
            : const Color(0xFFF7F6F2),
        shape: squircleBorder(
          radius: 24.r,
          side: BorderSide(
            color: highlighted ? kAccentYellow : kBorderDefault,
          ),
        ),
      ),
      child: Column(
        children: [
          Text('$emoji $value',
              style: TextStyle(
                  fontSize: 44.sp,
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary)),
          SizedBox(height: 4.h),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 28.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildMarkTakenButton(BuildContext context) {
    if (_takenToday) {
      final primary = Theme.of(context).colorScheme.primary;
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 18.h),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(100.r),
          border: Border.all(color: primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 40.sp, color: primary),
            SizedBox(width: 10.w),
            Text(
              'B12 prise aujourd\'hui',
              style: TextStyle(
                fontSize: 38.sp,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: AppButton(
        label: 'Marquer comme prise aujourd\'hui',
        icon: Icons.check,
        backgroundColor: Theme.of(context).colorScheme.primary,
        onPressed: _markAsTaken,
      ),
    );
  }

  Widget _buildEmptyState() {
    return AppCard(
      child: Column(
        children: [
          Text('💊', style: TextStyle(fontSize: 80.sp)),
          SizedBox(height: 16.h),
          Text(
            'Aucune prise enregistrée',
            style: AppTextStyles.baloo22,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            'Marquez votre première prise pour commencer le suivi !',
            style: TextStyle(fontSize: 38.sp, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(DateTime today) {
    final monthFormatter = DateFormat('MMMM yyyy', 'fr_FR');
    final items = <Widget>[];
    String? currentMonth;
    for (final date in _history) {
      final month = _capitalizeFr(monthFormatter.format(date));
      if (month != currentMonth) {
        currentMonth = month;
        items.add(_buildMonthHeader(month, isFirst: items.isEmpty));
      }
      items.add(_buildHistoryTile(date, today));
    }
    return Column(children: items);
  }

  Widget _buildMonthHeader(String month, {bool isFirst = false}) {
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 20.h, bottom: 12.h),
      child: Text(
        month.toUpperCase(),
        style: TextStyle(
          fontSize: 30.sp,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  Widget _buildHistoryTile(DateTime date, DateTime today) {
    final dayFormatter = DateFormat('EEEE d MMMM', 'fr_FR');
    final daysAgo = B12ReminderService.calendarDaysBetween(date, today);
    final isToday = daysAgo == 0;
    final isYesterday = daysAgo == 1;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: ShapeDecoration(
        color:
            isToday ? primary.withValues(alpha: 0.08) : const Color(0xFFF7F6F2),
        shape: squircleBorder(
          radius: 24.r,
          side: BorderSide(
            color: isToday ? primary.withValues(alpha: 0.3) : kBorderDefault,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 90.w,
            height: 90.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? primary : primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 38.sp,
                fontWeight: FontWeight.bold,
                color: isToday ? Colors.white : primary,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              _capitalizeFr(dayFormatter.format(date)),
              style: TextStyle(
                fontSize: 38.sp,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
              ),
            ),
          ),
          if (isToday || isYesterday)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: ShapeDecoration(
                color: primary.withValues(alpha: 0.12),
                shape: squircleBorder(radius: 20.r),
              ),
              child: Text(
                isToday ? 'Aujourd\'hui' : 'Hier',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
