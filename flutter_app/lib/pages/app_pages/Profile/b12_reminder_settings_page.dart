import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../models/b12_reminder_settings.dart';
import '../../../services/b12_reminder_service.dart';
import '../../../services/notification_service.dart';

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
      // Validate settings before saving
      if (_settings.enabled &&
          _settings.frequency == ReminderFrequency.twiceWeekly &&
          (_settings.daysOfWeek == null || _settings.daysOfWeek!.length != 2)) {
        throw Exception(
            'Veuillez sélectionner exactement 2 jours de la semaine');
      }
      if (_settings.enabled &&
          (_settings.frequency == ReminderFrequency.weekly ||
              _settings.frequency == ReminderFrequency.biweekly) &&
          _settings.dayOfWeek == null) {
        throw Exception(
            'Veuillez sélectionner un jour de la semaine pour ce type de rappel');
      }

      await B12ReminderService.scheduleReminder(_settings);
      await NotificationService().showTestNotification();
      final nextTime = await B12ReminderService.getNextNotificationTime();

      setState(() {
        _nextNotification = nextTime;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rappel enregistré avec succès'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rappel B12'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  SizedBox(height: 24.h),
                  _buildSettingsCard(),
                  SizedBox(height: 24.h),
                  _buildNextNotificationCard(),
                  SizedBox(height: 32.h),
                  _buildSaveButton(),
                  SizedBox(height: 120.h),
                ],
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
                        Text(
                          'Vitamine B12',
                          style: TextStyle(
                            fontSize: 56.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
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
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: Colors.blue[200]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.blue[700],
                              size: 48.sp,
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Text(
                                'Informations validées par Astrid Prévost, diététicienne spécialisée en nutrition végétale. \nInstagram @astrid_nutrition_militante',
                                style: TextStyle(
                                  fontSize: 38.sp,
                                  color: Colors.blue[900],
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
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: Colors.orange[200]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange[700],
                              size: 48.sp,
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Text(
                                'Ces informations sont à titre indicatif et ne se substituent pas à un avis médical.',
                                style: TextStyle(
                                  fontSize: 38.sp,
                                  color: Colors.orange[900],
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
                color: Colors.grey[800],
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
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                    padding: EdgeInsets.all(16.w),
                    child: Text(
                      '💊',
                      style: TextStyle(fontSize: 64.sp),
                    )),
                SizedBox(width: 20.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vitamine B12',
                        style: TextStyle(
                          fontSize: 52.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'N\'oubliez plus jamais de prendre votre B12 !',
                        style: TextStyle(
                          fontSize: 40.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showB12InfoModal,
                icon: Icon(Icons.search, size: 48.sp),
                label: Text(
                  'Infos sur la B12',
                  style: TextStyle(fontSize: 42.sp),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 18.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEnabledSwitch(),
            if (_settings.enabled) ...[
              Divider(height: 48.h),
              _buildFrequencySelector(),
              Divider(height: 48.h),
              _buildTimeSelector(),
              if (_settings.frequency == ReminderFrequency.twiceWeekly) ...[
                Divider(height: 48.h),
                _buildMultiDaySelector(),
              ] else if (_settings.frequency != ReminderFrequency.daily) ...[
                Divider(height: 48.h),
                _buildDaySelector(),
              ],
              if (_settings.frequency == ReminderFrequency.biweekly) ...[
                Divider(height: 48.h),
                _buildStartDateSelector(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEnabledSwitch() {
    return SwitchListTile(
      title: Text(
        'Activer les rappels',
        style: TextStyle(
          fontSize: 44.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        _settings.enabled
            ? 'Les rappels sont activés'
            : 'Les rappels sont désactivés',
        style: TextStyle(fontSize: 38.sp),
      ),
      value: _settings.enabled,
      onChanged: (value) {
        setState(() {
          _settings = _settings.copyWith(enabled: value);
        });
      },
      activeThumbColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildFrequencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fréquence',
          style: TextStyle(
            fontSize: 44.sp,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 20.h),
        _buildFrequencyOption(
          'Tous les jours',
          ReminderFrequency.daily,
          Icons.arrow_circle_right_outlined,
        ),
        SizedBox(height: 16.h),
        _buildFrequencyOption(
          'Une fois par semaine',
          ReminderFrequency.weekly,
          Icons.arrow_circle_right_outlined,
        ),
        SizedBox(height: 16.h),
        _buildFrequencyOption(
          'Deux fois par semaine',
          ReminderFrequency.twiceWeekly,
          Icons.arrow_circle_right_outlined,
        ),
        SizedBox(height: 16.h),
        _buildFrequencyOption(
          'Toutes les deux semaines',
          ReminderFrequency.biweekly,
          Icons.arrow_circle_right_outlined,
        ),
      ],
    );
  }

  Widget _buildFrequencyOption(
    String label,
    ReminderFrequency frequency,
    IconData icon,
  ) {
    final isSelected = _settings.frequency == frequency;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
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
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[300]!,
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: isSelected ? 12 : 8,
                  offset: Offset(0, isSelected ? 4 : 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[600],
                    size: 52.sp,
                  ),
                ),
                SizedBox(width: 20.w),
                SizedBox(width: 20.w),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 44.sp,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[800],
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 44.sp,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    final timeStr =
        '${_settings.hour.toString().padLeft(2, '0')}:${_settings.minute.toString().padLeft(2, '0')}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        'Heure',
        style: TextStyle(
          fontSize: 44.sp,
          fontWeight: FontWeight.w500,
          color: Colors.grey[800],
        ),
      ),
      subtitle: Text(
        timeStr,
        style: TextStyle(
          fontSize: 48.sp,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      trailing: ElevatedButton.icon(
        onPressed: _pickTime,
        icon: Icon(Icons.access_time, size: 48.sp),
        label: Text('Modifier', style: TextStyle(fontSize: 40.sp)),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jour de la semaine',
          style: TextStyle(
            fontSize: 44.sp,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16.h),
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
    );
  }

  Widget _buildDayChip(String label, int day) {
    final isSelected = _settings.dayOfWeek == day;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 40.sp,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : Colors.grey[800],
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _settings = _settings.copyWith(dayOfWeek: selected ? day : null);
        });
      },
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
    );
  }

  Widget _buildMultiDaySelector() {
    final selectedDays = _settings.daysOfWeek ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jours de la semaine (2 jours)',
          style: TextStyle(
            fontSize: 44.sp,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16.h),
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
    );
  }

  Widget _buildMultiDayChip(String label, int day, List<int> selectedDays) {
    final isSelected = selectedDays.contains(day);

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 40.sp,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : Colors.grey[800],
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
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
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

  Widget _buildStartDateSelector() {
    final formatter = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    final startDateStr = _settings.biweeklyStartDate != null
        ? formatter.format(_settings.biweeklyStartDate!)
        : 'Non définie';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        'Date de début',
        style: TextStyle(
          fontSize: 44.sp,
          fontWeight: FontWeight.w500,
          color: Colors.grey[800],
        ),
      ),
      subtitle: Text(
        startDateStr,
        style: TextStyle(
          fontSize: 42.sp,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      trailing: ElevatedButton.icon(
        onPressed: _pickStartDate,
        icon: Icon(Icons.calendar_today, size: 48.sp),
        label: Text('Choisir', style: TextStyle(fontSize: 40.sp)),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        ),
      ),
    );
  }

  Widget _buildNextNotificationCard() {
    if (!_settings.enabled || _nextNotification == null) {
      return const SizedBox.shrink();
    }

    final formatter = DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr_FR');
    final nextTimeStr = formatter.format(_nextNotification!);

    return Card(
      elevation: 2,
      color: Colors.blue[50],
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Row(
          children: [
            Icon(
              Icons.notifications_active,
              color: Colors.blue[700],
              size: 64.sp,
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prochain rappel',
                    style: TextStyle(
                      fontSize: 40.sp,
                      color: Colors.blue[900],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    nextTimeStr,
                    style: TextStyle(
                      fontSize: 38.sp,
                      color: Colors.blue[700],
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

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 24.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: _isSaving
            ? SizedBox(
                height: 48.h,
                width: 48.h,
                child: const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Enregistrer',
                style: TextStyle(
                  fontSize: 48.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
