import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../helpers/haptic_helper.dart';
import '../../../helpers/preference_helper.dart';
import '../../../models/veganuary/veganuary_content.dart';
import '../../../models/veganuary/veganuary_progress.dart';
import '../../../services/veganuary_reminder_service.dart';
import '../../../services/veganuary_service.dart';
import '../../../themes/app_spacing.dart';
import '../../../widgets/shared/app_background.dart';
import '../../../widgets/shared/app_button.dart';
import '../../../widgets/shared/tag_chip.dart';
import '../../../widgets/veganuary/veganuary_progress_bar.dart';
import '../../../widgets/veganuary/veganuary_step_views.dart';

const String _defaultMythTitle =
    'Quelle idée reçue voudriez-vous apprendre à contrer ?';

/// Idées reçues offered to pick from.
const int _mythChoices = 5;

/// One screen of the day. A myth step makes two: the pick, then the answer.
sealed class _Screen {
  const _Screen();
}

class _QuizScreen extends _Screen {
  final QuizStep quiz;
  const _QuizScreen(this.quiz);
}

class _InfoScreen extends _Screen {
  final VeganuaryInfo info;
  const _InfoScreen(this.info);
}

class _MythPickScreen extends _Screen {
  final String title;
  final List<VeganuaryMyth> pool;
  const _MythPickScreen(this.title, this.pool);
}

class _MythAnswerScreen extends _Screen {
  const _MythAnswerScreen();
}

class _RecipeScreen extends _Screen {
  final RecipeStep recipe;
  const _RecipeScreen(this.recipe);
}

class _DoneScreen extends _Screen {
  const _DoneScreen();
}

class _RecapScreen extends _Screen {
  const _RecapScreen();
}

/// A Veganuary day, page after page, under a progress bar. Done for the
/// first time, it's saved when leaving its last content page, before a
/// "N jour(s) !" page; opened again, it's just reread (with the idée reçue
/// picked that day). Ends with the recap of the day, if it has one.
class VeganuaryDayPage extends StatefulWidget {
  final VeganuaryWeek week;
  final VeganuaryDay day;
  final VeganuaryProgress progress;

  /// Debug: a locked day opened anyway, done like a new one but saving
  /// nothing (see [VeganuaryService.debugUnlockAll]).
  final bool preview;

  const VeganuaryDayPage({
    super.key,
    required this.week,
    required this.day,
    required this.progress,
    this.preview = false,
  });

  /// Resolves to true when the day was done.
  static Future<bool?> open(
    BuildContext context, {
    required VeganuaryWeek week,
    required VeganuaryDay day,
    required VeganuaryProgress progress,
    bool preview = false,
  }) {
    return Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => VeganuaryDayPage(
          week: week, day: day, progress: progress, preview: preview),
    ));
  }

  @override
  State<VeganuaryDayPage> createState() => _VeganuaryDayPageState();
}

class _VeganuaryDayPageState extends State<VeganuaryDayPage> {
  late final List<_Screen> _screens;
  int _index = 0;
  String? _mythId;
  bool _completed = false;

  /// Progress once the day is saved, for the done page.
  VeganuaryProgress? _savedProgress;
  bool _saving = false;

  /// An idée reçue was just tapped: ignores other taps until its answer.
  bool _picking = false;

  /// Choice picked on each quiz page answered, by page index. Saved with
  /// the day left halfway; rereading a done day, the right ones.
  final Map<int, int> _quizAnswers = {};

  /// Grid cards opened, saved with the day left halfway too.
  final Set<GridItem> _seenCards = {};

  /// Vibrates on a quiz answer, like a scan (unless turned off for it).
  bool _haptics = true;

  /// Bursts on reaching the done page.
  final _confettiController =
      ConfettiController(duration: const Duration(seconds: 2));

  bool get _alreadyDone => widget.progress.isCompleted(widget.day.number);

  @override
  void initState() {
    super.initState();
    final picked = widget.progress.pickedMyths[widget.day.number];
    // Forgotten if no longer in the content: its answer can't be shown
    _mythId =
        picked != null && widget.week.mythById(picked) != null ? picked : null;
    _screens = _buildScreens();
    _resume();
    if (_alreadyDone) _revealQuizzes();
    // Started today: no reminder this morning
    if (!_alreadyDone && !widget.preview) {
      VeganuaryReminderService.markDayOpened();
    }
    PreferencesHelper.getHapticFeedbackPref()
        .then((enabled) => _haptics = enabled);
  }

  /// Rereading: each quiz shows its right answer and explanation already.
  void _revealQuizzes() {
    for (int i = 0; i < _screens.length; i++) {
      if (_screens[i] case _QuizScreen(:final quiz)) {
        final right = quiz.choices
            .indexWhere((choice) => choice.result == QuizResult.right);
        if (right != -1) _quizAnswers[i] = right;
      }
    }
  }

  /// Pages before the done one: what the day's progress counts.
  int get _contentScreens {
    final done = _screens.indexWhere((screen) => screen is _DoneScreen);
    return done == -1 ? _screens.length : done;
  }

