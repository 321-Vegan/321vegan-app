import 'dart:io';
import 'dart:ui' as ui;

import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vegan_app/helpers/theme_helper.dart';
import 'package:vegan_app/models/seasonal_theme.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/widgets/homepage/share_home_card.dart';

/// Opens a dialog previewing the shareable home page cards (one per seasonal
/// theme, swipeable), with a button to share the selected one (system share
/// sheet: Instagram, Facebook, WhatsApp, etc.).
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
  static const String _posterAsset = 'lib/assets/affiche-321vegan-a4.png';

  final List<SeasonalTheme> _themes = ThemeHelper.getAllThemes();
  late final List<GlobalKey> _cardKeys =
      List.generate(_themes.length, (_) => GlobalKey());
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _sharing = false;

  // Last page is the A4 poster.
  int get _pageCount => _themes.length + 1;
  bool get _isPosterPage => _currentPage == _themes.length;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<File> _posterFile() async {
    final data = await rootBundle.load(_posterAsset);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/affiche-321vegan-a4.png');
    await file.writeAsBytes(data.buffer.asUint8List());
    return file;
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
        '${dir.path}/321vegan_impact_${_themes[_currentPage].season.name}.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final file =
          _isPosterPage ? await _posterFile() : await _capturedCardFile();
      if (file == null) return;

      if (!mounted) return;
      // sharePositionOrigin is required for the iPad popover.
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: _isPosterPage
            ? "Découvrez 321 Vegan 🌱 L'application gratuite et open source pour suivre son impact, scanner les produits et trouver des adresses véganes : https://321vegan.fr"
            : "Mon impact en tant que végane 🌱 Suivez le vôtre avec l'application 321 Vegan : https://321vegan.fr",
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
                        child: index == _themes.length
                            ? ClipSmoothRect(
                                radius: squircleRadius(16),
                                child: Image.asset(
                                  _posterAsset,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : ClipSmoothRect(
                                radius: squircleRadius(16),
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: MediaQuery.withNoTextScaling(
                                    child: RepaintBoundary(
                                      key: _cardKeys[index],
                                      child: ShareHomeCard(
                                        targetDate: widget.targetDate,
                                        savings: widget.savings,
                                        theme: _themes[index],
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
                      child: OutlinedButton(
                        onPressed:
                            _sharing ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          side: BorderSide(color: Colors.grey[300]!, width: 2),
                          padding: EdgeInsets.symmetric(vertical: 20.h),
                          shape: squircleBorder(radius: 12.r),
                        ),
                        child: Text(
                          'Fermer',
                          style: TextStyle(
                            fontSize: 44.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _sharing ? null : _share,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 20.h),
                          shape: squircleBorder(radius: 12.r),
                        ),
                        icon: _sharing
                            ? SizedBox(
                                width: 40.sp,
                                height: 40.sp,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(Icons.ios_share, size: 44.sp),
                        label: Text(
                          'Partager',
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
        ));
  }
}
