import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vegan_app/models/boycott_data.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';
import 'package:vegan_app/widgets/shared/bottom_sheet_shell.dart';
import 'package:vegan_app/widgets/shared/info_box.dart';

class InfoModal extends StatefulWidget {
  final String description;

  /// Optional context shown above [description], outside the highlighted
  /// [InfoBox] (e.g. biodynamie's "what it is" paragraph).
  final String? body;

  final BoycottMatch? boycottMatch;

  const InfoModal({
    super.key,
    required this.description,
    this.body,
    this.boycottMatch,
  });

  @override
  State<InfoModal> createState() => _InfoModalState();
}

class _InfoModalState extends State<InfoModal> {
  Widget _buildRichReason(String reason, List<String> sources) {
    final pattern = RegExp(r'\[(\d+)\]');
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final m in pattern.allMatches(reason)) {
      if (m.start > lastEnd) {
        spans.add(TextSpan(text: reason.substring(lastEnd, m.start)));
      }
      final index = int.parse(m.group(1)!) - 1;
      if (index >= 0 && index < sources.length) {
        final url = sources[index];
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () => launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 4.h),
              child: Text(
                '[${index + 1}]',
                style: TextStyle(
                  fontFamily: 'Karla',
                  fontSize: 38.sp,
                  color: kAccentYellow,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ));
      }
      lastEnd = m.end;
    }
    if (lastEnd < reason.length) {
      spans.add(TextSpan(text: reason.substring(lastEnd)));
    }

    return Text.rich(
      TextSpan(
        style: AppTextStyles.bodyRegular15.copyWith(height: 1.4),
        children: spans,
      ),
      textAlign: TextAlign.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.boycottMatch;
    final bool isBoycott = match != null;

    return BottomSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isBoycott ? 'Marque à éviter' : 'Information',
                  style: AppTextStyles.baloo22,
                ),
              ),
            ],
          ),
          SizedBox(height: 32.h),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (match != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            match.brandDisplay,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.baloo22,
                          ),
                          if (match.groupName != null) ...[
                            SizedBox(height: 6.h),
                            Text(
                              'Appartient au groupe ${match.groupName}',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyRegular13.copyWith(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          SizedBox(height: 14.h),
                          _buildRichReason(match.reason, match.sources),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                  ],
                  if (widget.body != null) ...[
                    Text(
                      widget.body!,
                      style: AppTextStyles.bodyRegular15.copyWith(
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 24.h),
                  ],
                  InfoBox(text: widget.description),
                  SizedBox(height: 32.h),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'OK !',
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
