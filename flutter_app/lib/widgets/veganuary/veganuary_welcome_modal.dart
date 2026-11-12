import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/veganuary_service.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/bottom_sheet_shell.dart';
import '../shared/page_dots_indicator.dart';

const String veganuaryDisclaimer =
    'Les informations partagées dans ce parcours ne remplacent pas un avis '
    'médical ni le suivi par un·e diététicien·ne.';

const String veganuaryDisclaimerDetails =
    'Un accompagnement peut être utile pour tout changement d’alimentation, '
    'particulièrement pendant la grossesse et l’allaitement, pour les '
    'enfants, ou si vous avez un problème de santé. La nutrition végétale '
    'n’est pas toujours bien enseignée, et certain·es professionnel·les de '
    'santé n’ont pas les connaissances les plus récentes sur le sujet. '
    'N’hésitez pas à chercher un·e diététicien·ne formé·e ou habitué·e à '
    'l’alimentation végétale. Et si on vous déconseille ce mode '
    'd’alimentation, vous pouvez tout à fait consulter une autre personne '
    'mieux formée.';

class _Step {
  final String? image;
  final String title;
  final String text;

  /// Smaller, below [text].
  final String? details;

  const _Step({
    this.image,
    required this.title,
    required this.text,
    this.details,
  });
}

const _steps = [
  _Step(
    image: 'lib/assets/images/characters/watermelon.webp',
    title: 'Bienvenue dans le Veganuary !',
    text: '${VeganuaryService.totalDays} jours pour trouver les réponses aux '
        'questions qu’on se pose sur le véganisme et bien commencer : chaque '
        'jour, une info et une idée reçue à démonter, et une recette chaque '
        'semaine.',
  ),
  _Step(
    image: 'lib/assets/images/characters/cow-ok.webp',
    title: 'À votre rythme',
    text: 'Un nouveau jour se débloque chaque jour. Un jour manqué ? Pas de '
        'souci, vous pourrez le rattraper. L’essentiel de chaque semaine vous '
        'attend ensuite dans ses fiches récap’.',
  ),
  // No image: the text is long
  _Step(
    title: 'Avant de commencer',
    text: veganuaryDisclaimer,
    details: veganuaryDisclaimerDetails,
  ),
];

/// First-visit intro sheet of the Veganuary tab, in a few swipeable steps
/// ending with the health disclaimer, shown once. Pops `true` when closed
/// with "C'est parti !" on the last step so the caller can mark it as seen
/// for good; swiping the sheet away leaves it to show again next time.
class VeganuaryWelcomeModal extends StatefulWidget {
  const VeganuaryWelcomeModal({super.key});

  @override
  State<VeganuaryWelcomeModal> createState() => _VeganuaryWelcomeModalState();
}

class _VeganuaryWelcomeModalState extends State<VeganuaryWelcomeModal> {
  final _pageController = PageController();
  int _page = 0;

  bool get _isLast => _page == _steps.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      Navigator.of(context).pop(true);
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return BottomSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 900.h,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _steps.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) {
                final step = _steps[index];
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  // Scrolls on small screens (the disclaimer is long)
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Text(
                            step.title,
                            style: AppTextStyles.baloo26,
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 48.h),
                          if (step.image != null) ...[
                            Image.asset(step.image!, height: 380.h),
                            SizedBox(height: 48.h),
                          ],
                          Text(
                            step.text,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyRegular15
                                .copyWith(color: Colors.grey[600]),
                          ),
                          if (step.details != null) ...[
                            SizedBox(height: 24.h),
                            Text(
                              step.details!,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyRegular13
                                  .copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 24.h),
          PageDotsIndicator(
            count: _steps.length,
            currentIndex: _page,
            activeColor: primary,
          ),
          SizedBox(height: 48.h),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: _isLast ? "C'est parti !" : 'Suivant',
              backgroundColor: primary,
              onPressed: _next,
            ),
          ),
        ],
      ),
    );
  }
}
