import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../models/b12_reminder_settings.dart';
import '../../../services/b12_reminder_service.dart';
import '../../../services/notification_service.dart';
import '../../../themes/app_colors.dart';
import '../../../themes/app_shapes.dart';
import '../../../themes/app_spacing.dart';
import '../../../themes/app_text_styles.dart';
import '../../../widgets/b12/next_reminder_banner.dart';
import '../../../widgets/shared/app_background.dart';
import '../../../widgets/shared/app_button.dart';
import '../../../widgets/shared/app_card.dart';
import 'b12_info_page.dart';

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
            backgroundColor: kSemanticError,
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
          title: Text(
            'Rappel B12',
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

  void _openB12Info() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const B12InfoPage()),
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
                    Text('Vitamine B12', style: AppTextStyles.baloo22),
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
            child: AppButton(
              label: 'Infos sur la B12',
              icon: Icons.search,
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).colorScheme.primary,
              borderColor: Theme.of(context).colorScheme.primary,
              onPressed: _openB12Info,
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
        customBorder: squircleBorder(radius: 24.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          decoration: ShapeDecoration(
            color: isSelected
                ? primary.withValues(alpha: 0.06)
                : const Color(0xFFF7F6F2),
            shape: squircleBorder(
              radius: 24.r,
              side: BorderSide(
                color: isSelected ? primary : kBorderDefault,
                width: isSelected ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: ShapeDecoration(
                  color: isSelected
                      ? primary.withValues(alpha: 0.15)
                      : Colors.white,
                  shape: squircleBorder(radius: 16.r),
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
        AppButton(
          label: buttonLabel,
          icon: buttonIcon,
          backgroundColor: Theme.of(context).colorScheme.primary,
          onPressed: onPressed,
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
      child: AppButton(
        label: _settings.enabled ? 'Enregistrer' : 'Activer les rappels',
        backgroundColor: Theme.of(context).colorScheme.primary,
        isLoading: _isSaving,
        onPressed: _saveSettings,
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
