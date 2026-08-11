import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../helpers/time_counter/time_counter.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';

/// Live "ans / mois / jours / heures / min" breakdown since a target date —
/// the pre-redesign home page counter, restyled as a row of bordered
/// digit tiles (Figma: hug, radius 9, 1px Border/Default, white fill).
class VeganCounter extends StatefulWidget {
  final DateTime targetDate;

  const VeganCounter({required this.targetDate, super.key});

  @override
  State<VeganCounter> createState() => _VeganCounterState();
}

class _VeganCounterState extends State<VeganCounter> {
  Timer? _timer;
  late TimeBreakdown _breakdown;

  @override
  void initState() {
    super.initState();
    _breakdown = TimeBreakdown.between(widget.targetDate, DateTime.now());
    // Minutes are the finest unit shown, so a per-minute tick is enough.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant VeganCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetDate != widget.targetDate) _tick();
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _breakdown = TimeBreakdown.between(widget.targetDate, DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static const _units = ['ans', 'mois', 'jours', 'heures', 'min'];

  @override
  Widget build(BuildContext context) {
    final values = [
      _breakdown.years,
      _breakdown.months,
      _breakdown.days,
      _breakdown.hours,
      _breakdown.minutes,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (int i = 0; i < values.length; i++) _unit(values[i], _units[i]),
      ],
    );
  }

  Widget _unit(int value, String label) {
    final text = value.toString().padLeft(2, '0');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 120.h,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: squircleBorder(
              radius: 9,
              side: const BorderSide(color: kBorderDefault),
            ),
          ),
          child: IntrinsicWidth(
            child: Row(
              children: [
                _digit(text[0]),
                Container(width: 1, height: 120.h, color: kBorderDefault),
                _digit(text[1]),
              ],
            ),
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 42.sp, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _digit(String digit) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30.w),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: Text(
          digit,
          key: ValueKey(digit),
          style: TextStyle(
            fontFamily: 'Baloo2',
            fontWeight: FontWeight.w600,
            fontSize: 64.sp,
            height: 1.0,
            color: kTextPrimary,
          ),
        ),
      ),
    );
  }
}
