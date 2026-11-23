import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../helpers/external_links.dart';
import '../../../models/veganuary/veganuary_content.dart';
import '../../../models/veganuary/veganuary_progress.dart';
import '../../../services/veganuary_reminder_service.dart';
import '../../../services/veganuary_service.dart';
import '../../../services/veganuary_sync_service.dart';
import '../../../themes/app_spacing.dart';
import '../../../themes/app_text_styles.dart';
import '../../../widgets/shared/app_background.dart';
import '../../../widgets/shared/animated_reveal.dart';
import '../../../widgets/shared/app_dialog.dart';
import '../../../widgets/shared/empty_state_view.dart';
import '../../../widgets/shared/icon_snack_bar.dart';
import '../../../widgets/shared/push_permission_prompt.dart';
import '../../../widgets/shared/square_icon_button.dart';
import '../../../widgets/veganuary/veganuary_day_node.dart';
import '../../../widgets/veganuary/veganuary_downloads.dart';
import '../../../widgets/veganuary/veganuary_finish_line.dart';
import '../../../widgets/veganuary/veganuary_step_views.dart';
import '../../../widgets/veganuary/veganuary_week_title.dart';
import '../../../widgets/veganuary/veganuary_welcome_modal.dart';
import '../home.dart';
import 'veganuary_day_page.dart';
import 'veganuary_weeks_page.dart';

/// Going on to the next week: the path slides, the header fades.
const Duration _weekChangeDuration = Duration(milliseconds: 900);

/// First visit, once the intro sheet is closed: the coins pop in one after
/// the other, then confetti.
const Duration _introDuration = Duration(milliseconds: 1600);

/// Veganuary tab: the path of the week of the next day to do, one coin per
/// day.
class VeganuaryPage extends StatefulWidget {
  const VeganuaryPage({super.key});

  @override
  State<VeganuaryPage> createState() => _VeganuaryPageState();
}

