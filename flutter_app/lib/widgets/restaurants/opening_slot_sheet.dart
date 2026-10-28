import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/restaurants/restaurant.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/bottom_sheet_shell.dart';
import '../shared/selectable_chip.dart';

/// Slots entered in [showOpeningSlotSheet]: each service's opening and
/// closing times ("HH:MM"), and the days (0 = monday) they apply to.
typedef OpeningSlotEntry = ({
  List<({String open, String close})> services,
  Set<int> days,
});

/// Wheel pickers for a slot's opening and closing times. When adding
/// ([allowOtherDays]), more services can be added (e.g. lunch then dinner)
/// and they can go to several days at once; when changing a slot, there's
/// just that one.
Future<OpeningSlotEntry?> showOpeningSlotSheet(
  BuildContext context, {
  required int day,
  String? open,
  String? close,
  bool allowOtherDays = true,
}) {
  return showModalBottomSheet<OpeningSlotEntry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OpeningSlotSheet(
      day: day,
      open: open ?? '12:00',
      close: close ?? '14:30',
      allowOtherDays: allowOtherDays,
    ),
  );
}

class _OpeningSlotSheet extends StatefulWidget {
  final int day;
  final String open;
  final String close;
  final bool allowOtherDays;

  const _OpeningSlotSheet({
    required this.day,
    required this.open,
    required this.close,
    required this.allowOtherDays,
  });

  @override
  State<_OpeningSlotSheet> createState() => _OpeningSlotSheetState();
}

/// A service being entered; [id] keeps its wheels when another one is
/// removed.
class _Service {
  final int id;
  DateTime open;
  DateTime close;

  _Service(this.id, this.open, this.close);

  bool get sameTime => open.hour == close.hour && open.minute == close.minute;

  bool get endsNextDay =>
      close.hour * 60 + close.minute < open.hour * 60 + open.minute;
}

class _OpeningSlotSheetState extends State<_OpeningSlotSheet> {
  static const _minuteInterval = 5;
  static const _maxServices = 3;

  late final List<_Service> _services = [
    _Service(0, _parse(widget.open), _parse(widget.close)),
  ];
  int _nextId = 1;
  late final Set<int> _days = {widget.day};

  /// On an arbitrary date: only the time matters, rounded to the wheels'
  /// step.
  static DateTime _parse(String hhmm) {
    final parts = hhmm.split(':');
    final minutes = int.parse(parts[1]);
    final rounded = (minutes / _minuteInterval).round() * _minuteInterval;
    return DateTime(2000, 1, 1, int.parse(parts[0]))
        .add(Duration(minutes: rounded.clamp(0, 60 - _minuteInterval)));
  }

  static String _format(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  List<({String open, String close})> get _entered => [
        for (final service in _services)
          (open: _format(service.open), close: _format(service.close)),
      ];

  /// What prevents saving, in words, or null.
  String? get _problem {
    if (_services.any((service) => service.sameTime)) {
      return 'L\'ouverture et la fermeture doivent être différentes.';
    }
    final slots = [
      for (final service in _entered)
        OpeningSlot(day: 0, open: service.open, close: service.close),
    ];
    if (OpeningSlot.anyOverlap(slots)) {
      return 'Les services se chevauchent.';
    }
    return null;
  }

  /// A dinner after the last service by default.
  void _addService() {
    setState(() =>
        _services.add(_Service(_nextId++, _parse('19:00'), _parse('22:30'))));
  }

  Widget _wheel(String label, DateTime value, ValueChanged<DateTime> onChanged,
      {Key? key}) {
    return Expanded(
      key: key,
      child: Column(
        children: [
          Text(label,
              style:
                  AppTextStyles.bodyBold13.copyWith(color: Colors.grey[600])),
          SizedBox(
            height: 300.h,
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
                minuteInterval: _minuteInterval,
                initialDateTime: value,
                onDateTimeChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) =>
      SelectableChip(
          label: label, selected: selected, onTap: onTap, dense: true);

  @override
  Widget build(BuildContext context) {
    return BottomSheetShell(
      child: Flexible(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dayName(widget.day, capitalize: true),
                  style: AppTextStyles.baloo22),
              SizedBox(height: 8.h),
              Text(
                'Choisissez l\'heure d\'ouverture et de fermeture.',
                style: AppTextStyles.bodyRegular15
                    .copyWith(color: Colors.grey[600]),
              ),
              for (final (index, service) in _services.indexed) ...[
                SizedBox(height: 36.h),
                if (_services.length > 1)
                  Row(
                    children: [
                      Expanded(
                        child: Text('Service ${index + 1}',
                            style: AppTextStyles.bodyBold15),
                      ),
                      if (index > 0)
                        IconButton(
                          tooltip: 'Retirer ce service',
                          onPressed: () =>
                              setState(() => _services.remove(service)),
                          icon: Icon(Icons.close,
                              size: 52.sp, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                Row(
                  children: [
                    _wheel('Ouverture', service.open,
                        (time) => setState(() => service.open = time),
                        key: ValueKey('open${service.id}')),
                    SizedBox(width: 24.w),
                    _wheel('Fermeture', service.close,
                        (time) => setState(() => service.close = time),
                        key: ValueKey('close${service.id}')),
                  ],
                ),
                SizedBox(height: 12.h),
                Center(
                  child: Text(
                    service.endsNextDay
                        ? 'Ferme après minuit, le lendemain.'
                        : '${_format(service.open)} – ${_format(service.close)}',
                    style: AppTextStyles.bodyMedium13
                        .copyWith(color: Colors.grey[600]),
                  ),
                ),
              ],
              if (widget.allowOtherDays && _services.length < _maxServices)
                Padding(
                  padding: EdgeInsets.only(top: 24.h),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: _addService,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un service'),
                    ),
                  ),
                ),
              if (_problem != null)
                Padding(
                  padding: EdgeInsets.only(top: 12.h),
                  child: Center(
                    child: Text(_problem!,
                        style: AppTextStyles.bodyMedium13
                            .copyWith(color: kSemanticError)),
                  ),
                ),
              if (widget.allowOtherDays) ...[
                SizedBox(height: 36.h),
                Text('Mêmes horaires autres jours',
                    style: AppTextStyles.bodyBold15),
                SizedBox(height: 18.h),
                Wrap(
                  spacing: 12.w,
                  runSpacing: 12.h,
                  children: [
                    for (var day = 0; day < 7; day++)
                      _chip(
                        dayName(day, capitalize: true).substring(0, 3),
                        _days.contains(day),
                        // The day the slot was added from always keeps it
                        day == widget.day
                            ? () {}
                            : () => setState(() => _days.contains(day)
                                ? _days.remove(day)
                                : _days.add(day)),
                      ),
                  ],
                ),
              ],
              SizedBox(height: 48.h),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: _days.length > 1
                      ? 'Ajouter à ${_days.length} jours'
                      : 'Enregistrer',
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  onPressed: _problem != null
                      ? null
                      : () => Navigator.of(context)
                          .pop((services: _entered, days: _days)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
