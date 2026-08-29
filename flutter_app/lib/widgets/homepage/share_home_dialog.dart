import 'dart:io';
import 'dart:ui' as ui;

import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vegan_app/models/seasonal_theme.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/default_theme.dart';
import 'package:vegan_app/widgets/homepage/share_home_card.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';

/// Opens a dialog previewing the shareable home page card looks (dark,
/// light, and their minimal variants, swipeable), with a button to share
/// the selected one via the system share sheet.
Future<void> showShareHomeDialog(
  BuildContext context, {
  required DateTime targetDate,
  required Map<String, int> savings,
}) {
  return showDialog(
    context: context,
    builder: (context) => ShareHomeDialog(
      targetDate: targetDate,
      savings: savings,
    ),
  );
}

class ShareHomeDialog extends StatefulWidget {
  final DateTime targetDate;
  final Map<String, int> savings;

  const ShareHomeDialog({
    required this.targetDate,
    required this.savings,
    super.key,
  });

  @override
  State<ShareHomeDialog> createState() => _ShareHomeDialogState();
}

class _ShareHomeDialogState extends State<ShareHomeDialog> {
  static const List<ShareCardStyle> _styles = [
    ShareCardStyle.darkMinimal,
    ShareCardStyle.lightMinimal,
    ShareCardStyle.dark,
    ShareCardStyle.light,
  ];

  late final List<GlobalKey> _cardKeys =
      List.generate(_styles.length, (_) => GlobalKey());
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _sharing = false;

  int get _pageCount => _styles.length;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<File?> _capturedCardFile() async {
    final boundary = _cardKeys[_currentPage].currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) return null;

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/321vegan_impact_${_styles[_currentPage].name}.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final file = await _capturedCardFile();
      if (file == null) return;

      if (!mounted) return;
      // sharePositionOrigin is required for the iPad popover.
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text:
            "Mon impact en tant que végane 🌱 Suivez le vôtre avec l'application 321 Vegan : https://321vegan.fr",
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Matches AppBackground's gradient so the dialog reads as part of the
    // app rather than a plain Material surface.
    final seasonal = Theme.of(context).extension<SeasonalTheme>();
    final isSeasonal =
        seasonal != null && seasonal.season != Season.defaultTheme;
    const defaultGradient = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      stops: [0.0, 0.3],
      colors: [kBackgroundGradientTop, kBackgroundGradientBottom],
    );
    final gradient = isSeasonal
        ? (seasonal.backgroundGradient ?? defaultGradient)
        : defaultGradient;

    return Dialog(
        backgroundColor: Colors.transparent,
        shape: squircleBorder(radius: 28.r),
        child: ClipSmoothRect(
          radius: squircleRadius(28.r),
          child: Container(
            decoration: BoxDecoration(gradient: gradient),
            padding: EdgeInsets.all(32.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: AspectRatio(
                    aspectRatio: 360 / 680,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pageCount,
                      onPageChanged: (index) =>
                          setState(() => _currentPage = index),
                      itemBuilder: (context, index) => Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.w),
                        child: ClipSmoothRect(
                          radius: squircleRadius(16),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: MediaQuery.withNoTextScaling(
                              child: RepaintBoundary(
                                key: _cardKeys[index],
                                child: ShareHomeCard(
                                  targetDate: widget.targetDate,
                                  savings: widget.savings,
                                  theme: defaultTheme,
                                  style: _styles[index],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pageCount, (index) {
                    final isActive = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.symmetric(horizontal: 6.w),
                      width: isActive ? 36.w : 18.w,
                      height: 18.w,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    );
                  }),
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Fermer',
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.grey[600]!,
                        borderColor: Colors.grey[300],
                        onPressed:
                            _sharing ? null : () => Navigator.of(context).pop(),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: AppButton(
                        label: 'Partager',
                        icon: Icons.ios_share,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        isLoading: _sharing,
                        onPressed: _sharing ? null : _share,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ));
  }
}
