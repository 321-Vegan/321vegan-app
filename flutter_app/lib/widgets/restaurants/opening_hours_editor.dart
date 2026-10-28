import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/restaurants/restaurant.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import 'opening_slot_sheet.dart';

/// Week schedule input: a row per day with its slots (tap one to change
/// it, its cross to remove it), a "+" to add one (to several days at once
/// if wanted), e.g. 12:00–14:30 then 19:00–23:00, and a menu to add the
/// slots of another day. A slot closing before it opens ends after
/// midnight.
class OpeningHoursEditor extends StatelessWidget {
  final List<OpeningSlot> slots;
  final ValueChanged<List<OpeningSlot>> onChanged;
  final bool enabled;

  const OpeningHoursEditor({
    super.key,
    required this.slots,
    required this.onChanged,
    this.enabled = true,
  });

  /// Adds a slot from the wheels sheet, to [day] and the other days
  /// picked there. A day where it would overlap another slot is skipped
  /// (and named).
  Future<void> _addSlot(BuildContext context, int day) async {
    final entry = await showOpeningSlotSheet(context, day: day);
    if (entry == null || !context.mounted) return;

    var updated = [...slots];
    final skipped = <int>[];
    for (final d in entry.days.toList()..sort()) {
      final daySlots = [
        for (final service in entry.services)
          OpeningSlot(day: d, open: service.open, close: service.close),
      ];
      // Already there: nothing to add
      final missing = [
        for (final slot in daySlots)
          if (!updated.any((s) => s.day == d && s.label == slot.label)) slot,
      ];
      if (missing.isEmpty) continue;
      final withSlots = [...updated, ...missing];
      if (OpeningSlot.anyOverlap(withSlots)) {
        skipped.add(d);
      } else {
        updated = withSlots;
      }
    }
    if (updated.length != slots.length) onChanged(updated);
    if (skipped.isNotEmpty) {
      _warn(
          context,
          'Pas ajouté le ${skipped.map(dayName).join(', ')} : ces horaires '
          'chevauchent un autre créneau.');
    }
  }

  /// Changes the times of [slot], on its own day.
  Future<void> _editSlot(BuildContext context, OpeningSlot slot) async {
    final entry = await showOpeningSlotSheet(context,
        day: slot.day,
        open: slot.open,
        close: slot.close,
        allowOtherDays: false);
    if (entry == null || !context.mounted) return;
    final changed = entry.services.first;
    final updated = [
      for (final s in slots)
        s == slot
            ? OpeningSlot(
                day: slot.day, open: changed.open, close: changed.close)
            : s,
    ];
    if (OpeningSlot.anyOverlap(updated)) {
      _warn(context, 'Ce créneau chevauche un autre créneau.');
      return;
    }
    onChanged(updated);
  }

  void _warn(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: kSemanticError,
    ));
  }

  List<OpeningSlot> _slotsOf(int day) =>
      slots.where((s) => s.day == day).toList()
        ..sort((a, b) => a.openMinutes.compareTo(b.openMinutes));

  /// The other days' schedules [day] can copy, as (source day, schedule
  /// text): each different schedule once, left out when closed or when
  /// [day] already has all its slots.
  List<(int, String)> _copySources(int day) {
    final own = {for (final slot in _slotsOf(day)) slot.label};
    final seen = <String>{};
    return [
      for (var offset = 1; offset < 7; offset++)
        if (_slotsOf((day + offset) % 7) case final sourceSlots
            when sourceSlots.any((s) => !own.contains(s.label)) &&
                seen.add(sourceSlots.map((s) => s.label).join(', ')))
          (
            (day + offset) % 7,
            sourceSlots.map((s) => s.label).join(', '),
          ),
    ];
  }

  /// Adds [source]'s slots to [day]'s, but those it already has.
  void _copyFrom(BuildContext context, int day, int source) {
    final own = {for (final slot in _slotsOf(day)) slot.label};
    final updated = [
      ...slots,
      for (final slot in _slotsOf(source))
        if (!own.contains(slot.label)) slot.copyWith(day: day),
    ];
    if (OpeningSlot.anyOverlap(updated)) {
      _warn(
          context,
          'Ces horaires chevauchent les créneaux de ce jour '
          'ou d\'un jour voisin.');
      return;
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var day = 0; day < 7; day++) ...[
          // A line between days, so several slots read as one day's
          if (day > 0) const Divider(height: 1, color: kBorderDefault),
          Builder(builder: (context) {
            final daySlots = _slotsOf(day);
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 18.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 240.w,
                    child: Text(dayName(day, capitalize: true),
                        style: AppTextStyles.bodyMedium15),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 12.w,
                      runSpacing: 12.h,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (daySlots.isEmpty)
                          Text('Fermé',
                              style: AppTextStyles.bodyRegular15
                                  .copyWith(color: Colors.grey[500])),
                        for (final slot in daySlots)
                          InputChip(
                            label: Text(slot.label,
                                style: AppTextStyles.bodyRegular13),
                            tooltip: 'Modifier le créneau',
                            onPressed:
                                enabled ? () => _editSlot(context, slot) : null,
                            onDeleted: enabled
                                ? () => onChanged([...slots]..remove(slot))
                                : null,
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: kBorderDefault),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ajouter un créneau',
                    onPressed: enabled ? () => _addSlot(context, day) : null,
                    icon: Icon(Icons.add_circle_outline,
                        color: primary, size: 64.sp),
                  ),
                  if (_copySources(day).isNotEmpty)
                    PopupMenuButton<int>(
                      tooltip: 'Copier des horaires',
                      enabled: enabled,
                      icon: Icon(Icons.content_copy_outlined,
                          color: Colors.grey[600], size: 56.sp),
                      onSelected: (source) => _copyFrom(context, day, source),
                      itemBuilder: (_) => [
                        for (final (source, label) in _copySources(day))
                          PopupMenuItem(value: source, child: Text(label)),
                      ],
                    )
                  else
                    // Keeps the rows aligned
                    const SizedBox(width: kMinInteractiveDimension),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
