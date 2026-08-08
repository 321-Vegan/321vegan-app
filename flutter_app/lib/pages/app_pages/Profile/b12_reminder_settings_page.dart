import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../models/b12_reminder_settings.dart';
import '../../../services/b12_reminder_service.dart';
import '../../../services/notification_service.dart';
import '../../../themes/app_colors.dart';
import '../../../themes/app_spacing.dart';
import '../../../themes/app_text_styles.dart';
import '../../../widgets/b12/next_reminder_banner.dart';
import '../../../widgets/shared/app_background.dart';
import '../../../widgets/shared/app_card.dart';

class B12ReminderSettingsPage extends StatefulWidget {
  const B12ReminderSettingsPage({super.key});

  @override
  State<B12ReminderSettingsPage> createState() =>
      _B12ReminderSettingsPageState();
}

class _B12ReminderSettingsPageState extends State<B12ReminderSettingsPage> {
  B12ReminderSettings _settings = B12ReminderSettings();
  bool _isLoading = true;
  bool _isSaving = false;
  DateTime? _nextNotification;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final settings = await B12ReminderService.getSettings();
    final nextTime = await B12ReminderService.getNextNotificationTime();

    setState(() {
      _settings = settings;
      _nextNotification = nextTime;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      // Reaching Save (there's no separate on/off switch on this page
      // anymore) means the user wants reminders on with these settings.
      final settings = _settings.copyWith(enabled: true);

      if (settings.frequency == ReminderFrequency.twiceWeekly &&
          (settings.daysOfWeek == null || settings.daysOfWeek!.length != 2)) {
        throw Exception(
            'Veuillez sélectionner exactement 2 jours de la semaine');
      }
      if ((settings.frequency == ReminderFrequency.weekly ||
              settings.frequency == ReminderFrequency.biweekly) &&
          settings.dayOfWeek == null) {
        throw Exception(
            'Veuillez sélectionner un jour de la semaine pour ce type de rappel');
      }

      await B12ReminderService.scheduleReminder(settings);
      await NotificationService().showTestNotification();
      final nextTime = await B12ReminderService.getNextNotificationTime();

      setState(() {
        _settings = settings;
        _nextNotification = nextTime;
        _isSaving = false;
      });

      // Returning to Paramètres, where the "Rappels" switch now shows on,
      // is the confirmation — no snackbar needed (it would pop with the page).
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _disableReminders() async {
    setState(() => _isSaving = true);
    final settings = _settings.copyWith(enabled: false);
    await B12ReminderService.scheduleReminder(settings);
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _nextNotification = null;
      _isSaving = false;
    });
    Navigator.pop(context);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _settings.hour, minute: _settings.minute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _settings = _settings.copyWith(
          hour: picked.hour,
          minute: picked.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Rappel B12',
            style: TextStyle(fontWeight: FontWeight.bold),
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
                    _buildInfoCard(),
                    SizedBox(height: AppSpacing.section),
                    _buildFrequencyCard(),
                    SizedBox(height: AppSpacing.item),
                    _buildTimeCard(),
                    if (_settings.frequency ==
                        ReminderFrequency.twiceWeekly) ...[
                      SizedBox(height: AppSpacing.item),
                      _buildMultiDayCard(),
                    ] else if (_settings.frequency !=
                        ReminderFrequency.daily) ...[
                      SizedBox(height: AppSpacing.item),
                      _buildDayCard(),
                    ],
                    if (_settings.frequency == ReminderFrequency.biweekly) ...[
                      SizedBox(height: AppSpacing.item),
                      _buildStartDateCard(),
                    ],
                    if (_settings.enabled && _nextNotification != null) ...[
                      SizedBox(height: AppSpacing.item),
                      B12NextReminderBanner(
                        date: _nextNotification!,
                        showTime: true,
                      ),
                    ],
                    SizedBox(height: AppSpacing.section),
                    _buildSaveButton(),
                    if (_settings.enabled) ...[
                      SizedBox(height: 8.h),
                      _buildDisableButton(),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  void _showB12InfoModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28.r)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60.w,
                      height: 6.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Row(
                      children: [
                        Icon(
                          Icons.medication_rounded,
                          size: 64.sp,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(width: 16.w),
                        Text('Vitamine B12', style: AppTextStyles.sectionTitle),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(20.w),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                              size: 48.sp,
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Text(
                                'Informations validées par Astrid Prévost, diététicienne spécialisée en nutrition végétale. \nInstagram @astrid_nutrition_militante',
                                style: TextStyle(
                                  fontSize: 38.sp,
                                  color: kTextPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Container(
                        padding: EdgeInsets.all(20.w),
                        decoration: BoxDecoration(
                          color: kSecondaryTag,
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(color: kAccentYellow),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: kAccentYellow,
                              size: 48.sp,
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Text(
                                'Ces informations sont à titre indicatif et ne se substituent pas à un avis médical.',
                                style: TextStyle(
                                  fontSize: 38.sp,
                                  color: kAccentYellow,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),
                      _buildInfoSection(
                        'Pourquoi prendre un complément ?',
                        Text(
                          'La complémentation en vitamine B12 est essentielle car cette vitamine est absente de l\'alimentation végétale. Sans complémentation, une carence arrivera tôt ou tard et peut avoir des conséquences graves.',
                          style: TextStyle(
                            fontSize: 42.sp,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        Icons.info_outline,
                      ),
                      SizedBox(height: 24.h),
                      _buildInfoSection(
                        'Dosages recommandés :',
                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 42.sp,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                            children: [
                              const TextSpan(
                                text: '• Par jour : 25 µg\n'
                                    '• Par semaine : 2000 µg (en une prise)\n'
                                    '• Tous les 15 jours : 5000 µg (en une prise)\n',
                              ),
                              TextSpan(
                                text:
                                    'Pour les enfants : de 6 à 24 mois doses divisées par 4, de 2 à 12 ans doses divisées par 2.',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 40.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icons.ads_click_outlined,
                      ),
                      SizedBox(height: 24.h),
                      _buildInfoSection(
                        'Pour une bonne absorption :',
                        Text(
                          '• La prise quotidienne permet une meilleure absorption et, hormis les adultes en bonne santé, toutes les catégories de population devraient la privilégier.\n•Pour une absorption optimale, le mieux est de prendre sa B12 pendant ou après un repas.\n•La spiruline ne contient pas de B12 et en limite l\'absorption. Si vous en prenez le matin : prenez votre B12 le soir, et inversement.',
                          style: TextStyle(
                            fontSize: 42.sp,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        Icons.pin_drop,
                      ),
                      SizedBox(height: 24.h),
                      _buildInfoSection(
                        'Où trouver la B12 ?',
                        Text(
                          'Pour une prise quotidienne, la Veg1 est très populaire et contient d\'autres vitamines. Pour une prescription médicale remboursable, vous pouvez demander les ampoules de Gerda à votre médecin (attention, la forme en comprimés contient du lactose).',
                          style: TextStyle(
                            fontSize: 42.sp,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        Icons.pin_drop,
                      ),
                      SizedBox(height: 50.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, Widget content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 48.sp,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 12.w),
            Text(
              title,
              style: TextStyle(
                fontSize: 48.sp,
                fontWeight: FontWeight.bold,
                color: kTextPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        content,
      ],
    );
  }

  Widget _buildInfoCard() {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: const BoxDecoration(
                  color: kAccentYellow,
                  shape: BoxShape.circle,
                ),
                child: Text('💊', style: TextStyle(fontSize: 44.sp)),
              ),
              SizedBox(width: 20.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vitamine B12', style: AppTextStyles.sectionTitle),
                    Text(
                      'N\'oubliez plus jamais de prendre votre B12 !',
                      style:
                          TextStyle(fontSize: 36.sp, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.item),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showB12InfoModal,
              icon: Icon(Icons.search, size: 40.sp),
              label: Text(
                'Infos sur la B12',
                style: TextStyle(fontSize: 38.sp, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 42.sp,
        fontWeight: FontWeight.w600,
        color: kTextPrimary,
      ),
    );
  }

  Widget _buildFrequencyCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Fréquence'),
          SizedBox(height: AppSpacing.afterTitle),
          _buildFrequencyOption(
            'Tous les jours',
            ReminderFrequency.daily,
            Icons.arrow_circle_right_outlined,
          ),
          SizedBox(height: AppSpacing.item),
          _buildFrequencyOption(
            'Une fois par semaine',
            ReminderFrequency.weekly,
            Icons.arrow_circle_right_outlined,
          ),
          SizedBox(height: AppSpacing.item),
          _buildFrequencyOption(
            'Deux fois par semaine',
            ReminderFrequency.twiceWeekly,
            Icons.arrow_circle_right_outlined,
          ),
          SizedBox(height: AppSpacing.item),
          _buildFrequencyOption(
            'Toutes les deux semaines',
            ReminderFrequency.biweekly,
            Icons.arrow_circle_right_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyOption(
    String label,
    ReminderFrequency frequency,
    IconData icon,
  ) {
    final isSelected = _settings.frequency == frequency;
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (frequency == ReminderFrequency.twiceWeekly) {
              _settings = _settings.copyWith(
                frequency: frequency,
                daysOfWeek: _settings.daysOfWeek ?? [1, 4],
              );
            } else {
              _settings = _settings.copyWith(
                frequency: frequency,
                dayOfWeek: frequency != ReminderFrequency.daily
                    ? (_settings.dayOfWeek ?? 1)
                    : null,
              );
            }
          });
        },
        borderRadius: BorderRadius.circular(24.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          decoration: BoxDecoration(
            color: isSelected
                ? primary.withValues(alpha: 0.06)
                : const Color(0xFFF7F6F2),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(
              color: isSelected ? primary : kBorderDefault,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primary.withValues(alpha: 0.15)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? primary : Colors.grey[500],
                  size: 48.sp,
                ),
              ),
              SizedBox(width: 20.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 40.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? primary : kTextPrimary,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration:
                      BoxDecoration(color: primary, shape: BoxShape.circle),
                  child: Icon(Icons.check_rounded,
                      color: Colors.white, size: 40.sp),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shared "label + value, edit button" row used by the time and start
  /// date pickers.
  Widget _buildValueRow({
    required String label,
    required String value,
    required String buttonLabel,
    required IconData buttonIcon,
    required VoidCallback onPressed,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel(label),
              SizedBox(height: 4.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 44.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 16.w),
        ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(buttonIcon, size: 36.sp),
          label: Text(
            buttonLabel,
            style: TextStyle(fontSize: 34.sp, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
            shape: const StadiumBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeCard() {
    final timeStr =
        '${_settings.hour.toString().padLeft(2, '0')}:${_settings.minute.toString().padLeft(2, '0')}';
    return AppCard(
      child: _buildValueRow(
        label: 'Heure',
        value: timeStr,
        buttonLabel: 'Modifier',
        buttonIcon: Icons.access_time,
        onPressed: _pickTime,
      ),
    );
  }

  Widget _buildDayCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Jour de la semaine'),
          SizedBox(height: AppSpacing.afterTitle),
          Wrap(
            spacing: 12.w,
            runSpacing: 12.h,
            children: [
              _buildDayChip('Lun', 1),
              _buildDayChip('Mar', 2),
              _buildDayChip('Mer', 3),
              _buildDayChip('Jeu', 4),
              _buildDayChip('Ven', 5),
              _buildDayChip('Sam', 6),
              _buildDayChip('Dim', 7),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayChip(String label, int day) {
    final isSelected = _settings.dayOfWeek == day;
    final primary = Theme.of(context).colorScheme.primary;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 38.sp,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : kTextPrimary,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _settings = _settings.copyWith(dayOfWeek: selected ? day : null);
        });
      },
      backgroundColor: const Color(0xFFF7F6F2),
      selectedColor: primary,
      checkmarkColor: Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: isSelected ? primary : kBorderDefault),
      ),
      side: BorderSide(color: isSelected ? primary : kBorderDefault),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
    );
  }

  Widget _buildMultiDayCard() {
    final selectedDays = _settings.daysOfWeek ?? [];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Jours de la semaine (2 jours)'),
          SizedBox(height: AppSpacing.afterTitle),
          Wrap(
            spacing: 12.w,
            runSpacing: 12.h,
            children: [
              _buildMultiDayChip('Lun', 1, selectedDays),
              _buildMultiDayChip('Mar', 2, selectedDays),
              _buildMultiDayChip('Mer', 3, selectedDays),
              _buildMultiDayChip('Jeu', 4, selectedDays),
              _buildMultiDayChip('Ven', 5, selectedDays),
              _buildMultiDayChip('Sam', 6, selectedDays),
              _buildMultiDayChip('Dim', 7, selectedDays),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiDayChip(String label, int day, List<int> selectedDays) {
    final isSelected = selectedDays.contains(day);
    final primary = Theme.of(context).colorScheme.primary;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 38.sp,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : kTextPrimary,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          final days = List<int>.from(selectedDays);
          if (selected) {
            if (days.length < 2) {
              days.add(day);
            } else {
              // Replace the oldest selection
              days.removeAt(0);
              days.add(day);
            }
          } else {
            days.remove(day);
          }
          _settings = _settings.copyWith(daysOfWeek: days);
        });
      },
      backgroundColor: const Color(0xFFF7F6F2),
      selectedColor: primary,
      checkmarkColor: Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: isSelected ? primary : kBorderDefault),
      ),
      side: BorderSide(color: isSelected ? primary : kBorderDefault),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
    );
  }

  Future<void> _pickStartDate() async {
    // Default to the next occurrence of the selected day of week
    final now = DateTime.now();
    final dayOfWeek = _settings.dayOfWeek ?? 1;
    int daysUntil = (dayOfWeek - now.weekday) % 7;
    if (daysUntil == 0) daysUntil = 7;
    final defaultDate =
        _settings.biweeklyStartDate ?? now.add(Duration(days: daysUntil));

    // A previously saved start date can be in the past; showDatePicker
    // requires initialDate >= firstDate.
    final initialDate =
        DateUtils.dateOnly(defaultDate).isBefore(DateUtils.dateOnly(now))
            ? now.add(Duration(days: daysUntil))
            : defaultDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _settings = _settings.copyWith(
          biweeklyStartDate: picked,
          dayOfWeek: picked.weekday,
        );
      });
    }
  }

  Widget _buildStartDateCard() {
    final formatter = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    final startDateStr = _settings.biweeklyStartDate != null
        ? formatter.format(_settings.biweeklyStartDate!)
        : 'Non définie';

    return AppCard(
      child: _buildValueRow(
        label: 'Date de début',
        value: startDateStr,
        buttonLabel: 'Choisir',
        buttonIcon: Icons.calendar_today,
        onPressed: _pickStartDate,
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 18.h),
          shape: const StadiumBorder(),
        ),
        child: _isSaving
            ? SizedBox(
                height: 40.h,
                width: 40.h,
                child: const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _settings.enabled ? 'Enregistrer' : 'Activer les rappels',
                style: TextStyle(fontSize: 40.sp, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildDisableButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _isSaving ? null : _disableReminders,
        style: TextButton.styleFrom(
          foregroundColor: Colors.grey[600],
          padding: EdgeInsets.symmetric(vertical: 20.h),
        ),
        child: Text(
          'Désactiver les rappels',
          style: TextStyle(fontSize: 38.sp, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
