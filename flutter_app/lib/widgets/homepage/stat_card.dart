import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vegan_app/models/seasonal_theme.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/widgets/theme/snow_globe_overlay.dart';

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

  /// Illustration shown on the Dashboard stat card.
  final String illustration;

  /// Avatar shown in the info dialog.
  final String avatar;

  const HomeStat({
    required this.savingsKey,
    required this.title,
    required this.unitName,
    required this.icon,
    required this.iconColor,
    required this.cardColor,
    required this.info,
    required this.illustration,
    required this.avatar,
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
    avatar: 'lib/assets/avatars/cochon.png',
    info:
        "L'industrie de l'élevage cause d'immenses souffrances aux animaux en les considérant comme des objets. Choisir le véganisme, c'est refuser cette exploitation. Ici, on souligne l'effet positif que chacun peut avoir pour un monde plus juste et durable.",
  ),
  HomeStat(
    savingsKey: 'co2Unit',
    title: 'CO₂ non émis',
    unitName: 'kg',
    icon: Icons.arrow_downward_sharp,
    iconColor: Color.fromARGB(255, 255, 133, 133),
    cardColor: Colors.redAccent,
    illustration: 'lib/assets/images/stat-cards/co2.webp',
    avatar: 'lib/assets/avatars/canard.png',
    info:
        "L'alimentation végétale a aussi un impact sur l'environnement et permet de réduire considérablement son empreinte carbone. La quantité de CO2 économisée vient du fait que l'élevage est l'une des principales sources d'émission de gaz à effet de serre, de déforestation, de pollution de l'air et de pollution de l'eau.",
  ),
  HomeStat(
    savingsKey: 'forestUnit',
    title: 'Forêt préservée',
    unitName: 'm²',
    icon: Icons.forest_sharp,
    iconColor: Color.fromARGB(127, 105, 240, 175),
    cardColor: Color.fromARGB(197, 36, 139, 87),
    illustration: 'lib/assets/images/stat-cards/forest.webp',
    avatar: 'lib/assets/avatars/lapin.png',
    info:
        "L'élevage est l'une des principales causes de déforestation. Il faut en effet énormément de place pour cultiver les céréales (notamment soja et maïs) destinés à nourrir les animaux d'élevage. Cette déforestation a des conséquences désastreuses sur la biodiversité et les communautés locales. Adopter une alimentation végétale c'est réduire la pression sur les forêts et à encourager une agriculture plus durable.",
  ),
  HomeStat(
    savingsKey: 'waterUnit',
    title: 'Eau économisée',
    unitName: 'm³',
    icon: Icons.water_drop,
    iconColor: Color.fromARGB(255, 97, 166, 250),
    cardColor: Colors.blueAccent,
    illustration: 'lib/assets/images/stat-cards/water.webp',
    avatar: 'lib/assets/avatars/poisson.png',
    info:
        "En choisissant d'être végétalien, vous aidez à économiser de précieuses ressources en eau. La production de produits animaux nécessite une gigantesque quantité d'eau, notamment pour l'irrigation des cultures pour les animaux d'élevage. Et cela sans parler de la pollution de l'eau due aux déjections qu'ils produisent.",
  ),
];

Widget buildStatCard(
  BuildContext context,
  HomeStat stat,
  int value, {
  SeasonalTheme? theme,
}) {
  final title = stat.title;
  final unit = value;
  final unitName = stat.unitName;
  final icon = stat.icon;
  final iconColor = stat.iconColor;
  // Figma spec: width 355, height hug (~104), radius 12, stroke 1,
  // padding 7 (v) / 13 (h), gap 10 — all ×3 for ScreenUtil units.
  return InkWell(
    borderRadius: BorderRadius.circular(36.r),
    onTap: () {
      showDialog(
        context: context,
        builder: (context) => StatInfoDialog(stat: stat, value: value),
      );
    },
    // Spacing between cards is owned by the Dashboard column (AppSpacing),
    // so the card carries no outer margin.
    child: _maybeSnowGlobe(
      theme: theme,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(36.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              offset: const Offset(0, 4),
              blurRadius: 16,
            ),
          ],
          border: Border.all(color: kBorderDefault, width: 1),
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
    ),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
      child: Container(
        padding: EdgeInsets.all(32.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar
            Container(
              width: 240.w,
              height: 240.w,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: stat.cardColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Image.asset(stat.avatar, fit: BoxFit.contain),
            ),
            SizedBox(height: 24.h),
            // Title
            Text(
              stat.title,
              style: TextStyle(
                fontSize: 56.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            // Current value badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: stat.cardColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                '$value ${stat.unitName}'.trim(),
                style: TextStyle(
                  color: stat.cardColor,
                  fontSize: 36.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(height: 16.h),
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
            SizedBox(height: 12.h),
            // Sources info box
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.blue.shade400, size: 42.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Les calculs sont des estimations basées sur des moyennes issues d\'études scientifiques.',
                      style: TextStyle(
                        fontSize: 36.sp,
                        color: Colors.blue.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32.h),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _openSources,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      side: BorderSide(color: Colors.grey[300]!, width: 2),
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'Sources',
                      style: TextStyle(
                        fontSize: 44.sp,
                        fontWeight: FontWeight.w500,
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
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'Fermer',
                      style: TextStyle(
                        fontSize: 44.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _maybeSnowGlobe({SeasonalTheme? theme, required Widget child}) {
  if (theme == null) return child;
  if (theme.snowGlobeParticleAsset == null &&
      theme.snowGlobeParticleIcon == null &&
      theme.particleType != ParticleType.snowflakes) {
    return child;
  }
  return SnowGlobeOverlay(
    particleAsset: theme.snowGlobeParticleAsset,
    particleIcon: theme.snowGlobeParticleIcon,
    particleCount: 12,
    child: child,
  );
}
