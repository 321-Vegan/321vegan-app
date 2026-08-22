import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';

/// Single-line text input from the Figma design system. Width/height are
/// left to the parent/content rather than fixed.
///
/// The squircle border lives on a wrapping [Container], not
/// `InputDecoration.border` (which only accepts a plain [InputBorder]).
///
/// Validation uses a [FormField] wrapping a plain [TextField] (not
/// [TextFormField]) so the error renders as a sibling below the border,
/// not inside it via [InputDecoration.errorText].
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
  final bool readOnly;
  final VoidCallback? onTap;
  final List<String>? autofillHints;

  /// Trailing widget inside the field (e.g. a password visibility toggle
  /// or a chevron/clear button on a read-only picker field).
  final Widget? suffixIcon;

  /// Wires the field into an ancestor [Form]; omit for fields validated
  /// manually outside a `Form` (the existing call sites in this codebase).
  final String? Function(String?)? validator;

  final String? labelText;

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
    this.readOnly = false,
    this.onTap,
    this.autofillHints,
    this.suffixIcon,
    this.validator,
    this.labelText,
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
    return FormField<String>(
      // Reads the controller directly rather than FormField's cached value,
      // so it stays correct when set programmatically (e.g. reverse-geocoding).
      validator: widget.validator == null
          ? null
          : (_) => widget.validator!(widget.controller.text),
      autovalidateMode: widget.validator != null
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
                readOnly: widget.readOnly,
                onTap: widget.onTap,
                autofillHints: widget.autofillHints,
                onChanged: field.didChange,
                textAlignVertical: widget.maxLines > 1
                    ? TextAlignVertical.top
                    : TextAlignVertical.center,
                style: AppTextStyles.bodyRegular15,
                decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  labelText: widget.labelText,
                  floatingLabelBehavior: widget.labelText != null
                      ? FloatingLabelBehavior.always
                      : FloatingLabelBehavior.auto,
                  labelStyle:
                      AppTextStyles.bodyMedium11.copyWith(color: Colors.grey[500]),
                  floatingLabelStyle:
                      AppTextStyles.bodyMedium11.copyWith(color: Colors.grey[500]),
                  hintText: widget.hintText,
                  hintStyle:
                      AppTextStyles.bodyRegular15.copyWith(color: Colors.grey[500]),
                  suffixIcon: widget.suffixIcon,
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 36.w, vertical: 36.h),
                ),
              ),
            ),
            if (field.hasError) ...[
              SizedBox(height: 8.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Text(
                  field.errorText!,
                  style: TextStyle(color: kSemanticError, fontSize: 33.sp),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