class _VeganuaryPageState extends State<VeganuaryPage>
    with
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin,
        SingleTickerProviderStateMixin {
  // Kept while on the other tabs: no reload, nor the bubble and ring
  // appearing again, on each return
  @override
  bool get wantKeepAlive => true;

  List<VeganuaryWeek>? _weeks;
  VeganuaryProgress _progress = const VeganuaryProgress();
  Object? _error;

  /// Next day still shown locked while the one just done changes color.
  int? _heldBackDay;

  /// Week on screen, and whether it came after the one before it: the path
  /// then slides on downwards (upwards when going back, after a reset).
  int? _shownWeek;
  bool _movedForward = true;

  /// Number of a week before the current one, gone back to by pulling the
  /// path down from its top; null on the current one.
  int? _browsedWeek;

  /// How far the path is pulled beyond its top (negative) or its bottom,
  /// and whether this drag already changed the week.
  double _pull = 0;
  bool _pullUsed = false;

  /// The coins popping in on the first visit, and on reaching a new week
  /// (at 1 the rest of the time).
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: _introDuration, value: 1);
  final _confetti = ConfettiController(duration: const Duration(seconds: 1));

  /// The week whose coins pop in (a new one reached); all on the first
  /// visit (null).
  int? _introWeek;

  /// The course just finished: what to download appears only once the
  /// trophy has turned yellow.
  bool _holdDownloads = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _showWelcomeOnFirstVisit();
    _refreshContent();
  }

  /// The content edited on the API since last time, shown once downloaded;
  /// likewise the days done on another device (logged in), each as soon as
  /// it's there.
  Future<void> _refreshContent() async {
    Future<void> reloadIf(bool changed) async {
      if (changed && mounted) await _load();
    }

    await Future.wait([
      VeganuaryService.refreshContent().then(reloadIf),
      VeganuarySyncService.sync().then(reloadIf),
    ]);
  }

  /// The intro of the course and its disclaimer, shown once: however it's
  /// closed (its last button, or swiped away), then the path comes in.
  Future<void> _showWelcomeOnFirstVisit() async {
    if (await VeganuaryService.welcomeSeen() || !mounted) return;
    // Wait a bit for the page to be fully displayed
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VeganuaryWelcomeModal(),
    );
    await VeganuaryService.markWelcomeSeen();
    if (mounted) _playIntro();
  }

  /// The coins pop in from the top, then confetti; straight there if the
  /// phone asks for fewer animations.
  Future<void> _playIntro() async {
    if (MediaQuery.of(context).disableAnimations) {
      _intro.value = 1;
      return;
    }
    await _intro.forward(from: 0);
    if (mounted) _confetti.play();
  }

  /// One coin of the intro: grows with a little bounce, in turn. Only on
  /// the week it plays for, and only while it plays: a path built after it
  /// (e.g. the week leaving when the next one comes in) isn't tied to it.
  Widget _popIn(int index, Widget child, {required int week}) {
    final playing = _intro.isAnimating || _intro.value < 1;
    if (!playing || (_introWeek != null && week != _introWeek)) return child;
    final start = min(index * 0.09, 0.6);
    return FadeTransition(
      opacity: _intro.drive(CurveTween(curve: Interval(start, start + 0.15))),
      child: ScaleTransition(
        scale: _intro.drive(CurveTween(
            curve: Interval(start, start + 0.4, curve: Curves.easeOutBack))),
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intro.dispose();
    _confetti.dispose();
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
      // First visit: an empty path behind the intro sheet, filled once closed
      if (!await VeganuaryService.welcomeSeen() && !_intro.isAnimating) {
        _introWeek = null;
        _intro.value = 0;
      }
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

  void _retry() {
    setState(() => _error = null);
    _load();
  }

  /// Week of the next day to do; the last written one when it isn't yet.
  /// While the day just done changes color, still its week (its last day
  /// done shouldn't jump to the next week before turning yellow).
  VeganuaryWeek get _currentWeek {
    final weeks = _weeks!;
    final focusDay =
        _heldBackDay != null ? _heldBackDay! - 1 : _progress.nextDay;
    return weeks.firstWhere(
      (week) => week.days.any((day) => day.number >= focusDay),
      orElse: () => weeks.last,
    );
  }

  /// The week on screen: the current one, unless an earlier one was gone
  /// back to.
  VeganuaryWeek get _week {
    final current = _currentWeek;
    if (_browsedWeek == null || _browsedWeek! >= current.number) return current;
    return _weeks!.firstWhere((week) => week.number == _browsedWeek,
        orElse: () => current);
  }

  /// To the week before ([delta] -1) or back towards the current one (1),
  /// never further than it.
  void _browse(int delta) {
    final target = _week.number + delta;
    if (target > _currentWeek.number ||
        !_weeks!.any((week) => week.number == target)) {
      return;
    }
    setState(
        () => _browsedWeek = target == _currentWeek.number ? null : target);
  }

  /// Pulling the path beyond its top goes to the week before, beyond its
  /// bottom to the one after: the weeks follow each other downwards.
  bool _onPathScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _pull = 0;
      _pullUsed = false;
    } else if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      // Android: the path stops at its ends
      _pull += notification.overscroll;
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      // iOS: it goes beyond them
      final metrics = notification.metrics;
      _pull = metrics.pixels < metrics.minScrollExtent
          ? metrics.pixels - metrics.minScrollExtent
          : metrics.pixels > metrics.maxScrollExtent
              ? metrics.pixels - metrics.maxScrollExtent
              : 0;
    }
    if (!_pullUsed && _pull.abs() > 150.h) {
      _pullUsed = true;
      _browse(_pull < 0 ? -1 : 1);
    }
    return false;
  }

  /// For the app links of a day: the map tab, on a layer.
  ValueChanged<String>? get _mapOpener {
    final home = MyHomePage.of(context);
    return home == null ? null : (layer) => home.goToMapTab(layer: layer);
  }

  /// Likewise: the Scan tab, looking up a barcode if not null.
  ValueChanged<String?>? get _scanOpener {
    final home = MyHomePage.of(context);
    return home == null
        ? null
        : (barcode) => home.goToScanTab(barcode: barcode);
  }

  Future<void> _openDay(VeganuaryDay day) async {
    final state = _progress.stateOf(day.number);
    switch (state) {
      case VeganuaryDayState.locked:
        showInfoSnackBar(context, 'Terminez d\'abord les jours précédents.');
      case VeganuaryDayState.tomorrow:
        showInfoSnackBar(
            context, 'Revenez demain pour le jour ${day.number} !');
      case VeganuaryDayState.available:
      case VeganuaryDayState.completed:
        final done = await VeganuaryDayPage.open(
          context,
          week: _week,
          day: day,
          progress: _progress,
          onOpenMap: _mapOpener,
          onOpenScan: _scanOpener,
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
    final finished = progress.nextDay > VeganuaryService.totalDays;
    final animate = !MediaQuery.of(context).disableAnimations;
    setState(() {
      _progress = progress;
      _heldBackDay = progress.nextDay;
      _browsedWeek = null;
      if (finished && animate) _holdDownloads = true;
    });
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    // A new week reached: its coins pop in as it slides up, like the very
    // first time
    final weekBefore = _week.number;
    var newWeek = false;
    setState(() {
      _heldBackDay = null;
      newWeek = _week.number > weekBefore && animate;
      if (newWeek) {
        _introWeek = _week.number;
        _intro.value = 0;
      }
    });
    if (newWeek) {
      await Future.delayed(_weekChangeDuration * 0.5);
      if (mounted) await _playIntro();
    }
    if (progress.nextDay == 2) await _offerReminder();
    // The last one: the trophy turns yellow (on its own), confetti, then
    // what to keep appears
    if (finished && animate && mounted) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      _confetti.play();
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) setState(() => _holdDownloads = false);
    }
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
            "Pas de rappel les jours où vous l'avez déjà commencé.",
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
            ? _error != null
                ? EmptyStateView(
                    title: 'Pas de connexion',
                    subtitle: 'Le Veganuary se télécharge à la première '
                        'visite. Vérifiez votre connexion, puis réessayez.',
                    buttonLabel: 'Réessayer',
                    onButtonTap: _retry,
                  )
                : const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.pageHorizontal,
                        16.h, AppSpacing.pageHorizontal, 0),
                    // Fades to the next week's while the path slides
                    child: AnimatedSwitcher(
                      duration: _weekChangeDuration,
                      child: KeyedSubtree(
                        key: ValueKey(_week.number),
                        child: _buildHeader(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(child: _buildPathOfWeek()),
                        // Same burst as at the end of a day
                        Align(
                          alignment: Alignment.topCenter,
                          child: IgnorePointer(
                            child: ConfettiWidget(
                              numberOfParticles: 20,
                              maxBlastForce: 50.r,
                              confettiController: _confetti,
                              blastDirectionality:
                                  BlastDirectionality.explosive,
                              shouldLoop: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
          VeganuaryImage(week.illustration!,
              width: 130.w, height: 130.w, fit: BoxFit.contain),
          SizedBox(width: 30.w),
        ],
        Expanded(child: VeganuaryWeekTitle(week: week)),
        SizedBox(width: 30.w),
        // Questions, other vegans: the course's Discord server
        Semantics(
          button: true,
          label: 'Rejoindre le Discord du Veganuary',
          excludeSemantics: true,
          child: SquareIconButton.action(
            onTap: () => openExternalUrl(
                context, Uri.parse(VeganuaryService.discordUrl)),
            shadows: const [],
            child: Image.asset(VeganuaryService.discordLogo, width: 96.w),
          ),
        ),
        SizedBox(width: 24.w),
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

  /// The path, going down to the next week's once a week is done: the old
  /// one leaves by the top while the new one comes up from the bottom.
  Widget _buildPathOfWeek() {
    final week = _week.number;
    if (_shownWeek != null && week != _shownWeek) {
      _movedForward = week > _shownWeek!;
    }
    _shownWeek = week;
    final direction = _movedForward ? 1.0 : -1.0;
    return ClipRect(
      child: AnimatedSwitcher(
        duration: _weekChangeDuration,
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        transitionBuilder: (child, animation) {
          // The week leaving runs its animation backwards (1 to 0)
          final entering = child.key == ValueKey(week);
          return SlideTransition(
            position: Tween(
              begin: Offset(0, entering ? direction : -direction),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
        child: KeyedSubtree(key: ValueKey(week), child: _buildPath()),
      ),
    );
  }

  Widget _buildPath() {
    final week = _week;
    final now = DateTime.now();
    final isLastWeek = week.days.last.number == VeganuaryService.totalDays;

    return NotificationListener<ScrollNotification>(
      onNotification: _onPathScroll,
      child: ListView.builder(
        // Can be pulled to change week even when it all fits on screen
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal, 60.h, AppSpacing.pageHorizontal, 120.h),
        // The last week ends on the trophy
        itemCount: week.days.length + (isLastWeek ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == week.days.length) {
            final daysLeft =
                VeganuaryService.totalDays - _progress.completedAt.length;
            return Padding(
              padding: EdgeInsets.only(top: 60.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _popIn(i, VeganuaryFinishLine(daysLeft: daysLeft),
                      week: week.number),
                  // Once over: everything to keep, at hand
                  AnimatedReveal(
                    visible: daysLeft <= 0 && !_holdDownloads,
                    duration: const Duration(milliseconds: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: AppSpacing.section),
                        Text(
                          'À garder sous la main',
                          style: AppTextStyles.baloo22,
                        ),
                        SizedBox(height: AppSpacing.afterTitle),
                        const VeganuaryDownloads(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
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
                  child: _popIn(
                    i,
                    week: week.number,
                    VeganuaryDayNode(
                      day: day.number,
                      icon: day.icon,
                      state: state,
                      isNext: day.number == _progress.nextDay && !heldBack,
                      dayProgress: _progress.dayProgress(day.number),
                      hasRecipe: day.steps.any((step) => step is RecipeStep),
                      onTap: () => _openDay(day),
                    ),
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
                        // With the coin after it
                        child: _popIn(
                          i + 1,
                          VeganuaryImage(illustration,
                              width: 330.w, fit: BoxFit.contain),
                          week: week.number,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
