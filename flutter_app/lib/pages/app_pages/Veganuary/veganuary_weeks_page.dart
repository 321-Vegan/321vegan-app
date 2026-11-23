import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../models/veganuary/veganuary_content.dart';
import '../../../models/veganuary/veganuary_progress.dart';
import '../../../services/veganuary_reminder_service.dart';
import '../../../services/veganuary_service.dart';
import '../../../themes/app_colors.dart';
import '../../../themes/app_shapes.dart';
import '../../../themes/app_spacing.dart';
import '../../../themes/app_text_styles.dart';
import '../../../widgets/shared/app_background.dart';
import '../../../widgets/settings/settings_toggle_tile.dart';
import '../../../widgets/shared/app_button.dart';
import '../../../widgets/shared/icon_snack_bar.dart';
import '../../../widgets/shared/push_permission_prompt.dart';
import '../../../widgets/veganuary/saturation_filter.dart';
import '../../../widgets/veganuary/veganuary_downloads.dart';
import '../../../widgets/veganuary/veganuary_progress_bar.dart';
import '../../../widgets/veganuary/veganuary_recipes_section.dart';
import '../../../widgets/veganuary/veganuary_step_views.dart';
import '../../../widgets/veganuary/veganuary_week_title.dart';
import 'veganuary_week_recap_page.dart';

enum _WeekState { completed, current, locked }

/// The weeks of the Veganuary (from the path's "i" button): done ones lead
/// to their fiches récap', the current one shows its progress, the next
/// ones are locked.
class VeganuaryWeeksPage extends StatefulWidget {
  final List<VeganuaryWeek> weeks;
  final VeganuaryProgress progress;

  const VeganuaryWeeksPage({
    super.key,
    required this.weeks,
    required this.progress,
  });

  static Future<void> open(
    BuildContext context, {
    required List<VeganuaryWeek> weeks,
    required VeganuaryProgress progress,
  }) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VeganuaryWeeksPage(weeks: weeks, progress: progress),
    ));
  }

  @override
  State<VeganuaryWeeksPage> createState() => _VeganuaryWeeksPageState();
}

class _VeganuaryWeeksPageState extends State<VeganuaryWeeksPage> {
  List<VeganuaryWeek> get weeks => widget.weeks;

  /// Reloaded after a debug button (the path reloads once back on it).
  late VeganuaryProgress progress = widget.progress;

  /// A debug button: the page stays open, up to date, and says it's done.
  Future<void> _debug(Future<void> Function() action, String done) async {
    await action();
    final updated = await VeganuaryService.loadProgress();
    if (!mounted) return;
    setState(() => progress = updated);
    showInfoSnackBar(context, done);
  }