  /// Back where the day was left, if it was.
  void _resume() {
    final started = widget.progress.started;
    if (_alreadyDone || started == null || started.day != widget.day.number) {
      return;
    }
    // The content may have changed since
    _index = started.screen.clamp(0, _contentScreens - 1);
    if (_screen is _MythAnswerScreen && _mythId == null) _index--;
    // What was done on its pages, if they're still there
    for (final MapEntry(key: screen, value: choice)
        in started.quizAnswers.entries) {
      if (screen >= _screens.length) continue;
      if (_screens[screen] case _QuizScreen(:final quiz)
          when choice < quiz.choices.length) {
        _quizAnswers[screen] = choice;
      }
    }
    _seenCards.addAll([
      for (final screen in _screens)
        if (screen case _InfoScreen(:final info))
          ...info.cardsToOpen
              .where((card) => started.openedCards.contains(card.label)),
    ]);
  }

  /// For the ring on the path, and to resume on [screen] with what was done
  /// so far.
  void _saveStarted(int screen) {
    if (_alreadyDone || widget.preview) return;
    VeganuaryService.saveStarted(
      VeganuaryStartedDay(
        day: widget.day.number,
        screen: screen,
        screens: _contentScreens,
        quizAnswers: Map.of(_quizAnswers),
        openedCards: {for (final card in _seenCards) card.label},
      ),
      mythId: _mythId,
    );
  }

  void _answerQuiz(QuizStep quiz, int choice) {
    setState(() => _quizAnswers[_index] = choice);
    _saveStarted(_index);
    if (!_haptics) return;
    // Like a scan: two pulses when wrong
    if (quiz.choices[choice].result == QuizResult.wrong) {
      HapticHelper.doubleImpact();
    } else {
      HapticHelper.impact();
    }
  }

