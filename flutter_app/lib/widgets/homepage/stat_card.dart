import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vegan_app/models/seasonal_theme.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/widgets/shared/info_box.dart';

/// Definition of one impact stat, shared between the home page cards and the
/// share card.
class HomeStat {
  /// Key into the savings map computed by the home page.
  final String savingsKey;
  final String title;
  final String unitName;
  final IconData icon;
  final Color iconColor;
  final Color cardColor;
  final String info;

  /// Illustration shown on the Dashboard stat card and the info dialog.
  final String illustration;

  const HomeStat({
    required this.savingsKey,
    required this.title,
    required this.unitName,
    required this.icon,
    required this.iconColor,
    required this.cardColor,
    required this.info,
    required this.illustration,
  });
}

const List<HomeStat> homeStats = [
  HomeStat(
    savingsKey: 'animalUnit',
    title: 'Animaux épargnés',
    unitName: '',
    icon: Icons.favorite,
    iconColor: Color.fromARGB(247, 255, 103, 153),
    cardColor: Colors.pinkAccent,
    illustration: 'lib/assets/images/stat-cards/animals.webp',
    info:
        "L'industrie de l'élevage cause d'immenses souffrances aux animaux en les considérant comme des objets.\n\nChoisir le véganisme, c'est refuser cette exploitation.\n\nIci, on souligne l'effet positif que chacun peut avoir pour un monde plus juste et durable.",
  ),
  HomeStat(
    savingsKey: 'co2Unit',
    title: 'CO₂ non émis',
    unitName: 'kg',
    icon: Icons.arrow_downward_sharp,
    iconColor: Color.fromARGB(255, 255, 133, 133),
    cardColor: Colors.redAccent,
    illustration: 'lib/assets/images/stat-cards/co2.webp',
    info:
        "L'alimentation végétale a aussi un impact sur l'environnement et permet de réduire considérablement son empreinte carbone.\n\nLa quantité de CO2 économisée vient du fait que l'élevage est l'une des principales sources d'émission de gaz à effet de serre, de déforestation, de pollution de l'air et de pollution de l'eau.",
  ),
  HomeStat(
    savingsKey: 'forestUnit',
    title: 'Forêt préservée',
    unitName: 'm²',
    icon: Icons.forest_sharp,
    iconColor: Color.fromARGB(127, 105, 240, 175),
    cardColor: Color.fromARGB(197, 36, 139, 87),
    illustration: 'lib/assets/images/stat-cards/forest.webp',
    info:
        "L'élevage est l'une des principales causes de déforestation. Il faut en effet énormément de place pour cultiver les céréales (notamment soja et maïs) destinés à nourrir les animaux d'élevage.\n\nCette déforestation a des conséquences désastreuses sur la biodiversité et les communautés locales.\n\nAdopter une alimentation végétale c'est réduire la pression sur les forêts et à encourager une agriculture plus durable.",
  ),
  HomeStat(
    savingsKey: 'waterUnit',
    title: 'Eau économisée',
    unitName: 'm³',
    icon: Icons.water_drop,
    iconColor: Color.fromARGB(255, 97, 166, 250),
    cardColor: Colors.blueAccent,
    illustration: 'lib/assets/images/stat-cards/water.webp',
    info:
        "En choisissant d'être végétalien, vous aidez à économiser de précieuses ressources en eau.\n\nLa production de produits animaux nécessite une gigantesque quantité d'eau, notamment pour l'irrigation des cultures pour les animaux d'élevage.\n\nEt cela sans parler de la pollution de l'eau due aux déjections qu'ils produisent.",
  ),
];

Widget buildStatCard(
  BuildContext context,
  HomeStat stat,
  int value,
) {
  final title = stat.title;
  final unit = value;
  final unitName = stat.unitName;
  final icon = stat.icon;
  final iconColor = stat.iconColor;
  final seasonal = Theme.of(context).extension<SeasonalTheme>();
  final showIceDecoration =
      seasonal?.season == Season.winter && stat.savingsKey == 'co2Unit';
  // Figma spec: width 355, height hug (~104), radius 12, stroke 1,
  // padding 7 (v) / 13 (h), gap 10 — all ×3 for ScreenUtil units.
  final card = InkWell(
    customBorder: squircleBorder(radius: 12),
    onTap: () {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatInfoDialog(stat: stat, value: value),
      );
    },
    // Spacing between cards is owned by the Dashboard column (AppSpacing),
    // so the card carries no outer margin.
    child: Container(
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 36.r,
          side: const BorderSide(color: kBorderDefault, width: 1),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 39.w, vertical: 21.h),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    unitName.isEmpty ? '$unit' : '$unit $unitName',
                    key: ValueKey<int>(unit),
                    style: TextStyle(
                      fontSize: 64.sp,
                      color: Colors.grey[850],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 42.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 30.w),
          SizedBox(
            width: 270.w,
            height: 270.w,
            child: Image.asset(
              stat.illustration,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 110.sp),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  if (!showIceDecoration) return card;

  return Stack(
    clipBehavior: Clip.none,
    children: [
      card,
      // A small icicle drip in the top-left corner, clipped to the card's
      // own corner radius so square image corners don't peek out past the
      // squircle.
      Positioned(
        top: -50.h,
        left: 0,
        child: IgnorePointer(
          child: ClipPath(
            clipper: ShapeBorderClipper(
              shape: squircleBorderOnly(topLeft: 36.r),
            ),
            child: Image.asset(
              'lib/assets/themes/ice_8.webp',
              width: 580.w,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topLeft,
            ),
          ),
        ),
      ),
    ],
  );
}

/// Info dialog for one impact stat
class StatInfoDialog extends StatelessWidget {
  final HomeStat stat;
  final int value;

  const StatInfoDialog({
    required this.stat,
    required this.value,
    super.key,
  });

  Future<void> _openSources() async {
    final url = Uri.parse('https://321vegan.fr/sources');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final valueLabel =
        '$value ${stat.unitName}'.trim().replaceAll(RegExp(r'\s+'), ' ');
    // Figma spec: fixed width 390, radius 12 (top corners), padding 7 (top) /
    // 17 (h), gap 20 between children — ×3 for ScreenUtil units.
    return Container(
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorderOnly(topLeft: 36.r, topRight: 36.r),
      ),
      padding: EdgeInsets.fromLTRB(
          51.w, 21.h, 51.w, MediaQuery.of(context).viewInsets.bottom + 60.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 60.h),
          // Value + title merged into one heading
          Text(
            '$valueLabel ${stat.title}',
            style: TextStyle(
              fontSize: 56.sp,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 60.h),
          // Illustration (same as the card)
          SizedBox(
            height: 260.w,
            child: Image.asset(stat.illustration, fit: BoxFit.contain),
          ),
          SizedBox(height: 60.h),
          // Explanation
          Flexible(
            child: SingleChildScrollView(
              child: Text(
                stat.info,
                style: TextStyle(
                  fontSize: 42.sp,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(height: 60.h),
          // Sources info box
          const InfoBox(
            text:
                'Les calculs sont des estimations basées sur des moyennes issues d\'études scientifiques.',
          ),
          SizedBox(height: 60.h),
          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _openSources,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentYellow,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    'Sources',
                    style: TextStyle(
                      fontSize: 44.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    'D\'acc !',
                    style: TextStyle(
                      fontSize: 44.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
