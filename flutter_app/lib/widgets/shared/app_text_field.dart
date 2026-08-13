import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';

/// Single-line text input from the Figma design system: 12pt horizontal
/// gap between the border and the text — ×3 for ScreenUtil units, same
/// convention as [AppTextStyles]. Width is left to the parent (the Figma
/// frame's 356pt was that mockup's column width, not an intrinsic property
/// of the field). Height comes from [contentPadding]'s vertical value, not
/// a wrapping SizedBox — [TextField] sizes itself to its content, so a
/// fixed-height box around it only adds dead space rather than growing the
/// visible field.
///
/// The border is a squircle, matching [AppCard]/[InfoBox] — Material's
/// `InputDecoration.border` can only be an [InputBorder] (plain rounded
/// rect), so the squircle shape lives on a wrapping [Container] instead and
/// the [TextField] itself goes borderless.
class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;
  final bool obscureText;
  final bool enabled;
  final List<String>? autofillHints;

  const AppTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
    this.obscureText = false,
    this.enabled = true,
    this.autofillHints,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_isFocused != _focusNode.hasFocus) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 30.r,
          side: BorderSide(
            color: _isFocused ? kAccentYellow : kBorderDefault,
            width: _isFocused ? 1.5 : 1,
          ),
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        maxLength: widget.maxLength,
        textCapitalization: widget.textCapitalization,
        keyboardType: widget.keyboardType,
        minLines: widget.minLines,
        maxLines: widget.obscureText ? 1 : widget.maxLines,
        obscureText: widget.obscureText,
        enabled: widget.enabled,
        autofillHints: widget.autofillHints,
        textAlignVertical: widget.maxLines > 1
            ? TextAlignVertical.top
            : TextAlignVertical.center,
        style: AppTextStyles.bodyRegular15,
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          hintText: widget.hintText,
          hintStyle: AppTextStyles.bodyRegular15.copyWith(color: Colors.grey[500]),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 36.h),
        ),
      ),
    );
  }
}
