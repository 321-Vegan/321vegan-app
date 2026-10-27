import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/bottom_sheet_shell.dart';
import '../shared/page_dots_indicator.dart';

class _Step {
  final String image;
  final String title;
  final String text;

  const _Step({required this.image, required this.title, required this.text});
}

const _steps = [
  _Step(
    image: 'lib/assets/images/characters/cow-ok.webp',
    title: 'Vos lieux sauvegardés',
    text: 'Sauvegardez un lieu depuis sa fiche pour le retrouver ici. '
        'Enregistrez autant de lieux que vous souhaitez !',
  ),
  _Step(
    image: 'lib/assets/images/characters/avocado.webp',
    title: 'Vos sélections',
    text: 'Rassemblez vos adresses préférées dans une sélection, avec un mot '
        'pour chacune et une image de couverture. Envoyez-la à vos proches '
        'par e-mail ou avec leur code ami.',
  ),
  _Step(
    image: 'lib/assets/images/characters/tomatoes.webp',
    title: 'Coups de 🖤 de la communauté',
    text: 'Rendez une sélection publique pour la partager avec tout le '
        'monde. Découvrez celles des autres et abonnez-vous à vos '
        'préférées.',
  ),
];

/// First-visit intro sheet of the saved places page, in a few swipeable
/// steps, shown once like [VegandexWelcomeModal]. Pops `true` when closed
/// with "C'est parti !" on the last step so the caller can mark it as seen
/// for good; swiping the sheet away leaves it to show again next time.
class SavedPlacesWelcomeModal extends StatefulWidget {
  const SavedPlacesWelcomeModal({super.key});

  @override
  State<SavedPlacesWelcomeModal> createState() =>
      _SavedPlacesWelcomeModalState();
}

class _SavedPlacesWelcomeModalState extends State<SavedPlacesWelcomeModal> {
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        step.title,
                        style: AppTextStyles.baloo26,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 48.h),
                      Image.asset(step.image, height: 380.h),
                      SizedBox(height: 48.h),
                      Text(
                        step.text,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyRegular15
                            .copyWith(color: Colors.grey[600]),
                      ),
                    ],
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
