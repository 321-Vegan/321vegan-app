import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/haptic_helper.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/widgets/settings/settings_toggle_tile.dart';

class SettingsModal extends StatefulWidget {
  final bool initialShowBoycott;
  final Function(bool) onShowBoycottChanged;
  final bool initialShowScores;
  final Function(bool) onShowScoresChanged;
  final bool initialHapticFeedback;
  final Function(bool) onHapticFeedbackChanged;

  const SettingsModal({
    super.key,
    required this.initialShowBoycott,
    required this.onShowBoycottChanged,
    required this.initialShowScores,
    required this.onShowScoresChanged,
    required this.initialHapticFeedback,
    required this.onHapticFeedbackChanged,
  });

  @override
  SettingsModalState createState() => SettingsModalState();
}

class SettingsModalState extends State<SettingsModal> {
  late bool _showBoycott;
  late bool _showScores;
  late bool _hapticFeedback;

  @override
  void initState() {
    super.initState();
    _showBoycott = widget.initialShowBoycott;
    _showScores = widget.initialShowScores;
    _hapticFeedback = widget.initialHapticFeedback;
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

  Future<void> _setHapticFeedbackPref(bool value) async {
    await PreferencesHelper.setHapticFeedbackPref(value);
    setState(() {
      _hapticFeedback = value;
    });
    if (value) {
      // Let the user feel what they just enabled
      HapticHelper.impact();
    }
    widget.onHapticFeedbackChanged(value);
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
          SettingsToggleTile(
            title: 'Afficher les mentions Boycott',
            subtitle: 'Afficher les informations de boycott sur les produits',
            value: _showBoycott,
            onChanged: _setShowBoycottPref,
          ),
          SizedBox(height: 16.h),
          SettingsToggleTile(
            title: 'Afficher Nutriscore & Green-score®',
            subtitle: 'Scores affichés lors du scan',
            value: _showScores,
            onChanged: _setShowScoresPref,
          ),
          SizedBox(height: 16.h),
          SettingsToggleTile(
            title: 'Retour haptique',
            subtitle: 'Vibrer lors du scan d\'un produit',
            value: _hapticFeedback,
            onChanged: _setHapticFeedbackPref,
          ),
        ],
      ),
    );
  }
}
