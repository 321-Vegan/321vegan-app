import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/models/boycott_data.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/shared/info_box.dart';

class InfoModal extends StatefulWidget {
  final String description;
  final BoycottMatch? boycottMatch;
  final bool showBoycottToggle;
  final bool? initialBoycottValue;
  final Function(bool)? onBoycottToggleChanged;

  const InfoModal({
    super.key,
    required this.description,
    this.boycottMatch,
    this.showBoycottToggle = false,
    this.initialBoycottValue,
    this.onBoycottToggleChanged,
  });

  @override
  State<InfoModal> createState() => _InfoModalState();
}

class _InfoModalState extends State<InfoModal> {
  late bool _showBoycott;

  @override
  void initState() {
    super.initState();
    _showBoycott = widget.initialBoycottValue ?? true;
  }

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
                  fontSize: 38.sp,
                  color: Colors.orange.shade700,
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
        style: TextStyle(
          fontSize: 40.sp,
          color: Colors.grey[800],
          height: 1.4,
        ),
        children: spans,
      ),
      textAlign: TextAlign.center,
    );
  }

  Future<void> _toggleBoycott(bool value) async {
    await PreferencesHelper.setShowBoycottPref(value);
    setState(() {
      _showBoycott = value;
    });
    widget.onBoycottToggleChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.boycottMatch;
    final bool isBoycott = match != null;

    return Container(
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorderOnly(topLeft: 24, topRight: 24),
      ),
      padding: EdgeInsets.only(
        left: 24.w,
        right: 24.w,
        top: 12.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 20.h),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBoycott ? 'Marque à éviter' : 'Information',
                    style: AppTextStyles.baloo22,
                  ),
                  SizedBox(height: 20.h),
                  if (match != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            match.brandDisplay,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 52.sp,
                              fontFamily: 'Baloo2',
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1,
                              color: Colors.black87,
                            ),
                          ),
                          if (match.groupName != null) ...[
                            SizedBox(height: 4.h),
                            Text(
                              'Appartient au groupe ${match.groupName}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 36.sp,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          SizedBox(height: 10.h),
                          _buildRichReason(match.reason, match.sources),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                  ],
                  InfoBox(text: widget.description),
                  if (widget.showBoycottToggle) ...[
                    SizedBox(height: 20.h),
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: ShapeDecoration(
                        color: Colors.grey[50],
                        shape: squircleBorder(
                          radius: 12.r,
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Afficher les mentions Boycott',
                                  style: TextStyle(
                                    fontSize: 40.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Vous pourrez réactiver cette option dans les paramètres',
                                  style: TextStyle(
                                    fontSize: 30.sp,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _showBoycott,
                            onChanged: _toggleBoycott,
                            activeThumbColor: Colors.white,
                            activeTrackColor: const Color(0xFF1A722E),
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: Colors.grey[300],
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A722E),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: squircleBorder(radius: 14.r),
                        elevation: 2,
                      ),
                      child: Text(
                        'OK !',
                        style: TextStyle(
                          fontSize: 48.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 100.h)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
