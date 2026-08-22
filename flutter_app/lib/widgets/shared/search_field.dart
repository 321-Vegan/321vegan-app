import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';

/// Search input pill shared by the pages that search over a list: white
/// squircle field with a leading search icon and a self-managed focus
/// border (yellow when focused), matching [ProductSearchPage]'s field.
///
/// A clear ("x") button appears once [controller] has text; pass
/// [trailing] to replace it entirely (e.g. a loading spinner while results
/// are fetched).
class SearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final double radius;
  final double iconSize;
  final double fontSize;
  final double clearIconSize;
  final Widget? trailing;

  const SearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.radius = 42,
    this.iconSize = 60,
    this.fontSize = 42,
    this.clearIconSize = 36,
    this.trailing,
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleTextChange);
  }

  void _handleFocusChange() {
    if (_isFocused != _focusNode.hasFocus) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  // Rebuilds so the clear button shows/hides as the controller's text
  // changes, including when it's cleared programmatically.
  void _handleTextChange() => setState(() {});

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: widget.radius.r,
          side: BorderSide(
            color: _isFocused ? kAccentYellow : kBorderDefault,
            width: _isFocused ? 1.5 : 1,
          ),
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        inputFormatters: widget.inputFormatters,
        style: TextStyle(fontSize: widget.fontSize.sp),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle:
              TextStyle(fontSize: widget.fontSize.sp, color: Colors.grey[500]),
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: 16.w),
            child: Image.asset(
              'lib/assets/images/icons/search-line.webp',
              width: widget.iconSize.sp,
              height: widget.iconSize.sp,
              color: Colors.grey[600],
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
          // InputDecorator floors prefixIcon to a 48px minimum by default
          // (kMinInteractiveDimension) — without this, iconSize values
          // below that have no visible effect.
          prefixIconConstraints: BoxConstraints(
            minWidth: widget.iconSize.sp + 16.w,
            minHeight: widget.iconSize.sp,
          ),
          suffixIcon: widget.trailing ??
              (widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: widget.clearIconSize.sp),
                      onPressed: _clear,
                    )
                  : null),
          contentPadding: EdgeInsets.symmetric(horizontal: 39.w, vertical: 33.h),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
