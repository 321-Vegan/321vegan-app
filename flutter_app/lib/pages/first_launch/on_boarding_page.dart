import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/models/b12_reminder_settings.dart';
import 'package:vegan_app/services/b12_reminder_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:intl/intl.dart';
import '../app_pages/home.dart';
import '../../widgets/auth/register_form.dart';
import '../../widgets/auth/login_form.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _introKey = GlobalKey<IntroductionScreenState>();
  DateTime? selectedDate;
  final TextEditingController _dateController = TextEditingController();
  bool _wantsB12Setup = false;

  // Answers of the B12 setup questions; null/empty until the user answers.
  ReminderFrequency? _b12Frequency;
  List<int> _b12Days = [];
  TimeOfDay? _b12Time;
  bool _b12Saving = false;

  static const _dayLabels = {
    1: 'Lun',
    2: 'Mar',
    3: 'Mer',
    4: 'Jeu',
    5: 'Ven',
    6: 'Sam',
    7: 'Dim',
  };

  @override
  void initState() {
    super.initState();
    _loadSelectedDate();
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadSelectedDate() async {
    selectedDate = await PreferencesHelper.getSelectedDateFromPrefs();
    if (selectedDate != null) {
      _dateController.text = DateFormat.yMMMd('fr_FR').format(selectedDate!);
    }
    setState(() {});
  }

  Future<void> _onIntroEnd(BuildContext context) async {
    final navigator = Navigator.of(context);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (!mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const MyHomePage()),
    );
  }

  void _nextIntroPage() {
    // Let the rebuild insert/remove conditional pages before scrolling.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _introKey.currentState?.next();
    });
  }

  void _answerB12Question(bool wantsSetup) {
    setState(() => _wantsB12Setup = wantsSetup);
    _nextIntroPage();
  }

  void _selectB12Frequency(ReminderFrequency frequency) {
    setState(() {
      _b12Frequency = frequency;
      if (frequency == ReminderFrequency.twiceWeekly) {
        // Let the user pick their two days from scratch.
        _b12Days = [];
      } else if (_b12Days.length > 1) {
        _b12Days = [_b12Days.first];
      }
    });
    _nextIntroPage();
  }

  void _selectB12Day(int day) {
    if (_b12Frequency == ReminderFrequency.twiceWeekly) {
      setState(() {
        if (_b12Days.contains(day)) {
          _b12Days.remove(day);
        } else {
          if (_b12Days.length >= 2) _b12Days.removeAt(0);
          _b12Days.add(day);
        }
      });
      if (_b12Days.length == 2) _nextIntroPage();
    } else {
      setState(() => _b12Days = [day]);
      _nextIntroPage();
    }
  }

  Future<void> _selectB12Time(TimeOfDay time) async {
    setState(() => _b12Time = time);
    await _activateB12Reminder();
  }

  Future<void> _pickCustomB12Time() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _b12Time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      await _selectB12Time(picked);
    }
  }

  Future<void> _activateB12Reminder() async {
    if (_b12Saving) return;
    setState(() => _b12Saving = true);

    // The flow guarantees answered questions, but swiping can bypass pages:
    // fall back to sensible defaults rather than failing silently.
    final frequency = _b12Frequency ?? ReminderFrequency.weekly;
    final time = _b12Time ?? const TimeOfDay(hour: 9, minute: 0);
    final isTwiceWeekly = frequency == ReminderFrequency.twiceWeekly;
    final days = List.of(_b12Days);
    if (isTwiceWeekly) {
      for (final day in [1, 4, 2, 5]) {
        if (days.length >= 2) break;
        if (!days.contains(day)) days.add(day);
      }
    } else if (days.isEmpty) {
      days.add(1);
    }

    await B12ReminderService.scheduleReminder(B12ReminderSettings(
      enabled: true,
      frequency: frequency,
      hour: time.hour,
      minute: time.minute,
      dayOfWeek: isTwiceWeekly ? null : days.first,
      daysOfWeek: isTwiceWeekly ? days : null,
    ));
    // scheduleReminder doesn't persist if notification permission was denied,
    // so re-read the saved state instead of assuming success.
    final saved = await B12ReminderService.getSettings();
    if (!mounted) return;
    setState(() => _b12Saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved.enabled
            ? 'Rappel B12 activé : ${saved.getDescription()}'
            : "Les notifications sont désactivées. Vous pourrez activer le rappel plus tard depuis votre profil."),
        backgroundColor: saved.enabled ? kSemanticSuccess : null,
      ),
    );
    _nextIntroPage();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        _dateController.text = DateFormat.yMMMd('fr_FR').format(selectedDate!);
      });
      await PreferencesHelper.addSelectedDateToPrefs(selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The package's SafeArea sits outside its Scaffold, so without this the
    // status bar / home indicator insets show as black bars.
    return ColoredBox(
      color: Colors.white,
      child: IntroductionScreen(
        key: _introKey,
        pages: [
          PageViewModel(
            title: "Bienvenue sur \n321 Vegan !",
            body:
                "Cette appli vous aide à facilement savoir si un produit est végane ou non. Fini de se prendre la tête devant une liste d'ingrédients incompréhensible !",
            image: Image.asset('lib/assets/app_icon.png', height: 175),
            decoration: getPageDecoration(),
          ),
          PageViewModel(
            title: "Scannez les produits",
            body:
                "Scannez un code-barres pour savoir instantanément si un produit est végane. Vérifiez aussi les additifs et les cosmétiques, même sans connexion !",
            image: Image.asset('lib/assets/intro/scan-1.webp'),
            decoration: getPageDecorationWithImage(),
          ),
          PageViewModel(
            title: "Explorez la carte",
            body:
                "Trouvez les produits véganes référencés dans les boutiques autour de vous.",
            image: Image.asset('lib/assets/intro/map.webp'),
            decoration: getPageDecorationWithImage(),
          ),
          PageViewModel(
            title: "Profitez de réductions",
            body:
                "Bénéficiez de codes de promotion chez nos partenaires véganes.",
            image: Image.asset('lib/assets/intro/partners.webp'),
            decoration: getPageDecorationWithImage(),
          ),
          PageViewModel(
            title: "Suivez votre impact",
            body:
                "Constatez l'impact de vos choix sur l'environnement et les animaux.",
            image: Image.asset('lib/assets/intro/home-1.webp'),
            decoration: getPageDecorationWithImage(),
          ),
          PageViewModel(
            title: "N'oubliez plus votre B12",
            bodyWidget: Column(
              children: [
                Text('💊💚', style: TextStyle(fontSize: 150.sp)),
                SizedBox(height: 24.h),
                Text(
                  "La vitamine B12 est indispensable quand on est végane. Souhaitez-vous configurer un rappel pour ne plus l'oublier ?",
                  style: TextStyle(fontSize: 50.sp),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _answerB12Question(true),
                    icon: Icon(Icons.notifications_active, size: 48.sp),
                    label: Text(
                      "Oui, configurer un rappel",
                      style: TextStyle(fontSize: 45.sp),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      shape: squircleBorder(radius: 12.r),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                TextButton(
                  onPressed: () => _answerB12Question(false),
                  child: Text(
                    "Non merci",
                    style: TextStyle(
                      fontSize: 42.sp,
                      color: Colors.grey[500],
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.grey[500],
                    ),
                  ),
                ),
              ],
            ),
            decoration: PageDecoration(
              titleTextStyle:
                  TextStyle(fontSize: 80.sp, fontWeight: FontWeight.bold),
              bodyAlignment: Alignment.center,
              pageColor: Colors.white,
              contentMargin: EdgeInsets.symmetric(horizontal: 16.w),
            ),
          ),
          if (_wantsB12Setup) ...[
            PageViewModel(
              title: "À quelle fréquence prenez-vous votre B12 ?",
              bodyWidget: _buildB12FrequencyChoices(),
              decoration: _getB12QuestionDecoration(),
            ),
            if (_b12Frequency != ReminderFrequency.daily)
              PageViewModel(
                title: _b12Frequency == ReminderFrequency.twiceWeekly
                    ? "Quels jours ?"
                    : "Quel jour ?",
                bodyWidget: _buildB12DayChoices(),
                decoration: _getB12QuestionDecoration(),
              ),
            PageViewModel(
              title: "À quelle heure ?",
              bodyWidget: _buildB12TimeChoices(),
              decoration: _getB12QuestionDecoration(),
            ),
          ],
          PageViewModel(
            title: "",
            bodyWidget: Column(
              children: [
                Icon(Icons.person_add_alt_1, size: 60.sp, color: Colors.green),
                SizedBox(height: 10.h),
                Text(
                  "Créez votre compte",
                  style:
                      TextStyle(fontSize: 80.sp, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                Text(
                  "Créez un compte pour profiter de toutes les fonctionnalités de l'application",
                  style: TextStyle(fontSize: 45.sp, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32.h),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Végane depuis quand ? (optionnel)",
                    style: TextStyle(fontSize: 40.sp, color: Colors.grey[700]),
                    textAlign: TextAlign.left,
                  ),
                ),
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _dateController,
                  decoration: InputDecoration(
                    labelText: 'Sélectionnez une date',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  readOnly: true,
                  onTap: _pickDate,
                ),
                SizedBox(height: 24.h),
                RegisterForm(
                  showTitle: false,
                  onRegisterSuccess: () => _onIntroEnd(context),
                  onSwitchToLogin: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => ClipSmoothRect(
                        radius: const SmoothBorderRadius.only(
                          topLeft: SmoothRadius(
                              cornerRadius: 20, cornerSmoothing: kCornerSmoothing),
                          topRight: SmoothRadius(
                              cornerRadius: 20, cornerSmoothing: kCornerSmoothing),
                        ),
                        child: Scaffold(
                          backgroundColor: Colors.white,
                          body: Center(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                                left: 16,
                                right: 16,
                                top: 24,
                              ),
                              child: LoginForm(
                                onLoginSuccess: () {
                                  Navigator.pop(ctx);
                                  _onIntroEnd(context);
                                },
                                onSwitchToRegister: () => Navigator.pop(ctx),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Button to pass
                TextButton.icon(
                  onPressed: () => _onIntroEnd(context),
                  icon: Icon(Icons.arrow_forward,
                      size: 40.sp, color: Colors.grey[500]),
                  label: Text(
                    "Continuer sans compte",
                    style: TextStyle(
                      fontSize: 40.sp,
                      color: Colors.grey[500],
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.grey[500],
                    ),
                  ),
                ),
              ],
            ),
            decoration: PageDecoration(
              titlePadding: EdgeInsets.zero,
              titleTextStyle: const TextStyle(fontSize: 0),
              bodyAlignment: Alignment.center,
              pageColor: Colors.white,
              contentMargin: EdgeInsets.symmetric(horizontal: 16.w),
            ),
          ),
        ],
        onDone: () => _onIntroEnd(context),
        showSkipButton: true,
        skip: const Text("Passer"),
        next: const Icon(Icons.arrow_forward),
        showDoneButton: true,
        done: Text(
          "Passer",
          style: TextStyle(
            fontSize: 40.sp,
            color: Colors.grey[500],
          ),
        ),
        dotsDecorator: getDotsDecorator(),
        // Keep content below the status bar and controls above the home
        // indicator; without this, titles render under the system clock.
        safeAreaList: const [false, false, true, true],
        controlsMargin: EdgeInsets.only(bottom: 16.h),
        controlsPadding: const EdgeInsets.all(16),
      ),
    );
  }

  PageDecoration _getB12QuestionDecoration() => PageDecoration(
        titleTextStyle: TextStyle(fontSize: 64.sp, fontWeight: FontWeight.bold),
        bodyAlignment: Alignment.center,
        pageColor: Colors.white,
        contentMargin: EdgeInsets.symmetric(horizontal: 16.w),
      );

  Widget _buildB12ChoiceButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? Colors.white : Colors.grey[800],
          backgroundColor: selected ? primary : Colors.white,
          side: BorderSide(
            color: selected ? primary : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
          padding: EdgeInsets.symmetric(vertical: 24.h),
          shape: squircleBorder(radius: 16.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 44.sp,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildB12FrequencyChoices() {
    const options = {
      ReminderFrequency.daily: 'Tous les jours',
      ReminderFrequency.weekly: 'Une fois par semaine',
      ReminderFrequency.twiceWeekly: 'Deux fois par semaine',
      ReminderFrequency.biweekly: 'Toutes les deux semaines',
    };
    return Column(
      children: [
        for (final entry in options.entries) ...[
          _buildB12ChoiceButton(
            label: entry.value,
            selected: _b12Frequency == entry.key,
            onTap: () => _selectB12Frequency(entry.key),
          ),
          if (entry.key != options.keys.last) SizedBox(height: 16.h),
        ],
      ],
    );
  }

  Widget _buildB12DayChoices() {
    final primary = Theme.of(context).colorScheme.primary;
    final isTwiceWeekly = _b12Frequency == ReminderFrequency.twiceWeekly;
    return Column(
      children: [
        if (isTwiceWeekly) ...[
          Text(
            "Sélectionnez 2 jours (${_b12Days.length}/2)",
            style: TextStyle(fontSize: 42.sp, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20.h),
        ],
        Wrap(
          spacing: 12.w,
          runSpacing: 12.h,
          alignment: WrapAlignment.center,
          children: [
            for (final entry in _dayLabels.entries)
              FilterChip(
                label: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 42.sp,
                    fontWeight: _b12Days.contains(entry.key)
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _b12Days.contains(entry.key)
                        ? Colors.white
                        : Colors.grey[800],
                  ),
                ),
                selected: _b12Days.contains(entry.key),
                onSelected: (_) => _selectB12Day(entry.key),
                selectedColor: primary,
                checkmarkColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildB12TimeChoices() {
    const presets = [
      TimeOfDay(hour: 8, minute: 0),
      TimeOfDay(hour: 9, minute: 0),
      TimeOfDay(hour: 12, minute: 0),
      TimeOfDay(hour: 19, minute: 0),
      TimeOfDay(hour: 20, minute: 0),
      TimeOfDay(hour: 21, minute: 0),
    ];
    String format(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Wrap(
          spacing: 12.w,
          runSpacing: 12.h,
          alignment: WrapAlignment.center,
          children: [
            for (final preset in presets)
              ChoiceChip(
                label: Text(
                  format(preset),
                  style: TextStyle(
                    fontSize: 42.sp,
                    fontWeight: _b12Time == preset
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _b12Time == preset ? Colors.white : Colors.grey[800],
                  ),
                ),
                selected: _b12Time == preset,
                onSelected: _b12Saving ? null : (_) => _selectB12Time(preset),
                selectedColor: Theme.of(context).colorScheme.primary,
                checkmarkColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              ),
          ],
        ),
        SizedBox(height: 24.h),
        TextButton.icon(
          onPressed: _b12Saving ? null : _pickCustomB12Time,
          icon: Icon(Icons.access_time, size: 44.sp),
          label: Text(
            "Une autre heure…",
            style: TextStyle(fontSize: 42.sp),
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          "Le rappel sera activé dès que vous aurez choisi l'heure.",
          style: TextStyle(fontSize: 38.sp, color: Colors.grey[500]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  PageDecoration getPageDecoration() => PageDecoration(
        titleTextStyle: TextStyle(fontSize: 80.sp, fontWeight: FontWeight.bold),
        bodyTextStyle: TextStyle(fontSize: 50.sp),
        imagePadding: const EdgeInsets.all(24),
        pageColor: Colors.white,
      );

  PageDecoration getPageDecorationWithImage() => PageDecoration(
        titleTextStyle: TextStyle(fontSize: 80.sp, fontWeight: FontWeight.bold),
        bodyTextStyle: TextStyle(fontSize: 50.sp),
        imagePadding: EdgeInsets.fromLTRB(0, 0.05.sh, 0, 0),
        pageColor: Colors.white,
        imageFlex: 5,
        bodyFlex: 2,
        imageAlignment: Alignment.topCenter,
        contentMargin:
            EdgeInsets.only(top: 0.03.sh, left: 0.03.sw, right: 0.03.sw),
      );

  DotsDecorator getDotsDecorator() => const DotsDecorator(
        size: Size(5, 5),
        spacing: EdgeInsets.symmetric(horizontal: 3.0),
        activeSize: Size(14, 10),
        activeColor: Colors.green,
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      );
}
