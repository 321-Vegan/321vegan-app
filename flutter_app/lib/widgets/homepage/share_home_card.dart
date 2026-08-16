import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vegan_app/helpers/time_counter/time_counter.dart';
import 'package:vegan_app/models/seasonal_theme.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/widgets/homepage/stat_card.dart';

/// The image that gets shared: the home page (counter + stats) inside a phone
/// mockup, branded 321 Vegan, decorated with a seasonal theme. Uses fixed
/// logical sizes (no ScreenUtil) so the captured image is identical on every
/// device.
class ShareHomeCard extends StatelessWidget {
  final DateTime targetDate;
  final Map<String, int> savings;
  final SeasonalTheme theme;

  const ShareHomeCard({
    required this.targetDate,
    required this.savings,
    required this.theme,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('lib/assets/white_icon.png', width: 42, height: 42),
              const SizedBox(width: 10),
              const Text(
                '321 Vegan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Baloo2',
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPhoneMockup(),
          const SizedBox(height: 14),
          const Text(
            'Vous connaissez 321 Vegan ?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Baloo2',
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              _FeatureChip('🌱 Voir son impact'),
              _FeatureChip('📷 Scanner les produits'),
              _FeatureChip('💸 Des réductions'),
              _FeatureChip('🤝 Communautaire'),
              _FeatureChip('❤️ Gratuit'),
              _FeatureChip('💻 Open source'),
            ],
          ),
        ],
      ),
    );
  }

  /// Same background the real home page shows for [theme]: its own seasonal
  /// gradient, or the app's default cream gradient outside a season — see
  /// AppBackground, which this mirrors.
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
    return Container(
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
          height: 415,
          child: Stack(
            children: [
              // Real home page background for this card's season.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: _phoneBackgroundGradient),
                ),
              ),
              Column(
                children: [
                  // Clears the notch.
                  const SizedBox(height: 40),
                  const Text(
                    'Je suis végane depuis',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1,
                      color: kTextPrimary,
                      fontFamily: 'Baloo2',
                    ),
                  ),
                  _buildCounter(),
                  const SizedBox(height: 6),
                  ...homeStats.map(
                    (stat) =>
                        _miniStatCard(stat, savings[stat.savingsKey] ?? 0),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: squircleBorder(
                        radius: 20,
                        side: const BorderSide(color: kBorderDefault),
                      ),
                    ),
                    child: Text(
                      'Depuis le ${DateFormat('dd/MM/yyyy').format(targetDate)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'Baloo2',
                        letterSpacing: -1,
                        color: kTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
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
    );
  }

  Widget _buildCounter() {
    final breakdown = TimeBreakdown.between(targetDate, DateTime.now());
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _counterColumn('${breakdown.years}', 'ans'),
        const SizedBox(width: 8),
        _counterColumn('${breakdown.months}', 'mois'),
        const SizedBox(width: 8),
        _counterColumn('${breakdown.days}', 'jours'),
        const SizedBox(width: 8),
        _counterColumn('${breakdown.hours}', 'heures'),
        const SizedBox(width: 8),
        _counterColumn('${breakdown.minutes}', 'min'),
      ],
    );
  }

  Widget _counterColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value.padLeft(2, '0'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: kTextPrimary,
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -4),
          child: Text(
            label,
            style: const TextStyle(fontSize: 8, color: kTextPrimary),
          ),
        ),
      ],
    );
  }

  /// Mini version of the redesigned Dashboard stat card: white surface,
  /// hairline border, value + title on the left, illustration on the right.
  Widget _miniStatCard(HomeStat stat, int value) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    fontSize: 14,
                    color: Colors.grey[850],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  stat.title,
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            height: 40,
            child: Image.asset(
              seasonalStatIllustration(stat, theme.season),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: BoxDecoration(
                  color: stat.iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(stat.icon, color: stat.iconColor, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;

  const _FeatureChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontFamily: 'Baloo2',
          letterSpacing: -1,
        ),
      ),
    );
  }
}
