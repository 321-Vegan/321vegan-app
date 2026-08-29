import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:vegan_app/helpers/time_counter/time_counter.dart';
import 'package:vegan_app/models/seasonal_theme.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/homepage/stat_card.dart';

/// The four shareable looks for [ShareHomeCard]: [dark] is the original
/// seasonal-primary-colored card, [light] the cream/brand-green variant.
/// [darkMinimal]/[lightMinimal] swap the heading and feature chips for a
/// plain "321 Vegan" brand mark.
enum ShareCardStyle { dark, light, darkMinimal, lightMinimal }

/// The image that gets shared: the home page (counter + stats) inside a
/// phone mockup. Uses fixed logical sizes (no ScreenUtil) so the captured
/// image is identical on every device.
class ShareHomeCard extends StatelessWidget {
  final DateTime targetDate;
  final Map<String, int> savings;
  final SeasonalTheme theme;
  final ShareCardStyle style;

  const ShareHomeCard({
    required this.targetDate,
    required this.savings,
    required this.theme,
    this.style = ShareCardStyle.dark,
    super.key,
  });

  bool get _isLight =>
      style == ShareCardStyle.light || style == ShareCardStyle.lightMinimal;

  bool get _isMinimal =>
      style == ShareCardStyle.darkMinimal || style == ShareCardStyle.lightMinimal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        gradient: _isLight
            ? const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                stops: [0.0, 0.3],
                colors: [kBackgroundGradientTop, kBackgroundGradientBottom],
              )
            : LinearGradient(
                colors: [
                  Color.lerp(theme.primaryColor, Colors.black, 0.35)!,
                  theme.primaryColor,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPhoneMockup(),
          const SizedBox(height: 14),
          if (_isMinimal)
            _buildBrandMark()
          else ...[
            _buildHeading(),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                _FeatureChip('🌱 Voir son impact', light: _isLight),
                _FeatureChip('📷 Scanner les produits', light: _isLight),
                _FeatureChip('💸 Des réductions', light: _isLight),
                _FeatureChip('🤝 Communautaire', light: _isLight),
                _FeatureChip('❤️ Gratuit', light: _isLight),
                _FeatureChip('💻 Open source', light: _isLight),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeading() {
    final headingStyle = AppTextStyles.baloo22
        .copyWith(color: _isLight ? kTextPrimary : Colors.white);
    final brandStyle = AppTextStyles.baloo22
        .copyWith(color: _isLight ? theme.primaryColor : Colors.white);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Vous connaissez ', style: headingStyle),
        Image.asset(
          _isLight ? 'lib/assets/app_icon.png' : 'lib/assets/white_icon.png',
          width: 20,
          height: 20,
        ),
        const SizedBox(width: 4),
        Text('321 Vegan', style: brandStyle),
        Text(' ?', style: brandStyle),
      ],
    );
  }

  Widget _buildBrandMark() {
    final brandStyle = AppTextStyles.baloo22
        .copyWith(color: _isLight ? theme.primaryColor : Colors.white);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          _isLight ? 'lib/assets/app_icon.png' : 'lib/assets/white_icon.png',
          width: 22,
          height: 22,
        ),
        const SizedBox(width: 6),
        Text('321 Vegan', style: brandStyle),
      ],
    );
  }

  /// Mirrors AppBackground: [theme]'s seasonal gradient, or the app's
  /// default cream gradient outside a season.
  LinearGradient get _phoneBackgroundGradient {
    const defaultGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [kBackgroundGradientTop, kBackgroundGradientBottom],
    );
    final isSeasonal = theme.season != Season.defaultTheme;
    return isSeasonal
        ? (theme.backgroundGradient ?? defaultGradient)
        : defaultGradient;
  }

  Widget _buildPhoneMockup() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: ShapeDecoration(
            color: const Color(0xFF1F2937),
            shape: squircleBorder(radius: 38),
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipSmoothRect(
            radius: squircleRadius(30),
            child: SizedBox(
              width: 234,
              height: 473,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration:
                          BoxDecoration(gradient: _phoneBackgroundGradient),
                    ),
                  ),
                  Column(
                    children: [
                      // Clears the notch and the counter card above.
                      const SizedBox(height: 150),
                      ...homeStats.map(
                        (stat) =>
                            _miniStatCard(stat, savings[stat.savingsKey] ?? 0),
                      ),
                    ],
                  ),
                  // Notch
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 64,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Deliberately wider than the phone frame so it overflows past its
        // edges, giving the shared image a "zoomed in" pop-out look.
        Positioned(top: 34, child: _CounterCard(targetDate: targetDate)),
      ],
    );
  }

  Widget _miniStatCard(HomeStat stat, int value) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 12,
          side: const BorderSide(color: kBorderDefault),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.unitName.isEmpty ? '$value' : '$value ${stat.unitName}',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.grey[850],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  stat.title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: Image.asset(
              seasonalStatIllustration(stat, theme.season),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: BoxDecoration(
                  color: stat.iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(stat.icon, color: stat.iconColor, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Vous êtes vegan depuis" title + bordered digit-tile counter, mirroring
/// [VeganCounter]'s tile design at share-image scale.
class _CounterCard extends StatelessWidget {
  final DateTime targetDate;

  const _CounterCard({required this.targetDate});

  static const _units = ['ans', 'mois', 'jours', 'heures', 'min'];

  @override
  Widget build(BuildContext context) {
    final breakdown = TimeBreakdown.between(targetDate, DateTime.now());
    final values = [
      breakdown.years,
      breakdown.months,
      breakdown.days,
      breakdown.hours,
      breakdown.minutes,
    ];

    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(radius: 12),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Vous êtes végane depuis',
            textAlign: TextAlign.center,
            style: AppTextStyles.baloo22,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < values.length; i++)
                _tile(values[i], _units[i]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(int value, String label) {
    final text = value.toString().padLeft(2, '0');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: squircleBorder(
              radius: 6,
              side: const BorderSide(color: kBorderDefault),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _digit(text[0]),
                Container(width: 1, color: kBorderDefault),
                _digit(text[1]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _digit(String digit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: kTextPrimary,
          fontFamily: 'Baloo2',
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  final bool light;

  const _FeatureChip(this.label, {this.light = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: light ? kSecondaryTag : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: light ? Border.all(color: kAccentYellow) : null,
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyMedium11.copyWith(color: light ? kAccentYellow : Colors.white,)
      ),
    );
  }
}
