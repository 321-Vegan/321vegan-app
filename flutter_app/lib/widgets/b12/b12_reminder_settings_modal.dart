import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../models/b12_reminder_settings.dart';
import '../../services/b12_reminder_service.dart';
import '../../services/notification_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/bottom_sheet_shell.dart';
import '../shared/info_box.dart';

const List<String> _dayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

/// Bottom sheet for editing B12 reminder settings — frequency, day(s) of
/// week, and time. Opened from Settings ("Rappels") and the Dashboard's
/// B12 activation banner with:
/// `showModalBottomSheet(context: ..., isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const B12ReminderSettingsModal())`
class B12ReminderSettingsModal extends StatefulWidget {
  const B12ReminderSettingsModal({super.key});

  @override
  State<B12ReminderSettingsModal> createState() =>
      _B12ReminderSettingsModalState();
}

class _B12ReminderSettingsModalState extends State<B12ReminderSettingsModal> {
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
    final settings = await B12ReminderService.getSettings();
    final nextTime = await B12ReminderService.getNextNotificationTime();

    if (mounted) {
      setState(() {
        _settings = settings;
        _nextNotification = nextTime;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      // Reaching Save (there's no separate on/off switch on this sheet
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

      // Closing the sheet, after which the "Rappels" switch shows on, is
      // the confirmation — no snackbar needed.
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
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetShell(
      child: _isLoading
          ? SizedBox(
              height: 400.h,
              child: const Center(child: CircularProgressIndicator()),
            )
          : ConstrainedBox(
              constraints:
                  BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rappel de votre B12', style: AppTextStyles.baloo26),
                    SizedBox(height: 8.h),
                    Text(
                      'N\'oubliez plus jamais de prendre votre B12 !',
                      style: TextStyle(
                        fontSize: 42.sp,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: AppSpacing.section),
                    _sectionLabel('Fréquence'),
                    SizedBox(height: AppSpacing.afterTitle),
                    _buildFrequencyOption('Tous les jours', ReminderFrequency.daily),
                    SizedBox(height: AppSpacing.item),
                    _buildFrequencyOption('Une fois par semaine', ReminderFrequency.weekly),
                    SizedBox(height: AppSpacing.item),
                    _buildFrequencyOption(
                        'Deux fois par semaine', ReminderFrequency.twiceWeekly),
                    SizedBox(height: AppSpacing.item),
                    _buildFrequencyOption(
                        'Toutes les deux semaines', ReminderFrequency.biweekly),
                    if (_settings.frequency == ReminderFrequency.twiceWeekly) ...[
                      SizedBox(height: AppSpacing.section),
                      _sectionLabel('Jours de la semaine (2 jours)'),
                      SizedBox(height: AppSpacing.afterTitle),
                      _buildDayRow(
                        isSelected: (day) => (_settings.daysOfWeek ?? []).contains(day),
                        onTap: (day) => setState(() {
                          final days = List<int>.from(_settings.daysOfWeek ?? []);
                          if (days.contains(day)) {
                            days.remove(day);
                          } else if (days.length < 2) {
                            days.add(day);
                          } else {
                            days.removeAt(0);
                            days.add(day);
                          }
                          _settings = _settings.copyWith(daysOfWeek: days);
                        }),
                      ),
                    ] else if (_settings.frequency != ReminderFrequency.daily) ...[
                      SizedBox(height: AppSpacing.section),
                      _sectionLabel('Jour de la semaine'),
                      SizedBox(height: AppSpacing.afterTitle),
                      _buildDayRow(
                        isSelected: (day) => _settings.dayOfWeek == day,
                        onTap: (day) => setState(() {
                          _settings = _settings.copyWith(dayOfWeek: day);
                        }),
                      ),
                    ],
                    SizedBox(height: AppSpacing.section),
                    _sectionLabel('Heure'),
                    _buildTimeWheel(),
                    if (_settings.enabled && _nextNotification != null) ...[
                      SizedBox(height: AppSpacing.item),
                      InfoBox(
                        iconAsset: 'lib/assets/images/icons/info-circle.webp',
                        text: 'Prochain rappel : '
                            '${_capitalizeFr(B12ReminderService.relativeDayLabel(_nextNotification!))} '
                            'à ${DateFormat('HH:mm').format(_nextNotification!)}.',
                      ),
                    ],
                    SizedBox(height: AppSpacing.section),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label: _settings.enabled ? 'Enregistrer' : 'Activer les rappels',
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        isLoading: _isSaving,
                        onPressed: _saveSettings,
                      ),
                    ),
                    if (_settings.enabled) ...[
                      SizedBox(height: 8.h),
                      SizedBox(
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
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  String _capitalizeFr(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  Widget _sectionLabel(String label) {
    return Text(label, style: AppTextStyles.baloo17);
  }

  Widget _buildFrequencyOption(String label, ReminderFrequency frequency) {
    final isSelected = _settings.frequency == frequency;

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
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
          decoration: ShapeDecoration(
            color: isSelected ? kSecondaryTag : Colors.white,
            shape: squircleBorder(
              radius: 24.r,
              side: BorderSide(
                color: isSelected ? kAccentYellow : kBorderDefault,
                width: isSelected ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyRegular15.copyWith(
                    fontWeight: const FontWeight(400),
                    color: isSelected ? kAccentYellow : null,
                  ),
                ),
              ),
              SizedBox(
                width: 108.w,
                height: 108.w,
                child: isSelected
                    ? Center(
                        child: Image.asset(
                          'lib/assets/images/icons/solid-check.webp',
                          width: 60.w,
                          height: 60.w,
                          color: kAccentYellow,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Seven equal-width day pills in a single row (Lun…Dim) so they always
  /// fit the sheet's width instead of wrapping unevenly.
  Widget _buildDayRow({
    required bool Function(int day) isSelected,
    required void Function(int day) onTap,
  }) {
    return Row(
      children: List.generate(7, (i) {
        final day = i + 1;
        final selected = isSelected(day);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: GestureDetector(
              onTap: () => onTap(day),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 18.h),
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: selected ? kAccentYellow : Colors.white,
                  shape: squircleBorder(
                    radius: 16.r,
                    side: BorderSide(color: selected ? kAccentYellow : kBorderDefault),
                  ),
                ),
                child: Text(
                  _dayLabels[i],
                  style: AppTextStyles.bodyMedium15.copyWith(
                    fontWeight: const FontWeight(400),
                    color: selected ? Colors.white : null,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTimeWheel() {
    final initial = DateTime(2024, 1, 1, _settings.hour, _settings.minute);
    return SizedBox(
      height: 280.h,
      child: CupertinoTheme(
        data: CupertinoTheme.of(context).copyWith(
          textTheme: CupertinoTheme.of(context).textTheme.copyWith(
                dateTimePickerTextStyle: CupertinoTheme.of(context)
                    .textTheme
                    .dateTimePickerTextStyle
                    .copyWith(fontFamily: 'Baloo2'),
              ),
        ),
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          use24hFormat: true,
          initialDateTime: initial,
          onDateTimeChanged: (date) => setState(() {
            _settings = _settings.copyWith(hour: date.hour, minute: date.minute);
          }),
        ),
      ),
    );
  }

}
