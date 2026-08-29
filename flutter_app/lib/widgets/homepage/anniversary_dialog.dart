import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/homepage/stat_card.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';

/// Shows a congratulation popup celebrating the user's vegan anniversary.
/// [productsSent] and [issuesReported] are null when unknown (logged out or
/// offline), which hides their row.
Future<void> showAnniversaryDialog(
  BuildContext context, {
  required int years,
  required Map<String, int> savings,
  required int scanCount,
  int? productsSent,
  int? issuesReported,
}) {
  return showDialog(
    context: context,
    builder: (BuildContext context) => _AnniversaryDialog(
      years: years,
      savings: savings,
      scanCount: scanCount,
      productsSent: productsSent,
      issuesReported: issuesReported,
    ),
  );
}

class _AnniversaryDialog extends StatefulWidget {
  final int years;
  final Map<String, int> savings;
  final int scanCount;
  final int? productsSent;
  final int? issuesReported;

  const _AnniversaryDialog({
    required this.years,
    required this.savings,
    required this.scanCount,
    required this.productsSent,
    required this.issuesReported,
  });

  @override
  State<_AnniversaryDialog> createState() => _AnniversaryDialogState();
}

class _AnniversaryDialogState extends State<_AnniversaryDialog> {
  // Wraps the visual card (everything above the action buttons) so it can be
  // captured to an image identical to what's shown.
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  bool get _hasYears => widget.years > 1;
  String get _yearLabel => widget.years > 1 ? 'ans' : 'an';

  String get _shareText => _hasYears
      ? 'Ça fait ${widget.years} $_yearLabel que je suis végane ! 🌱 '
          'Je suis mon impact avec l\'application 321 Vegan : https://321vegan.fr'
      : 'Déjà 1 an que je suis végane ! 🌱 '
          'Je suis mon impact avec l\'application 321 Vegan : https://321vegan.fr';

  /// Render the card [RepaintBoundary] to a PNG file in the temp dir.
  Future<File?> _capturedCardFile() async {
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) return null;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/veganniversaire.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final file = await _capturedCardFile();
      if (file == null || !mounted) return;

      // sharePositionOrigin is required for the iPad popover.
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: _shareText,
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Dialog(
      backgroundColor: Colors.white,
      shape: squircleBorder(radius: 28.r),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: _cardKey,
              child: AnniversaryCard(
                years: widget.years,
                savings: widget.savings,
                scanCount: widget.scanCount,
                productsSent: widget.productsSent,
                issuesReported: widget.issuesReported,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(32.w, 0, 32.w, 32.w),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Partager',
                      icon: Icons.ios_share,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.grey[700]!,
                      borderColor: kBorderDefault,
                      isLoading: _sharing,
                      onPressed: _sharing ? null : _share,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: AppButton(
                      label: 'Merci !',
                      backgroundColor: primary,
                      onPressed:
                          _sharing ? null : () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The visual anniversary card (avatar, congratulations, and impact/activity
/// recaps) shown by the anniversary popup ([showAnniversaryDialog]).
class AnniversaryCard extends StatelessWidget {
  final int years;
  final Map<String, int> savings;
  final int scanCount;
  final int? productsSent;
  final int? issuesReported;

  const AnniversaryCard({
    required this.years,
    required this.savings,
    required this.scanCount,
    required this.productsSent,
    required this.issuesReported,
    super.key,
  });

  bool get _hasYears => years > 1;
  String get _yearLabel => years > 1 ? 'ans' : 'an';

  bool get _hasContributions =>
      scanCount > 0 || (productsSent ?? 0) > 0 || (issuesReported ?? 0) > 0;

  /// The congratulation message, with the years count rendered in bold.
  List<InlineSpan> _messageSpans() {
    final bold = AppTextStyles.bodyBold15.copyWith(height: 1.4);
    return _hasYears
        ? [
            const TextSpan(text: 'Ça fait maintenant '),
            TextSpan(text: '$years $_yearLabel', style: bold),
            const TextSpan(
              text: ' que vous êtes végane. '
                  'Une année de plus à refuser d\'exploiter les animaux, '
                  'ça se fête ! 🥳',
            ),
          ]
        : [
            const TextSpan(text: 'Déjà '),
            TextSpan(text: '1 an', style: bold),
            const TextSpan(
              text: ' que vous êtes végane ! '
                  'Une année à refuser d\'exploiter les animaux, '
                  'ça se fête ! 🥳',
            ),
          ];
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.all(32.w),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(radius: 28.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 200.w,
            height: 200.w,
            child: Image.asset(
              'lib/assets/avatars/cochon.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.person,
                size: 140.w,
                color: primary,
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Joyeux véganniversaire !',
            style: AppTextStyles.baloo22,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          Text.rich(
            TextSpan(children: _messageSpans()),
            style: AppTextStyles.bodyRegular15.copyWith(
              color: Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          _RecapSection(
            label: 'Votre impact',
            rows: [
              for (final stat in homeStats)
                _AnniversaryStatRow(
                  icon: stat.icon,
                  color: stat.cardColor,
                  title: stat.title,
                  value: savings[stat.savingsKey] ?? 0,
                  unitName: stat.unitName,
                ),
            ],
          ),
          if (_hasContributions) ...[
            SizedBox(height: 16.h),
            _RecapSection(
              label: 'Activité sur l\'appli',
              rows: [
                _AnniversaryStatRow(
                  icon: Icons.qr_code_scanner,
                  color: Colors.deepPurple,
                  title: 'Produits scannés',
                  value: scanCount,
                ),
                if (productsSent != null)
                  _AnniversaryStatRow(
                    icon: Icons.send_rounded,
                    color: Colors.teal,
                    title: 'Produits envoyés',
                    value: productsSent!,
                  ),
                if (issuesReported != null)
                  _AnniversaryStatRow(
                    icon: Icons.flag_rounded,
                    color: Colors.orange,
                    title: 'Erreurs signalées',
                    value: issuesReported!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A labelled, bordered group of recap rows.
class _RecapSection extends StatelessWidget {
  final String label;
  final List<Widget> rows;

  const _RecapSection({required this.label, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 8.w, bottom: 6.h),
          child: Text(
            label.toUpperCase(),
            style: AppTextStyles.bodyBold11.copyWith(
              color: Colors.grey[500],
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
          decoration: ShapeDecoration(
            color: Colors.grey[50],
            shape: squircleBorder(
              radius: 16.r,
              side: const BorderSide(color: kBorderDefault),
            ),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }
}

/// A single compact line in the anniversary recap: colored icon + label + value.
class _AnniversaryStatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final int value;
  final String unitName;

  const _AnniversaryStatRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    this.unitName = '',
  });

  @override
  Widget build(BuildContext context) {
    final formattedValue = NumberFormat.decimalPattern('fr_FR').format(value);
    final unit = unitName.isEmpty ? '' : ' $unitName';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 40.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.bodyMedium13.copyWith(color: Colors.grey[700]),
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            '$formattedValue$unit',
            style: AppTextStyles.bodyBold13.copyWith(color: kTextPrimary),
          ),
        ],
      ),
    );
  }
}
