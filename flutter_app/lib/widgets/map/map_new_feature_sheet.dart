import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/bottom_sheet_shell.dart';
import '../shared/info_box.dart';

/// What [MapNewFeatureSheet] pops with, for the map to carry it out.
enum MapNewFeatureAction { addPlace, openSelections }

const _ways = [
  (
    Icons.add_location_alt_outlined,
    'Ajoutez les lieux que vous connaissez',
    null
  ),
  (
    Icons.add_a_photo_outlined,
    'Partagez des photos du lieu et des plats',
    null
  ),
  (
    Icons.edit_outlined,
    'Proposez une modification depuis la fiche d\'un lieu',
    null
  ),
  (Icons.star_border, 'Mettez des avis sur les restaurants', null),
  (
    Icons.bookmark_border,
    'Créez des sélections publiques pour partager vos lieux préférés avec '
        'la communauté',
    MapNewFeatureAction.openSelections,
  ),
];

/// Explains that the restaurants map is new, hence still sparse, and how to
/// help fill it. Pops a [MapNewFeatureAction] when one of its links is
/// tapped (add a place, open the selections).
class MapNewFeatureSheet extends StatelessWidget {
  const MapNewFeatureSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return BottomSheetShell(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Image.asset(
                'lib/assets/images/characters/radish.webp',
                height: 220.h,
              ),
            ),
            SizedBox(height: 36.h),
            Center(
              child: Text(
                'Une carte toute neuve !',
                style: AppTextStyles.baloo26,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'La carte des restaurants vient d\'arriver : il y a encore peu '
              'de lieux et d\'informations. Elle va grandir grâce à vous, '
              'toute contribution est la bienvenue !',
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.bodyRegular15.copyWith(color: Colors.grey[600]),
            ),
            SizedBox(height: 48.h),
            for (final (icon, text, action) in _ways) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: action == null
                    ? null
                    : () => Navigator.of(context).pop(action),
                child: Row(
                  children: [
                    Icon(icon, color: primary, size: 64.sp),
                    SizedBox(width: 30.w),
                    Expanded(
                      child: Text(
                        text,
                        style: AppTextStyles.bodyMedium15.copyWith(
                          color: action == null ? kTextPrimary : primary,
                          decoration:
                              action == null ? null : TextDecoration.underline,
                          decorationColor: primary,
                        ),
                      ),
                    ),
                    if (action != null)
                      Icon(Icons.chevron_right, color: primary, size: 64.sp),
                  ],
                ),
              ),
              SizedBox(height: 30.h),
            ],
            SizedBox(height: 18.h),
            const InfoBox(
              text: 'Plus vous renseignez d\'infos en créant un lieu '
                  '(horaires, contact, photos, options…), plus vous nous '
                  'aidez !',
            ),
            SizedBox(height: 48.h),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Ajouter un lieu',
                icon: Icons.add_location_alt_outlined,
                backgroundColor: primary,
                onPressed: () =>
                    Navigator.of(context).pop(MapNewFeatureAction.addPlace),
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Compris',
                backgroundColor: Colors.white,
                foregroundColor: Colors.grey[700]!,
                borderColor: kBorderDefault,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
