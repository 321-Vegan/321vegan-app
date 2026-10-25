import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/restaurants/restaurant.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/bottom_sheet_shell.dart';
import 'restaurant_labels.dart';

/// Filters of the map's restaurant layer. [openNow] is applied app-side
/// from the pins' opening hours, the others by the API.
class RestaurantMapFilters {
  final Set<String> tags;
  final Set<String> serviceOptions;
  final bool fullyVeganOnly;
  final bool openNow;
  final bool noPlantMilkSurcharge;

  const RestaurantMapFilters({
    this.tags = const {},
    this.serviceOptions = const {},
    this.fullyVeganOnly = false,
    this.openNow = false,
    this.noPlantMilkSurcharge = false,
  });

  /// Number of active filters, for the filter button's badge.
  int get count =>
      tags.length +
      serviceOptions.length +
      (fullyVeganOnly ? 1 : 0) +
      (openNow ? 1 : 0) +
      (noPlantMilkSurcharge ? 1 : 0);

  /// Whether [restaurant] passes the app-side filters.
  bool keeps(Restaurant restaurant, DateTime now) =>
      !openNow || restaurant.openingStateAt(now)?.isOpen == true;
}

/// Bottom sheet to edit the restaurant filters; resolves with the new ones,
/// or null when dismissed.
Future<RestaurantMapFilters?> showRestaurantFilterSheet(
  BuildContext context,
  RestaurantMapFilters current,
) {
  return showModalBottomSheet<RestaurantMapFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RestaurantFilterSheet(current: current),
  );
}

class _RestaurantFilterSheet extends StatefulWidget {
  final RestaurantMapFilters current;

  const _RestaurantFilterSheet({required this.current});

  @override
  State<_RestaurantFilterSheet> createState() => _RestaurantFilterSheetState();
}

class _RestaurantFilterSheetState extends State<_RestaurantFilterSheet> {
  late final Set<String> _tags = {...widget.current.tags};
  late final Set<String> _serviceOptions = {...widget.current.serviceOptions};
  late bool _fullyVeganOnly = widget.current.fullyVeganOnly;
  late bool _openNow = widget.current.openNow;
  late bool _noSurcharge = widget.current.noPlantMilkSurcharge;

  /// Toggles [value] in [values] (the tags or the service options), with
  /// [icon] (in [iconColor]) before the label, as in the creation form.
  Widget _tagChip(Set<String> values, String value, String label,
      {IconData? icon, Color? iconColor}) {
    final primary = Theme.of(context).colorScheme.primary;
    final selected = values.contains(value);
    return GestureDetector(
      onTap: () =>
          setState(() => selected ? values.remove(value) : values.add(value)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 21.h),
        decoration: ShapeDecoration(
          color: selected ? primary.withValues(alpha: 0.08) : Colors.white,
          shape: squircleBorder(
            radius: 100.r,
            side: BorderSide(
              color: selected ? primary : kBorderDefault,
              width: selected ? 1.5 : 1,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 42.sp, color: iconColor),
              SizedBox(width: 12.w),
            ],
            Text(label,
                style: AppTextStyles.bodyMedium13
                    .copyWith(color: selected ? primary : kTextPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(label, style: AppTextStyles.bodyRegular15),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetShell(
      child: Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filtrer les lieux', style: AppTextStyles.baloo22),
              SizedBox(height: 36.h),
              _switch('100 % végane uniquement', _fullyVeganOnly,
                  (v) => setState(() => _fullyVeganOnly = v)),
              _switch('Ouvert maintenant', _openNow,
                  (v) => setState(() => _openNow = v)),
              _switch('Sans supplément lait végétal', _noSurcharge,
                  (v) => setState(() => _noSurcharge = v)),
              SizedBox(height: 24.h),
              Text('Sur place, à emporter, livraison',
                  style: AppTextStyles.bodyBold15),
              SizedBox(height: 18.h),
              Wrap(
                spacing: 18.w,
                runSpacing: 18.h,
                children: [
                  for (final (value, label) in RestaurantServiceOptions.all)
                    _tagChip(_serviceOptions, value, label),
                ],
              ),
              SizedBox(height: 36.h),
              Text('Type de lieu', style: AppTextStyles.bodyBold15),
              SizedBox(height: 18.h),
              Wrap(
                spacing: 18.w,
                runSpacing: 18.h,
                children: [
                  for (final (value, label) in RestaurantTags.all)
                    _tagChip(_tags, value, label,
                        icon: restaurantTagIcon(value),
                        iconColor: restaurantTagColor(value)),
                ],
              ),
              SizedBox(height: 48.h),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Réinitialiser',
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.grey[700]!,
                      borderColor: kBorderDefault,
                      onPressed: () => Navigator.of(context)
                          .pop(const RestaurantMapFilters()),
                    ),
                  ),
                  SizedBox(width: 20.w),
                  Expanded(
                    child: AppButton(
                      label: 'Appliquer',
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      onPressed: () => Navigator.of(context).pop(
                        RestaurantMapFilters(
                          tags: _tags,
                          serviceOptions: _serviceOptions,
                          fullyVeganOnly: _fullyVeganOnly,
                          openNow: _openNow,
                          noPlantMilkSurcharge: _noSurcharge,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