  void _openedCard(GridItem card) {
    setState(() => _seenCards.add(card));
    _saveStarted(_index);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  List<_Screen> _buildScreens() {
    // Myths picked on the other days of the week are out of the pool
    final pickedElsewhere = {
      for (final entry in widget.progress.pickedMyths.entries)
        if (entry.key != widget.day.number) entry.value,
    };
    return [
      for (final step in widget.day.steps)
        ...switch (step) {
          QuizStep() => [_QuizScreen(step)],
          InfoStep(:final info) => [_InfoScreen(info)],
          RecipeStep() => [_RecipeScreen(step)],
          MythStep(:final title) => _alreadyDone
              // Reread: straight to the answer picked that day, if any
              ? [if (_mythId != null) const _MythAnswerScreen()]
              : () {
                  // A few of those left, picked at random, so the list
                  // stays short and changes from day to day
                  final pool = (widget.week.myths
                          .where((myth) => !pickedElsewhere.contains(myth.id))
                          .toList()
                        ..shuffle())
                      .take(_mythChoices)
                      .toList();
                  return pool.isEmpty
                      ? <_Screen>[]
                      : [
                          _MythPickScreen(title ?? _defaultMythTitle, pool),
                          const _MythAnswerScreen(),
                        ];
                }(),
        },
      if (!_alreadyDone) const _DoneScreen(),
      if (widget.day.recap.isNotEmpty ||
          (widget.day.steps.any((step) => step is MythStep) &&
              widget.week.myths.any((myth) => myth.recap != null)))
        const _RecapScreen(),
    ];
  }

  /// The day's cards, then the one of the idée reçue picked.
  List<VeganuaryRecapCard> get _recapCards {
    final mythRecap =
        _mythId == null ? null : widget.week.mythById(_mythId!)?.recap;
    return [...widget.day.recap, if (mythRecap != null) mythRecap];
  }

  _Screen get _screen => _screens[_index];

  bool get _isLast => _index == _screens.length - 1;

  /// Back on the path: true once the day was done (not in a preview, which
  /// saved nothing to celebrate).
  void _close() => Navigator.of(context).pop(_completed && !widget.preview);

  Future<void> _next() async {
    if (_isLast) {
      _close();
      return;
    }
    if (_screens[_index + 1] is _DoneScreen) {
      if (widget.preview) {
        // As if done, for the done page only
        _savedProgress =
            widget.progress.withCompleted(widget.day.number, mythId: _mythId);
        _completed = true;
        _confettiController.play();
        setState(() => _index++);
        return;
      }
      setState(() => _saving = true);
      _savedProgress = await VeganuaryService.completeDay(widget.day.number,
          mythId: _mythId);
      _completed = true;
      // The next reminders are for the next day (and maybe from tomorrow)
      VeganuaryReminderService.reschedule();
      if (!mounted) return;
      setState(() => _saving = false);
      _confettiController.play();
    } else {
      _saveStarted(_index + 1);
    }
    setState(() => _index++);
  }

  void _back() {
    // Once saved (done or recap page), going back would only reopen the
    // celebration or pages already read
    if (_index == 0 || _completed) {
      _close();
    } else {
      setState(() => _index--);
    }
  }

  /// Tapping an idée reçue is enough: its answer comes right after, once
  /// the choice has shown.
  Future<void> _pickMyth(String id) async {
    if (_picking) return;
    setState(() {
      _mythId = id;
      _picking = true;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _picking = false;
    await _next();
  }

  String get _buttonLabel => switch (_screen) {
        _DoneScreen() when !_isLast => 'Continuer',
        _DoneScreen() || _RecapScreen() => 'Terminer',
        _ when _isLast => 'Fermer',
        _ => 'On continue !',
      };

  /// The idée reçue pick goes on by itself; a quiz, once answered.
  bool get _showButton => switch (_screen) {
        _MythPickScreen() => false,
        _QuizScreen() => _quizAnswers.containsKey(_index),
        _ => true,
      };

  /// Grid cards of the page still to open before going on (none when
  /// rereading): the button stays grey until then.
  int get _cardsLeft => switch (_screen) {
        _InfoScreen(:final info) when !_alreadyDone =>
          info.cardsToOpen.where((card) => !_seenCards.contains(card)).length,
        _ => 0,
      };

  void _remindCards() {
    final left = _cardsLeft;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(left == 1
            ? 'Touchez la dernière carte pour la découvrir avant de continuer.'
            : 'Touchez les $left cartes restantes pour les découvrir avant '
                'de continuer.'),
      ));
  }

  /// What kind of page it is, right above its title (icons of the path's
  /// days).
  Widget _tag(String label, IconData icon) => TagChip(
        label: label,
        icon: icon,
        color: Theme.of(context).colorScheme.primary,
      );

  Widget _buildScreen(_Screen screen) {
    return switch (screen) {
      _QuizScreen(:final quiz) => VeganuaryQuizView(
          quiz: quiz,
          selected: _quizAnswers[_index],
          reviewing: _alreadyDone,
          onSelected: (choice) => _answerQuiz(quiz, choice),
          tag: _tag('Quiz', FontAwesomeIcons.circleQuestion),
        ),
      _InfoScreen(:final info) => VeganuaryInfoView(
          info: info,
          seenCards: _seenCards,
          onCardSeen: _openedCard,
          tag: _tag('Info', FontAwesomeIcons.scroll),
        ),
      _RecipeScreen(:final recipe) => VeganuaryRecipeView(
          recipe: recipe,
          tag: _tag('Recette', FontAwesomeIcons.bowlFood),
        ),
      _MythPickScreen(:final title, :final pool) => VeganuaryMythPicker(
          title: title,
          myths: pool,
          selectedId: _mythId,
          onSelected: _pickMyth,
          tag: _tag('Idée reçue', FontAwesomeIcons.comments),
        ),
      _MythAnswerScreen() => VeganuaryInfoView(
          info: widget.week.mythById(_mythId!)!.answer,
          tag: _tag('Idée reçue', FontAwesomeIcons.comments),
        ),
      _DoneScreen() => VeganuaryDoneView(
          day: widget.day.number,
          weekDays: [for (final day in widget.week.days) day.number],
          completedDays: _savedProgress!.completedAt.keys.toSet(),
          nextAvailable: _savedProgress!.stateOf(widget.day.number + 1) ==
              VeganuaryDayState.available,
          badgeImage: widget.week.badgeImage,
        ),
      _RecapScreen() => VeganuaryRecapView(
          cards: _recapCards,
          tag: _tag('Récap', FontAwesomeIcons.listCheck),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(children: [
            SafeArea(
              child: Column(
                children: [
                  // Hidden on the done page (kept in the layout so the
                  // pages don't jump)
                  Visibility(
                    visible: _screen is! _DoneScreen,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          12.w, 12.h, AppSpacing.pageHorizontal + 60.w, 0),
                      child: Row(
                        children: [
                          // Stops for now: the day resumes where it was
                          // left (saved on each page)
                          IconButton(
                            onPressed: _close,
                            tooltip: 'Retour au parcours',
                            icon: Icon(Icons.home_outlined,
                                color: Colors.grey[700], size: 72.sp),
                          ),
                          IconButton(
                            onPressed: _back,
                            tooltip: 'Retour',
                            icon: Icon(Icons.arrow_back,
                                color: Colors.grey[700], size: 72.sp),
                          ),
                          SizedBox(width: 24.w),
                          Expanded(
                            child: VeganuaryProgressBar(
                                value: (_index + 1) / _screens.length),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                                  begin: const Offset(0.05, 0),
                                  end: Offset.zero)
                              .animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_index),
                        child: _buildScreen(_screen),
                      ),
                    ),
                  ),
                  Visibility(
                    visible: _showButton,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(AppSpacing.pageHorizontal,
                          24.h, AppSpacing.pageHorizontal, 24.h),
                      child: SizedBox(
                        width: double.infinity,
                        // Grey like a disabled one, but still says why
                        child: AppButton(
                          label: _buttonLabel,
                          onPressed: _cardsLeft > 0 ? _remindCards : _next,
                          isLoading: _saving,
                          backgroundColor:
                              _cardsLeft > 0 ? Colors.grey.shade500 : primary,
                          disabledBackgroundColor: primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Same burst as the vegan anniversary (home.dart)
            Align(
              alignment: Alignment.topCenter,
              child: IgnorePointer(
                child: ConfettiWidget(
                  numberOfParticles: 20,
                  maxBlastForce: 50.r,
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
