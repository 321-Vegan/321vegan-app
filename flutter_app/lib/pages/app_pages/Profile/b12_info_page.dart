import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../themes/app_spacing.dart';
import '../../../themes/app_text_styles.dart';
import '../../../widgets/shared/app_background.dart';
import '../../../widgets/shared/info_box.dart';

/// Full-screen "Plus d'informations" page explaining B12 supplementation —
/// content validated by Astrid Prévost (dietician), reached from the "Plus
/// d'informations" row in Paramètres › B12 (and from the B12 reminder
/// settings page).
class B12InfoPage extends StatelessWidget {
  const B12InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Plus d\'informations', style: AppTextStyles.baloo22),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal, 8.h, AppSpacing.pageHorizontal, 32.h),
            children: [
              const InfoBox(
                iconAsset: 'lib/assets/images/icons/solid-check.webp',
                text: 'Informations validées par Astrid Prévost, '
                    'diététicienne spécialisée en nutrition végétale. '
                    'Instagram : @astrid_nutrition_militante',
              ),
              SizedBox(height: AppSpacing.item),
              const InfoBox(
                iconAsset: 'lib/assets/images/icons/alert-circle.webp',
                text: 'Ces informations sont à titre indicatif et ne se '
                    'substituent pas à un avis médical.',
              ),
              SizedBox(height: AppSpacing.section),
              _buildSection(
                'Pourquoi prendre un complément ?',
                'La complémentation en vitamine B12 est essentielle car '
                    'cette vitamine est absente de l\'alimentation végétale. '
                    'Sans complémentation, une carence arrivera tôt ou tard '
                    'et peut avoir des conséquences graves.',
              ),
              SizedBox(height: AppSpacing.section),
              _buildDosageSection(),
              SizedBox(height: AppSpacing.section),
              _buildSection(
                'Pour une bonne absorption',
                'La prise quotidienne permet une meilleure absorption et, '
                    'hormis les adultes en bonne santé, toutes les '
                    'catégories de population devraient la privilégier.\n\n'
                    'Pour une absorption optimale, le mieux est de prendre '
                    'sa B12 pendant ou après un repas.\n\n'
                    'La spiruline ne contient pas de B12 et en limite '
                    'l\'absorption. Si vous en prenez le matin, prenez votre '
                    'B12 le soir, et inversement.',
              ),
              SizedBox(height: AppSpacing.section),
              _buildSection(
                'Où trouver la B12 ?',
                'Pour une prise quotidienne, la Veg1 est très populaire et '
                    'contient d\'autres vitamines. Pour une prescription '
                    'médicale remboursable, vous pouvez demander les '
                    'ampoules de Gerda à votre médecin (attention, la forme '
                    'en comprimés contient du lactose).',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.baloo22),
        SizedBox(height: AppSpacing.afterTitle),
        Text(
          body,
          style: AppTextStyles.bodyRegular13.copyWith(
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDosageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dosages recommandés', style: AppTextStyles.baloo22),
        SizedBox(height: AppSpacing.afterTitle),
        Text.rich(
          TextSpan(
            style: AppTextStyles.bodyRegular13.copyWith(
              color: Colors.grey[700],
              height: 1.6,
            ),
            children: [
              const TextSpan(
                text: '•  Par jour : 25 µg\n'
                    '•  Par semaine : 2000 µg (en une prise)\n'
                    '•  Tous les 15 jours : 5000 µg (en une prise)\n\n',
              ),
              TextSpan(
                text: 'Pour les enfants : de 6 à 24 mois doses divisées '
                    'par 4, de 2 à 12 ans doses divisées par 2.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 36.sp,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
