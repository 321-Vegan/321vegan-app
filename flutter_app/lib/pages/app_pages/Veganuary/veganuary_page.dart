import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../models/veganuary/veganuary_content.dart';
import '../../../models/veganuary/veganuary_progress.dart';
import '../../../services/veganuary_reminder_service.dart';
import '../../../services/veganuary_service.dart';
import '../../../themes/app_spacing.dart';
import '../../../themes/app_text_styles.dart';
import '../../../widgets/shared/app_background.dart';
import '../../../widgets/shared/app_dialog.dart';
import '../../../widgets/shared/push_permission_prompt.dart';
import '../../../widgets/shared/square_icon_button.dart';
import '../../../widgets/veganuary/veganuary_day_node.dart';
import '../../../widgets/veganuary/veganuary_week_title.dart';
import '../../../widgets/veganuary/veganuary_welcome_modal.dart';
import 'veganuary_day_page.dart';
import 'veganuary_weeks_page.dart';

/// Veganuary tab: the path of the week of the next day to do, one coin per
/// day.
class VeganuaryPage extends StatefulWidget {
  const VeganuaryPage({super.key});

  @override
  State<VeganuaryPage> createState() => _VeganuaryPageState();
}

class _VeganuaryPageState extends State<VeganuaryPage>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  // Kept while on the other tabs: no reload, nor the bubble and ring
  // appearing again, on each return
  @override
  bool get wantKeepAlive => true;

  List<VeganuaryWeek>? _weeks;
  VeganuaryProgress _progress = const VeganuaryProgress();
  Object? _error;

  /// Next day still shown locked while the one just done changes color.
  int? _heldBackDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _showWelcomeOnFirstVisit();
  }

  /// The intro of the course and its disclaimer, until closed with its last
  /// button.
  Future<void> _showWelcomeOnFirstVisit() async {
    if (await VeganuaryService.welcomeSeen() || !mounted) return;
    // Wait a bit for the page to be fully displayed
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    final seen = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VeganuaryWelcomeModal(),
    );
    if (seen == true) await VeganuaryService.markWelcomeSeen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // "Demain" may have become today while in the background
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final weeks = await VeganuaryService.loadWeeks();
      final progress = await VeganuaryService.loadProgress();
      if (mounted) {
        setState(() {
          _weeks = weeks;
          _progress = progress;
        });
      }
    } catch (e) {
      debugPrint('Veganuary content failed to load: $e');
      if (mounted) setState(() => _error = e);
    }
  }

  /// Week of the next day to do; the last written one when it isn't yet.
  /// While the day just done changes color, still its week (its last day
  /// done shouldn't jump to the next week before turning yellow).
  VeganuaryWeek get _week {
    final weeks = _weeks!;
    final focusDay =
        _heldBackDay != null ? _heldBackDay! - 1 : _progress.nextDay;
    return weeks.firstWhere(
      (week) => week.days.any((day) => day.number >= focusDay),
      orElse: () => weeks.last,
    );
  }

  Future<void> _openDay(VeganuaryDay day) async {
    final state = _progress.stateOf(day.number);
    switch (state) {
      case VeganuaryDayState.locked:
        _showSnackBar('Terminez d\'abord les jours précédents.');
      case VeganuaryDayState.tomorrow:
        _showSnackBar('Revenez demain pour le jour ${day.number} !');
      case VeganuaryDayState.available:
      case VeganuaryDayState.completed:
        final done = await VeganuaryDayPage.open(
          context,
          week: _week,
          day: day,
          progress: _progress,
        );
        if (done == true) {
          await _celebrate();
        } else {
          // Left halfway: the ring shows how far
          await _load();
        }
    }
  }

  /// Back on the path after a day done: it turns yellow, then the next one
  /// opens (bubble and ring moving on to it).
  Future<void> _celebrate() async {
    // Lets the day page's closing transition end first
    await Future.delayed(const Duration(milliseconds: 350));
    final progress = await VeganuaryService.loadProgress();
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _heldBackDay = progress.nextDay;
    });
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _heldBackDay = null);
    if (progress.nextDay == 2) await _offerReminder();
  }

  /// At the end of day 1 (once only): the morning reminder, off unless
  /// asked for. Can be changed later from the list of weeks.
  Future<void> _offerReminder() async {
    if (await VeganuaryReminderService.isEnabled() != null) return;
    // Once the bubble has moved on to day 2
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        image: 'lib/assets/images/characters/avocado.webp',
        title: 'Un petit rappel chaque matin ?',
        message: 'On vous prévient à 10h quand un nouveau jour vous attend. '
            'Pas de rappel les jours où vous l’avez déjà commencé.',
        primaryLabel: 'Oui, je veux bien',
        onPrimary: () => Navigator.of(ctx).pop(true),
        secondaryLabel: 'Non merci',
        onSecondary: () => Navigator.of(ctx).pop(false),
      ),
    );
    if (accepted != true) {
      await VeganuaryReminderService.disable();
      return;
    }
    final granted = await VeganuaryReminderService.enable();
    if (!granted && mounted) showPushBlockedSnackBar(context);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openWeeks() async {
    await VeganuaryWeeksPage.open(context, weeks: _weeks!, progress: _progress);
    // Its debug buttons change the progress (the reset shows the intro again)
    await _load();
    await _showWelcomeOnFirstVisit();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: _weeks == null
            ? Center(
                child: _error != null
                    ? Text('Le contenu n\'a pas pu être chargé.',
                        style: AppTextStyles.bodyRegular15)
                    : const CircularProgressIndicator(),
              )
            : Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.pageHorizontal,
                        16.h, AppSpacing.pageHorizontal, 0),
                    child: _buildHeader(),
                  ),
                  Expanded(child: _buildPath()),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final week = _week;
    return Row(
      children: [
        if (week.illustration != null) ...[
          Image.asset(week.illustration!, width: 130.w, height: 130.w),
          SizedBox(width: 30.w),
        ],
        Expanded(child: VeganuaryWeekTitle(week: week)),
        SizedBox(width: 30.w),
        Semantics(
          button: true,
          label: 'Voir les semaines du Veganuary',
          excludeSemantics: true,
          child: SquareIconButton.action(
            onTap: _openWeeks,
            icon: Icons.info_outline,
            shadows: const [],
          ),
        ),
      ],
    );
  }

  Widget _buildPath() {
    final week = _week;
    final now = DateTime.now();

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal, 60.h, AppSpacing.pageHorizontal, 120.h),
      itemCount: week.days.length,
      itemBuilder: (context, i) {
        final day = week.days[i];
        final heldBack = day.number == _heldBackDay;
        final state = heldBack
            ? VeganuaryDayState.locked
            : _progress.stateOf(day.number, now: now);
        // Winding path: center, left, left, center, right, right...
        final bend = sin(i * pi / 3);
        // One illustration per bend, from its first day, on the other side
        final illustrationIndex = i ~/ 3;
        final illustration =
            i % 3 == 1 && illustrationIndex < week.pathIllustrations.length
                ? week.pathIllustrations[illustrationIndex]
                : null;
        return Padding(
          padding: EdgeInsets.only(bottom: 54.h),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment(-bend * 0.5, 0),
                child: VeganuaryDayNode(
                  day: day.number,
                  icon: day.icon,
                  state: state,
                  isNext: day.number == _progress.nextDay && !heldBack,
                  dayProgress: _progress.dayProgress(day.number),
                  onTap: () => _openDay(day),
                ),
              ),
              if (illustration != null)
                Positioned(
                  // Down into the bend, beside the next day too
                  top: 60.h,
                  left: bend > 0 ? null : 0,
                  right: bend > 0 ? 0 : null,
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: Image.asset(illustration, width: 330.w),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
