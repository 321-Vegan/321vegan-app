import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/preference_helper.dart';

class SettingsModal extends StatefulWidget {
  final bool initialOpenOnScanPage;
  final Function(bool) onOpenOnScanPageChanged;
  final bool initialShowBoycott;
  final Function(bool) onShowBoycottChanged;
  final bool initialShowScores;
  final Function(bool) onShowScoresChanged;

  const SettingsModal({
    super.key,
    required this.initialOpenOnScanPage,
    required this.onOpenOnScanPageChanged,
    required this.initialShowBoycott,
    required this.onShowBoycottChanged,
    required this.initialShowScores,
    required this.onShowScoresChanged,
  });

  @override
  SettingsModalState createState() => SettingsModalState();
}

class SettingsModalState extends State<SettingsModal> {
  late bool _openOnScanPage;
  late bool _showBoycott;
  late bool _showScores;

  @override
  void initState() {
    super.initState();
    _openOnScanPage = widget.initialOpenOnScanPage;
    _showBoycott = widget.initialShowBoycott;
    _showScores = widget.initialShowScores;
  }

  Future<void> _setOpenOnScanPagePref(bool value) async {
    await PreferencesHelper.setOpenOnScanPagePref(value);
    setState(() {
      _openOnScanPage = value;
    });
    widget.onOpenOnScanPageChanged(value);
  }

  Future<void> _setShowBoycottPref(bool value) async {
    await PreferencesHelper.setShowBoycottPref(value);
    setState(() {
      _showBoycott = value;
    });
    widget.onShowBoycottChanged(value);
  }

  Future<void> _setShowScoresPref(bool value) async {
    await PreferencesHelper.setShowScoresPref(value);
    setState(() {
      _showScores = value;
    });
    widget.onShowScoresChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings,
                color: const Color(0xFF1A722E),
                size: 60.sp,
              ),
              SizedBox(width: 12.w),
              Text(
                'Paramètres',
                style: TextStyle(
                  fontSize: 60.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Page par défaut',
                        style: TextStyle(
                          fontSize: 40.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Ouvrir directement sur la page de scan',
                        style: TextStyle(
                          fontSize: 30.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _openOnScanPage,
                  onChanged: (value) {
                    _setOpenOnScanPagePref(value);
                  },
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF1A722E),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey[300],
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey[200]!),
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
                        'Afficher les informations de boycott sur les produits',
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
                  onChanged: _setShowBoycottPref,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF1A722E),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey[300],
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Afficher Nutriscore & Green-score®',
                        style: TextStyle(
                          fontSize: 40.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Scores affichés lors du scan',
                        style: TextStyle(
                          fontSize: 30.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _showScores,
                  onChanged: _setShowScoresPref,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF1A722E),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey[300],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
