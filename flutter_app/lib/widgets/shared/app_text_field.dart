import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Restricts what can be typed or pasted (e.g. digits only): the
  /// [keyboardType] is only a hint to the keyboard.
  final List<TextInputFormatter>? inputFormatters;
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

  /// Appends a red asterisk to [hintText].
  final bool isRequired;

  /// Shows "12 / 100" under the field, right-aligned (red at the limit).
  /// Needs [maxLength].
  final bool showCounter;

  const AppTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.inputFormatters,
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
    this.isRequired = false,
    this.showCounter = false,
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

  TextStyle get _hintStyle =>
      AppTextStyles.bodyRegular15.copyWith(color: Colors.grey[500]);

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
                inputFormatters: widget.inputFormatters,
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
                  labelStyle: AppTextStyles.bodyMedium11
                      .copyWith(color: Colors.grey[500]),
                  floatingLabelStyle: AppTextStyles.bodyMedium11
                      .copyWith(color: Colors.grey[500]),
                  // hint and hintText are exclusive: the rich one for the star
                  // (hintStyle isn't applied to it, hence the explicit style)
                  hintText: widget.isRequired ? null : widget.hintText,
                  hint: widget.isRequired && widget.hintText != null
                      ? Text.rich(
                          TextSpan(children: [
                            TextSpan(text: widget.hintText),
                            const TextSpan(
                              text: ' *',
                              style: TextStyle(color: kSemanticError),
                            ),
                          ]),
                          style: _hintStyle,
                        )
                      : null,
                  hintStyle: _hintStyle,
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
            // Rebuilt on each keystroke by field.didChange
            if (widget.showCounter && widget.maxLength != null)
              Padding(
                padding: EdgeInsets.only(top: 8.h, right: 12.w),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${widget.controller.text.characters.length} / '
                    '${widget.maxLength}',
                    style: AppTextStyles.bodyRegular13.copyWith(
                      color: widget.controller.text.characters.length >=
                              widget.maxLength!
                          ? kSemanticError
                          : Colors.grey[500],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
