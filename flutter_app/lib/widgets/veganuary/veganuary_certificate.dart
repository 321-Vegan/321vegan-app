import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../helpers/image_capture.dart';
import '../../services/auth_service.dart';
import '../../services/veganuary_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import '../shared/app_text_field.dart';
import '../shared/bottom_sheet_shell.dart';
import 'veganuary_story_share.dart';

const String _appIcon = 'lib/assets/app_icon.png';

/// The certificate with one's name: a sheet to type it, then the share
/// sheet. Dated the day the course was finished.
Future<void> showVeganuaryCertificateSheet(BuildContext context) async {
  final progress = await VeganuaryService.loadProgress();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CertificateSheet(
      date: progress.completedAt[VeganuaryService.totalDays] ?? DateTime.now(),
    ),
  );
}

/// On the page of the last day, in place of the progress to share: a card
/// showing the certificate, tapped to get it with one's name (a sheet to
/// type it, then the share sheet).
class VeganuaryCertificateButton extends StatelessWidget {
  const VeganuaryCertificateButton({super.key});

  @override
  Widget build(BuildContext context) {
    final shape = squircleBorder(
      radius: 60.r,
      side: BorderSide(color: kAccentYellow.withValues(alpha: 0.3), width: 1.5),
    );
    return Semantics(
      button: true,
      label: 'Obtenir mon certificat du parcours',
      excludeSemantics: true,
      child: Material(
        color: kSecondaryTag,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: shape,
          onTap: () => showVeganuaryCertificateSheet(context),
          child: Padding(
            padding: EdgeInsets.fromLTRB(36.w, 36.h, 40.w, 36.h),
            child: Row(
              children: [
                // What will be shared: the certificate, tilted
                Transform.rotate(
                  angle: -0.08,
                  child: SizedBox(
                    height: 330.h,
                    child: FittedBox(
                      child: _CertificatePreview(
                        name: AuthService.currentUser?.nickname ?? '',
                        date: DateTime.now(),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 44.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Votre certificat', style: AppTextStyles.baloo22),
                      SizedBox(height: 8.h),
                      Text(
                        'À votre nom, pour fêter ces '
                        '${VeganuaryService.totalDays} jours : à partager '
                        'ou à garder.',
                        style: AppTextStyles.bodyRegular13
                            .copyWith(color: Colors.grey[700], height: 1.3),
                      ),
                      SizedBox(height: 28.h),
                      AppButton(
                        label: 'Mon certificat',
                        compact: true,
                        backgroundColor: kAccentYellow,
                        onPressed: () => showVeganuaryCertificateSheet(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The certificate as it will be shared, under the name to write on it.
class _CertificateSheet extends StatefulWidget {
  final DateTime date;

  const _CertificateSheet({required this.date});

  @override
  State<_CertificateSheet> createState() => _CertificateSheetState();
}

class _CertificateSheetState extends State<_CertificateSheet> {
  late final _name =
      TextEditingController(text: AuthService.currentUser?.nickname ?? '');
  bool _sharing = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _share(BuildContext buttonContext) async {
    if (_sharing) return;
    FocusScope.of(context).unfocus();
    setState(() => _sharing = true);
    try {
      final files = await captureOffscreen(
        context,
        width: VeganuaryCertificateCard.size.width,
        images: {
          'parcours-321-vegan-certificat': VeganuaryCertificateCard(
            name: _name.text.trim(),
            date: widget.date,
          ),
        },
        precache: [const AssetImage(_appIcon)],
        // 360 × 640 drawn at 3×: 1080 × 1920, the size of a story
        pixelRatio: VeganuaryCertificateCard.pixelRatio,
      );
      if (files.isEmpty || !buttonContext.mounted) return;
      await shareImageFiles(
        buttonContext,
        files,
        text: "J'ai terminé les ${VeganuaryService.totalDays} jours du "
            "parcours de l'app 321 Vegan, disponible sur iOS et Android 🌱 "
            'https://321vegan.fr',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Above the keyboard
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: BottomSheetShell(
        padding: EdgeInsets.fromLTRB(
            60.w, 12.h, 60.w, MediaQuery.of(context).padding.bottom + 48.h),
        child: Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 900.h,
                  child: FittedBox(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _name,
                      builder: (_, value, __) => _CertificatePreview(
                        name: value.text.trim(),
                        date: widget.date,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 48.h),
                AppTextField(
                  controller: _name,
                  labelText: 'Votre nom sur le certificat',
                  hintText: 'Prénom, pseudo…',
                  maxLength: 30,
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: 36.h),
                Builder(
                  // Own context: the share popover (iPad) points at the button
                  builder: (buttonContext) => AppButton(
                    label: 'Partager le certificat',
                    backgroundColor: kAccentYellow,
                    disabledBackgroundColor: kAccentYellow,
                    isLoading: _sharing,
                    onPressed: _sharing ? null : () => _share(buttonContext),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [VeganuaryCertificateCard] shown in the app: a shadow around it, the
/// same whatever the phone's text size.
class _CertificatePreview extends StatelessWidget {
  final String name;
  final DateTime date;

  const _CertificatePreview({required this.name, required this.date});

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: squircleBorder(radius: 28),
          shadows: [
            BoxShadow(
              color: kTextPrimary.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipSmoothRect(
          radius: squircleRadius(28),
          child: VeganuaryCertificateCard(name: name, date: date),
        ),
      ),
    );
  }
}

/// The certificate image, the size of a story: a framed sheet saying
/// [name] did the whole course, with the [date] it was finished and the
/// app at its bottom. Its sizes are plain logical pixels of [size], not
/// ScreenUtil's (an image, the same on every phone); its top and bottom are
/// left for Instagram's header and reply bar. Without a name, it's written
/// in the first person.
class VeganuaryCertificateCard extends StatelessWidget {
  static const Size size = Size(360, 640);
  static const double pixelRatio = 3;

  final String name;
  final DateTime date;

  const VeganuaryCertificateCard({
    super.key,
    required this.name,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    const days = VeganuaryService.totalDays;
    final grey = AppTextStyles.bodyRegular13
        .copyWith(fontSize: 14, height: 1.4, color: Colors.grey[700]);
    const text = "suivi les $days jours du parcours : des infos, des idées "
        'reçues démontées et de nouvelles recettes chaque jour.';
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        size: size,
        child: ColoredBox(
          color: kBackgroundGradientBottom,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 48, 18, 48),
            child: Column(
              children: [
                Expanded(
                  // A double frame, like a diploma's
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: squircleBorder(
                        radius: 28,
                        side:
                            const BorderSide(color: kAccentYellow, width: 2.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          shape: squircleBorder(
                            radius: 22,
                            side: BorderSide(
                                color: kAccentYellow.withValues(alpha: 0.4)),
                          ),
                        ),
                        child: CustomPaint(
                          painter: const _ConfettiPainter(),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 26, 18, 14),
                            child: Column(
                              children: [
                                const _Party(),
                                const SizedBox(height: 14),
                                Text(
                                  'CERTIFICAT',
                                  style: AppTextStyles.bodyBold13.copyWith(
                                      fontSize: 13,
                                      letterSpacing: 4,
                                      color: kAccentYellow),
                                ),
                                Text(
                                  'Parcours\n321 Vegan',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.baloo26
                                      .copyWith(fontSize: 46),
                                ),
                                const Spacer(),
                                if (name.isNotEmpty) ...[
                                  Text('Ce certificat atteste que',
                                      style: grey),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      style: AppTextStyles.baloo30Bold.copyWith(
                                          fontSize: 30, letterSpacing: 0),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                Text(
                                  name.isNotEmpty ? 'a $text' : "J'ai $text",
                                  textAlign: TextAlign.center,
                                  style: name.isNotEmpty
                                      ? grey
                                      : grey.copyWith(
                                          fontSize: 16, color: kTextPrimary),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '$days / $days jours · parcours complet !',
                                  style: AppTextStyles.baloo30Bold.copyWith(
                                      fontSize: 17,
                                      letterSpacing: 0,
                                      color: kAccentYellow),
                                ),
                                Text(
                                  'Le ${DateFormat('d MMMM y', 'fr_FR').format(date)}'
                                      .replaceFirst(
                                          RegExp(r'^Le 1 '), 'Le 1er '),
                                  style: AppTextStyles.bodyItalic12.copyWith(
                                      fontSize: 11.5, color: Colors.grey[600]),
                                ),
                                const Spacer(),
                                const SizedBox(height: 10),
                                const VeganuaryAppName(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The trophy, between the cow and the watermelon in party hats.
class _Party extends StatelessWidget {
  const _Party();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(width: 10),
        Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kAccentYellow,
            border: Border.all(color: kSecondaryTag, width: 4),
          ),
          child: const FaIcon(FontAwesomeIcons.trophy,
              size: 34, color: Colors.white),
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}

/// Confetti scattered along the frame's edges, the same every time.
class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter();

  // x, y (fractions of the frame), angle, color, round
  static const _pieces = [
    (0.08, 0.04, 0.6, kAccentYellow, false),
    (0.20, 0.10, -0.4, kLogoGreen, true),
    (0.05, 0.17, 1.1, kVeganOptionsOrange, false),
    (0.15, 0.25, 0.2, kAccentYellow, true),
    (0.92, 0.05, -0.7, kLogoGreen, false),
    (0.80, 0.11, 0.3, kVeganOptionsOrange, true),
    (0.95, 0.18, 0.9, kAccentYellow, false),
    (0.85, 0.26, -0.2, kLogoGreen, true),
    (0.04, 0.40, -0.9, kLogoGreen, false),
    (0.96, 0.43, 0.5, kVeganOptionsOrange, false),
    (0.06, 0.62, 0.4, kAccentYellow, true),
    (0.94, 0.66, -0.5, kAccentYellow, false),
    (0.07, 0.86, 0.8, kVeganOptionsOrange, false),
    (0.15, 0.94, -0.3, kLogoGreen, true),
    (0.93, 0.88, -1.0, kLogoGreen, false),
    (0.84, 0.95, 0.4, kAccentYellow, true),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, angle, color, round) in _pieces) {
      final paint = Paint()..color = color.withValues(alpha: 0.8);
      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      canvas.rotate(angle);
      if (round) {
        canvas.drawCircle(Offset.zero, 2.6, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: 9, height: 4),
              const Radius.circular(1)),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => false;
}