  _WeekState _stateOf(VeganuaryWeek week) {
    if (progress.isWeekDone(week)) return _WeekState.completed;
    // Days are done in order: the first week not done is the current one
    final current = weeks.firstWhere((w) => !progress.isWeekDone(w));
    return week == current ? _WeekState.current : _WeekState.locked;
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Veganuary', style: AppTextStyles.baloo22),
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
              const _ReminderToggle(),
              SizedBox(height: AppSpacing.section),
              for (final week in weeks) ...[
                _WeekCard(
                  week: week,
                  state: _stateOf(week),
                  progress: progress,
                ),
                SizedBox(height: AppSpacing.item),
              ],
              // The course done: its idées reçues to keep, as a PDF
              if (progress.completedAt.length >=
                  VeganuaryService.totalDays) ...[
                SizedBox(height: AppSpacing.section),
                const VeganuaryDownloadCard(
                    download: VeganuaryDownload.answers),
              ],
              SizedBox(height: AppSpacing.section),
              VeganuaryRecipesSection(weeks: weeks, progress: progress),
              if (kDebugMode) ...[
                SizedBox(height: AppSpacing.section),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 24.w,
                  children: [
                    TextButton(
                      onPressed: () => _debug(() async {
                        await VeganuaryService.shiftOneDayBack();
                        await VeganuaryReminderService.reschedule();
                      }, 'Passé au lendemain'),
                      child: const Text('Debug : passer au lendemain'),
                    ),
                    TextButton(
                      onPressed: () => _debug(() async {
                        await VeganuaryService.reset();
                        // The reminder is offered again at the end of day 1
                        await VeganuaryReminderService.reset();
                      }, 'Parcours réinitialisé'),
                      child: const Text('Debug : réinitialiser'),
                    ),
                    TextButton(
                      onPressed: () => _debug(() async {
                        await VeganuaryService.debugCompleteNextDay();
                        await VeganuaryReminderService.reschedule();
                      }, 'Jour terminé'),
                      child: const Text('Debug : terminer le jour'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await VeganuaryReminderService.showTestSoon();
                        if (!context.mounted) return;
                        showInfoSnackBar(
                            context,
                            'Rappel dans 10 secondes : '
                            "passez l'app en arrière-plan");
                      },
                      child: const Text('Debug : rappel dans 10 s'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The morning reminder on or off (offered at the end of day 1).
class _ReminderToggle extends StatefulWidget {
  const _ReminderToggle();

  @override
  State<_ReminderToggle> createState() => _ReminderToggleState();
}

class _ReminderToggleState extends State<_ReminderToggle> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    VeganuaryReminderService.isEnabled().then((enabled) {
      if (mounted) setState(() => _enabled = enabled ?? false);
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    if (!value) {
      await VeganuaryReminderService.disable();
      return;
    }
    final granted = await VeganuaryReminderService.enable();
    if (granted || !mounted) return;
    setState(() => _enabled = false);
    showPushBlockedSnackBar(context);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsToggleTile(
      title: 'Rappel chaque matin à 10h',
      subtitle: 'Sauf les jours où vous avez déjà commencé',
      value: _enabled,
      onChanged: _toggle,
    );
  }
}

class _WeekCard extends StatelessWidget {
  final VeganuaryWeek week;
  final _WeekState state;
  final VeganuaryProgress progress;

  const _WeekCard({
    required this.week,
    required this.state,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final locked = state == _WeekState.locked;
    final daysDone =
        week.days.where((day) => progress.isCompleted(day.number)).length;

    return Container(
      padding: EdgeInsets.all(39.w),
      decoration: ShapeDecoration(
        color: locked ? Colors.white.withValues(alpha: 0.5) : Colors.white,
        shape: squircleBorder(
          radius: 60.r,
          side: const BorderSide(color: kBorderDefault, width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Done weeks fold up to their title and fiches récap'
          if (state != _WeekState.completed && week.coverImage != null) ...[
            AspectRatio(
              aspectRatio: 2.1,
              child: ClipSmoothRect(
                radius: squircleRadius(36.r),
                child: locked
                    ? Opacity(
                        opacity: 0.5,
                        child: ColorFiltered(
                          colorFilter: saturationFilter(0),
                          child: VeganuaryImage(week.coverImage!),
                        ),
                      )
                    : VeganuaryImage(week.coverImage!),
              ),
            ),
            SizedBox(height: AppSpacing.afterTitle),
          ],
          Row(
            children: [
              Expanded(
                child: VeganuaryWeekTitle(week: week, faded: locked),
              ),
              if (state == _WeekState.completed)
                Container(
                  width: 78.w,
                  height: 78.w,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: kAccentYellow,
                  ),
                  child: Icon(Icons.check_rounded,
                      color: Colors.white, size: 54.sp),
                )
              else if (locked)
                Icon(Icons.lock_rounded, color: Colors.grey[400], size: 72.sp),
            ],
          ),
          SizedBox(height: AppSpacing.afterTitle),
          if (state == _WeekState.completed)
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: "Voir les fiches récap'",
                compact: true,
                backgroundColor: kAccentYellow,
                onPressed: () =>
                    VeganuaryWeekRecapPage.open(context, week, progress),
              ),
            )
          else
            VeganuaryProgressBar(
              value: daysDone / week.days.length,
              trackColor: kBackgroundGradientBottom,
            ),
        ],
      ),
    );
  }
}
