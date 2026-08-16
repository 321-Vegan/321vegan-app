import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../models/b12_reminder_settings.dart';
import '../../../services/b12_reminder_service.dart';
import '../../../themes/app_colors.dart';
import '../../../themes/app_spacing.dart';
import '../../../themes/app_text_styles.dart';
import '../../../widgets/shared/bottom_sheet_shell.dart';
import '../../../widgets/shared/info_box.dart';

/// Streak/monthly/total counts and a per-day calendar — the B12 tracking
/// view reached from the "Historique B12" row in Paramètres. Shown with:
/// `showModalBottomSheet(context: ..., isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const B12HistorySheet())`
class B12HistorySheet extends StatefulWidget {
  const B12HistorySheet({super.key});

  @override
  State<B12HistorySheet> createState() => _B12HistorySheetState();
}

class _B12HistorySheetState extends State<B12HistorySheet> {
  bool _isLoading = true;
  Set<DateTime> _historyDays = {};
  int _historyCount = 0;
  int _monthCount = 0;
  int _streak = 0;
  DateTime? _nextIntake;
  B12ReminderSettings _settings = B12ReminderSettings();
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
    _load();
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final history = await B12ReminderService.getB12IntakeHistory();
    final streak = await B12ReminderService.getB12Streak();
    final next = await B12ReminderService.getNextNotificationTime();
    final settings = await B12ReminderService.getSettings();
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _historyDays = history.map(_dayOnly).toSet();
      _historyCount = history.length;
      _monthCount = history
          .where((d) => d.year == now.year && d.month == now.month)
          .length;
      _streak = streak;
      _nextIntake = next;
      _settings = settings;
      _isLoading = false;
    });
  }

  void _goToPreviousMonth() {
    setState(() => _visibleMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1));
  }

  bool get _canGoToNextMonth {
    final now = DateTime.now();
    return _visibleMonth.isBefore(DateTime(now.year, now.month, 1));
  }

  void _goToNextMonth() {
    if (!_canGoToNextMonth) return;
    setState(() => _visibleMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1));
  }

  String _capitalizeFr(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  /// The next expected intake day, only meaningful while reminders are on
  /// — see [_buildDayCell]'s ring marker and the "Prochaine prise" banner.
  DateTime? get _nextIntakeDay =>
      _settings.enabled && _nextIntake != null ? _dayOnly(_nextIntake!) : null;

  @override
  Widget build(BuildContext context) {
    return BottomSheetShell(
      child: _isLoading
          ? SizedBox(
              height: 400.h,
              child: const Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Historique de votre B12', style: AppTextStyles.baloo26),
                  SizedBox(height: 8.h),
                  Text(
                    'Suivez l\'historique de vos prises de B12.',
                    style: TextStyle(fontSize: 40.sp, color: Colors.grey[600]),
                  ),
                  SizedBox(height: AppSpacing.section),
                  if (_settings.enabled && _nextIntake != null) ...[
                    InfoBox(
                      iconAsset: 'lib/assets/images/icons/info-circle.webp',
                      text: 'Prochaine prise : '
                          '${_capitalizeFr(B12ReminderService.relativeDayLabel(_nextIntake!))}.',
                    ),
                    SizedBox(height: AppSpacing.section),
                  ],
                  _buildMonthNav(),
                  SizedBox(height: AppSpacing.item),
                  _buildCalendarGrid(),
                  SizedBox(height: AppSpacing.section),
                  _buildStatsRow(),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthNav() {
    final label = _capitalizeFr(
      DateFormat('MMMM yyyy', 'fr_FR').format(_visibleMonth),
    );
    return Row(
      children: [
        GestureDetector(
          onTap: _goToPreviousMonth,
          child: Icon(Icons.arrow_back, color: Colors.grey[500], size: 56.sp),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.baloo22,
          ),
        ),
        GestureDetector(
          onTap: _canGoToNextMonth ? _goToNextMonth : null,
          child: Icon(
            Icons.arrow_forward,
            color: _canGoToNextMonth ? Colors.grey[500] : Colors.grey[300],
            size: 56.sp,
          ),
        ),
      ],
    );
  }

  static const _weekdayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  Widget _buildWeekdayHeader() {
    return Row(
      children: _weekdayLabels
          .map(
            (label) => Expanded(
              child: Center(
                child: Text(
                  label,
                  style:
                      AppTextStyles.bodyMedium13.copyWith(color: kTextPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth =
        DateUtils.getDaysInMonth(_visibleMonth.year, _visibleMonth.month);
    // DateTime.weekday is 1 (Monday) .. 7 (Sunday), which already matches
    // the Monday-first column order of [_weekdayLabels].
    final leadingBlanks = _visibleMonth.weekday - 1;
    final today = _dayOnly(DateTime.now());
    return Column(
      children: [
        _buildWeekdayHeader(),
        SizedBox(height: 8.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leadingBlanks + daysInMonth,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 140.h,
          ),
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = index - leadingBlanks + 1;
            final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
            return _buildDayCell(day, date, today);
          },
        ),
      ],
    );
  }

  Widget _buildDayCell(int day, DateTime date, DateTime today) {
    final taken = _historyDays.contains(date);
    final isToday = date == today;
    final isNextIntake = !taken && _nextIntakeDay == date;
    final status = !date.isAfter(today)
        ? _buildDayStatus(date, taken, isToday: isToday)
        : null;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60.w,
          height: 60.w,
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: AppTextStyles.bodyMedium13.copyWith(
              fontWeight: isToday ? FontWeight.bold : const FontWeight(400),
              color: isToday ? primary : kTextPrimary,
            ),
          ),
        ),
        SizedBox(height: 10.h),
        if (isNextIntake)
          _buildNextIntakeBadge(context, child: status)
        else if (status != null)
          status,
      ],
    );
  }

  /// Green check (taken); red cross (due under the current reminder rhythm
  /// but not taken — only for days strictly before today, since today
  /// isn't "missed" until the day is over); a neutral yellow dash (not
  /// taken, and the rhythm never required this day) — except today, which
  /// only ever shows taken or nothing, never a "not needed" mark, since the
  /// day isn't over yet.
  Widget? _buildDayStatus(DateTime date, bool taken,
      {bool isToday = false, double size = 56}) {
    if (taken) {
      return Image.asset(
        'lib/assets/images/icons/solid-check.webp',
        width: size.w,
        height: size.w,
        color: kSemanticSuccess,
        colorBlendMode: BlendMode.srcIn,
      );
    }
    if (isToday) return null;
    final due = B12ReminderService.isDueDay(date, _settings);
    if (due) {
      return Image.asset(
        'lib/assets/images/icons/solid-close.webp',
        width: size.w,
        height: size.w,
        color: kSemanticError,
        colorBlendMode: BlendMode.srcIn,
      );
    }
    return Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        color: Colors.grey[500],
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.remove, color: Colors.white, size: size.sp * 0.55),
    );
  }

  /// Bell icon marking the next day the user is expected to take their B12
  /// (see [_nextIntakeDay]). On a future day, with no status yet, it's just
  /// the bell; an overdue day still shows its red cross as a small badge on
  /// the bell so that information isn't lost.
  Widget _buildNextIntakeBadge(BuildContext context, {Widget? child}) {
    return SizedBox(
      width: 64.w,
      height: 64.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.notifications_rounded, size: 64.w, color: kAccentYellow),
          if (child != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: SizedBox(width: 26.w, height: 26.w, child: child),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _statColumn('lib/assets/images/icons/award-line.webp',
              '$_streak', 'd\'affilée'),
        ),
        Expanded(
          child: _statColumn('lib/assets/images/icons/calendar.webp',
              '$_monthCount', 'ce mois-ci'),
        ),
        Expanded(
          child: _statColumn('lib/assets/images/icons/clipboard-check.webp',
              '$_historyCount', 'au total'),
        ),
      ],
    );
  }

  Widget _statColumn(String iconAsset, String value, String label) {
    return Column(
      children: [
        Image.asset(
          iconAsset,
          width: 100.w,
          height: 100.w,
          color: Colors.grey[600],
          colorBlendMode: BlendMode.srcIn,
        ),
        SizedBox(height: 8.h),
        Text(
          value,
          style:
              AppTextStyles.baloo22.copyWith(fontWeight: const FontWeight(600)),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyMedium13
              .copyWith(fontWeight: const FontWeight(400)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
