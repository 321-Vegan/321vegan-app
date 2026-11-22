import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../helpers/image_capture.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_button.dart';
import 'veganuary_step_views.dart';

const String _appIcon = 'lib/assets/app_icon.png';

/// "Partagez votre progression", on the page of a day just done: a card
/// showing the story's phone, tapped anywhere to share a story image of the
/// days done so far through the share sheet (Instagram offers to post it as
/// a story, other apps to send or save it).
class VeganuaryShareProgressButton extends StatefulWidget {
  final int day;
  final int totalDays;
  final Set<int> completedDays;

  /// The illustration of the done page (the week's badge once it's done).
  final String image;

  /// Number of the week, when this day finished it.
  final int? weekDone;

  const VeganuaryShareProgressButton({
    super.key,
    required this.day,
    required this.totalDays,
    required this.completedDays,
    required this.image,
    this.weekDone,
  });

  @override
  State<VeganuaryShareProgressButton> createState() =>
      _VeganuaryShareProgressButtonState();
}

class _VeganuaryShareProgressButtonState
    extends State<VeganuaryShareProgressButton> {
  bool _sharing = false;

  String get _shareText {
    final day = widget.day;
    const end = "avec l'app 321 Vegan, disponible sur iOS et Android 🌱 "
        'https://321vegan.fr';
    if (day >= widget.totalDays) {
      return "J'ai terminé les ${widget.totalDays} jours du Veganuary $end";
    }
    if (day == 1) return "J'ai commencé le Veganuary $end";
    return 'Jour $day du Veganuary $end';
  }

  Future<void> _share(BuildContext buttonContext) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final network = widget.image.startsWith('http');
      final files = await captureOffscreen(
        context,
        width: VeganuaryStoryCard.size.width,
        images: {
          'veganuary-jour-${widget.day}': VeganuaryStoryCard(
            day: widget.day,
            totalDays: widget.totalDays,
            completedDays: widget.completedDays,
            image: widget.image,
            weekDone: widget.weekDone,
          ),
        },
        precache: [
          network
              ? CachedNetworkImageProvider(widget.image)
              : AssetImage(widget.image),
          const AssetImage(_appIcon),
        ],
        settle: network ? const Duration(milliseconds: 700) : Duration.zero,
        // 360 × 640 drawn at 3×: 1080 × 1920, the size of a story
        pixelRatio: VeganuaryStoryCard.pixelRatio,
      );
      if (files.isEmpty || !buttonContext.mounted) return;

      await shareImageFiles(buttonContext, files, text: _shareText);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shape = squircleBorder(
      radius: 60.r,
      side: BorderSide(color: kAccentYellow.withValues(alpha: 0.3), width: 1.5),
    );
    // Own context: the share popover (iPad) points at the card
    return Builder(
      builder: (buttonContext) {
        final onTap = _sharing ? null : () => _share(buttonContext);
        return Semantics(
          button: true,
          label: 'Partager ma progression en story',
          excludeSemantics: true,
          child: Material(
            color: kSecondaryTag,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: shape,
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.fromLTRB(36.w, 36.h, 40.w, 36.h),
                child: Row(
                  children: [
                    // What will be shared: the story's phone, tilted
                    Transform.rotate(
                      angle: -0.08,
                      child: SizedBox(
                        height: 330.h,
                        child: FittedBox(
                          child: MediaQuery(
                            data: MediaQuery.of(context)
                                .copyWith(textScaler: TextScaler.noScaling),
                            child: _PhoneMockup(
                              child: _ProgressScreen(
                                day: widget.day,
                                totalDays: widget.totalDays,
                                completedDays: widget.completedDays,
                                image: widget.image,
                                weekDone: widget.weekDone,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 44.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Partagez votre progression',
                              style: AppTextStyles.baloo22),
                          SizedBox(height: 8.h),
                          Text(
                            'Une image prête pour votre story Instagram, '
                            'ou à envoyer à vos proches.',
                            style: AppTextStyles.bodyRegular13
                                .copyWith(color: Colors.grey[700], height: 1.3),
                          ),
                          SizedBox(height: 28.h),
                          AppButton(
                            label: 'Partager',
                            compact: true,
                            backgroundColor: kAccentYellow,
                            disabledBackgroundColor: kAccentYellow,
                            isLoading: _sharing,
                            onPressed: onTap,
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
      },
    );
  }
}

/// The story image: a phone showing the number of days done, big, and the
/// 31 days ticked so far (a week per row), then the app's name below. It
/// has a fixed size whatever the screen, so its sizes are plain logical
/// pixels of [size], not ScreenUtil's. Its top and bottom are left for
/// Instagram's header and reply bar. Transparent around the phone: it's
/// laid on the story's own background.
class VeganuaryStoryCard extends StatelessWidget {
  static const Size size = Size(360, 640);
  static const double pixelRatio = 3;

  final int day;
  final int totalDays;
  final Set<int> completedDays;
  final String image;
  final int? weekDone;

  const VeganuaryStoryCard({
    super.key,
    required this.day,
    required this.totalDays,
    required this.completedDays,
    required this.image,
    this.weekDone,
  });

  @override
  Widget build(BuildContext context) {
    // An image: the same whatever the phone's text size
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        size: size,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 60, 32, 0),
          child: Column(
            children: [
              _PhoneMockup(
                child: _ProgressScreen(
                  day: day,
                  totalDays: totalDays,
                  completedDays: completedDays,
                  image: image,
                  weekDone: weekDone,
                ),
              ),
              const SizedBox(height: 20),
              const _AppName(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A phone drawn around [child], its screen: dark frame, rounded screen,
/// the camera's pill at the top.
class _PhoneMockup extends StatelessWidget {
  static const double width = 200;
  static const double height = 420;
  static const double bezel = 7;

  final Widget child;

  const _PhoneMockup({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(bezel),
      decoration: ShapeDecoration(
        color: kTextPrimary,
        shape: squircleBorder(radius: 36),
        shadows: [
          BoxShadow(
            color: kTextPrimary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipSmoothRect(
        radius: squircleRadius(30),
        child: Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 52,
                  height: 15,
                  decoration: const ShapeDecoration(
                    color: kTextPrimary,
                    shape: StadiumBorder(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// On the phone's screen, like the app's page of a day done.
class _ProgressScreen extends StatelessWidget {
  final int day;
  final int totalDays;
  final Set<int> completedDays;
  final String image;
  final int? weekDone;

  const _ProgressScreen({
    required this.day,
    required this.totalDays,
    required this.completedDays,
    required this.image,
    required this.weekDone,
  });

  String get _subtitle {
    if (day >= totalDays) return 'jours : défi relevé !';
    return day > 1 ? 'jours de Veganuary !' : 'jour de Veganuary !';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kBackgroundGradientBottom,
      child: Padding(
        // Below the camera
        padding: const EdgeInsets.fromLTRB(8, 30, 8, 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            VeganuaryImage(image, height: 72, fit: BoxFit.contain),
            Text(
              '$day',
              style: AppTextStyles.baloo90
                  .copyWith(fontSize: 64, color: kAccentYellow),
            ),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.baloo30Bold
                  .copyWith(fontSize: 18, color: kAccentYellow),
            ),
            if (weekDone != null && day < totalDays) ...[
              const SizedBox(height: 6),
              Text(
                'Semaine $weekDone terminée !',
                style: AppTextStyles.bodyBold11
                    .copyWith(fontSize: 12, color: kTextPrimary),
              ),
            ],
            const SizedBox(height: 14),
            for (var start = 1; start <= totalDays; start += 7)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var d = start; d < start + 7 && d <= totalDays; d++)
                    _DayDot(day: d, done: completedDays.contains(d)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Under the phone: where to find the app.
class _AppName extends StatelessWidget {
  const _AppName();

  @override
  Widget build(BuildContext context) {
    // On a card: readable whatever the story's background
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(radius: 18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(_appIcon, width: 36, height: 36),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '321 Vegan',
                style: AppTextStyles.baloo30Bold
                    .copyWith(fontSize: 20, letterSpacing: 0),
              ),
              Text(
                'Disponible sur iOS et Android',
                style: AppTextStyles.bodyBold11
                    .copyWith(fontSize: 12, color: kTextPrimary),
              ),
              Text(
                '321vegan.fr',
                style: AppTextStyles.bodyRegular12
                    .copyWith(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A day of the course: ticked once done, its number otherwise.
class _DayDot extends StatelessWidget {
  final int day;
  final bool done;

  const _DayDot({required this.day, required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.all(2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? kAccentYellow : kLockedFill,
      ),
      child: done
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
          : Text(
              '$day',
              style: AppTextStyles.bodyBold11
                  .copyWith(fontSize: 9, color: kLockedContent),
            ),
    );
  }
}
