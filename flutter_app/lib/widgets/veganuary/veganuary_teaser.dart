import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../services/veganuary_launch.dart';
import '../../services/veganuary_reminder_service.dart';
import '../../services/veganuary_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_background.dart';
import '../shared/app_button.dart';
import '../shared/icon_snack_bar.dart';

/// The Veganuary tab before the course opens ([VeganuaryLaunch.opensAt]):
/// what it is, and how long until it starts.
class VeganuaryTeaser extends StatelessWidget {
  const VeganuaryTeaser({super.key});

  @override
  Widget build(BuildContext context) {
    final date = VeganuaryLaunch.opensAtLabel;

    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.pageHorizontal, vertical: 60.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'lib/assets/images/characters/cow-ok.webp',
                  height: 420.h,
                ),
                SizedBox(height: 48.h),
                Text(
                  'Le Parcours 321 Vegan arrive le $date !',
                  style: AppTextStyles.baloo26,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSpacing.afterTitle),
                Text(
                  '${VeganuaryService.totalDays} jours pour trouver les '
                  "réponses aux questions qu'on se pose sur le véganisme : "
                  'chaque jour, une info et une idée reçue à démonter, et des '
                  'recettes !',
                  style: AppTextStyles.bodyRegular15
                      .copyWith(color: Colors.grey[700], height: 1.4),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSpacing.section),
                const _Countdown(),
                SizedBox(height: AppSpacing.section),
                _OpeningReminderButton(date: date),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Me prévenir le 1er janvier": a notification the morning the course
/// opens. Once set, says so, with a way to cancel it.
class _OpeningReminderButton extends StatefulWidget {
  final String date;

  const _OpeningReminderButton({required this.date});

  @override
  State<_OpeningReminderButton> createState() => _OpeningReminderButtonState();
}

class _OpeningReminderButtonState extends State<_OpeningReminderButton> {
  /// Null until read from the prefs.
  bool? _set;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    VeganuaryReminderService.isOpeningReminderSet().then((set) {
      if (mounted) setState(() => _set = set);
    });
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    final granted = await VeganuaryReminderService.setOpeningReminder();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _set = granted;
    });
    if (!granted) {
      showInfoSnackBar(context,
          'Autorisez les notifications dans les réglages du téléphone.');
    }
  }

  Future<void> _cancel() async {
    await VeganuaryReminderService.cancelOpeningReminder();
    if (mounted) setState(() => _set = false);
  }

  @override
  Widget build(BuildContext context) {
    final set = _set;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: switch (set) {
        null => const SizedBox.shrink(),
        false => AppButton(
            key: const ValueKey(false),
            label: 'Me prévenir le ${widget.date}',
            icon: Icons.notifications_active_rounded,
            backgroundColor: kAccentYellow,
            isLoading: _busy,
            onPressed: _enable,
          ),
        true => Column(
            key: const ValueKey(true),
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: kSemanticSuccess, size: 60.sp),
                  SizedBox(width: 20.w),
                  Flexible(
                    child: Text(
                      'Tu recevras une notification le ${widget.date} !',
                      style: AppTextStyles.bodyBold15
                          .copyWith(color: kTextPrimary),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _cancel,
                child: Text(
                  'Annuler le rappel',
                  style: AppTextStyles.bodyRegular13.copyWith(
                    color: Colors.grey[700],
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
      },
    );
  }
}

/// Days, hours, minutes and seconds until [VeganuaryLaunch.opensAt], ticking
/// every second.
class _Countdown extends StatefulWidget {
  const _Countdown();

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = VeganuaryLaunch.opensAt.difference(DateTime.now());
    // At zero, VeganuaryLaunch swaps the teaser for the course
    if (left.isNegative) return const SizedBox.shrink();

    final days = left.inDays;
    final hours = left.inHours % 24;
    final minutes = left.inMinutes % 60;
    final seconds = left.inSeconds % 60;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CountdownTile(value: days, label: days > 1 ? 'jours' : 'jour'),
        _CountdownTile(value: hours, label: hours > 1 ? 'heures' : 'heure'),
        _CountdownTile(value: minutes, label: 'min'),
        _CountdownTile(value: seconds, label: 's'),
      ],
    );
  }
}

/// One number of the [_Countdown] on a white card, its unit below.
class _CountdownTile extends StatelessWidget {
  final int value;
  final String label;

  const _CountdownTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210.w,
      margin: EdgeInsets.symmetric(horizontal: 12.w),
      padding: EdgeInsets.symmetric(vertical: 28.h),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 40.r,
          side: const BorderSide(color: kBorderDefault),
        ),
      ),
      child: Column(
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            // Same width for every digit: the tiles don't twitch each second
            style: AppTextStyles.baloo33
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: AppTextStyles.bodyMedium13.copyWith(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}
