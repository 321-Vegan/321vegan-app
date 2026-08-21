import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/models/validator_product.dart';
import 'package:vegan_app/services/validator_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';

class BrandSelect extends StatefulWidget {
  final ValidatorBrand? initialBrand;
  final String? initialQuery;
  final ValueChanged<ValidatorBrand?> onSelected;

  const BrandSelect({super.key, this.initialBrand, this.initialQuery, required this.onSelected});

  @override
  State<BrandSelect> createState() => _BrandSelectState();
}

class _BrandSelectState extends State<BrandSelect> {
  ValidatorBrand? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialBrand;
  }

  void _clear() {
    setState(() => _selected = null);
    widget.onSelected(null);
  }

  Future<void> _openSelector() async {
    final result = await showModalBottomSheet<ValidatorBrand>(
      context: context,
      isScrollControlled: true,
      shape: squircleBorderOnly(topLeft: 20.r, topRight: 20.r),
      builder: (ctx) => _BrandSelectorSheet(
        initialQuery: _selected?.name ?? widget.initialQuery,
      ),
    );
    if (result != null) {
      setState(() => _selected = result);
      widget.onSelected(result);
    }
  }

  Future<void> _openCreate() async {
    final result = await showDialog<ValidatorBrand>(
      context: context,
      builder: (ctx) => _CreateBrandDialog(
        prefillName: _selected == null ? widget.initialQuery : null,
      ),
    );
    if (result != null) {
      setState(() => _selected = result);
      widget.onSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 12.r,
          side: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              customBorder: squircleBorderOnly(
                topLeft: 12.r,
                bottomLeft: 12.r,
              ),
              onTap: _openSelector,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selected?.name ?? 'Sélectionnez',
                        style: TextStyle(
                          fontSize: 38.sp,
                          color: _selected != null
                              ? Colors.grey[800]
                              : Colors.grey[400],
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Icon(Icons.keyboard_arrow_down, color: Colors.grey[500], size: 44.sp),
                  ],
                ),
              ),
            ),
          ),
          if (_selected != null) ...[
            Container(width: 1, height: 44.h, color: Colors.grey[200]),
            IconButton(
              icon: Icon(Icons.close, size: 40.sp),
              onPressed: _clear,
              color: Colors.grey[500],
            ),
          ],
          Container(width: 1, height: 44.h, color: Colors.grey[200]),
          IconButton(
            icon: Icon(Icons.add_circle_outline, size: 44.sp),
            onPressed: _openCreate,
            color: primary,
          ),
        ],
      ),
    );
  }
}

class _BrandSelectorSheet extends StatefulWidget {
  final String? initialQuery;
  const _BrandSelectorSheet({this.initialQuery});

  @override
  State<_BrandSelectorSheet> createState() => _BrandSelectorSheetState();
}

class _BrandSelectorSheetState extends State<_BrandSelectorSheet> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<ValidatorBrand> _results = [];
  bool _searching = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _ctrl.text = widget.initialQuery!;
      _search(widget.initialQuery!);
    }
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_isFocused != _focusNode.hasFocus) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final results = await ValidatorService.searchBrands(query.trim());
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: 600.h,
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Text('Sélectionner une marque',
                  style: TextStyle(
                      fontSize: 46.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800])),
              SizedBox(height: 16.h),
              Container(
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: squircleBorder(
                    radius: 12.r,
                    side: BorderSide(
                      color: _isFocused ? kAccentYellow : kBorderDefault,
                      width: _isFocused ? 1.5 : 1,
                    ),
                  ),
                ),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focusNode,
                  autofocus: true,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: 'Rechercher…',
                    hintStyle: TextStyle(fontSize: 36.sp, color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, size: 44.sp),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 39.w, vertical: 33.h),
                    suffixIcon: _searching
                        ? Padding(
                            padding: EdgeInsets.all(12.w),
                            child: SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  style: TextStyle(fontSize: 38.sp),
                ),
              ),
              SizedBox(height: 12.h),
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Text(
                          _ctrl.text.isEmpty ? 'Tapez pour rechercher' : 'Aucun résultat',
                          style: TextStyle(fontSize: 38.sp, color: Colors.grey[400]),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => Divider(color: Colors.grey[100], height: 1),
                        itemBuilder: (_, i) {
                          final b = _results[i];
                          return ListTile(
                            leading: Icon(Icons.storefront_outlined,
                                color: Colors.grey[500], size: 44.sp),
                            title: Text(b.name,
                                style: TextStyle(fontSize: 40.sp, color: Colors.grey[800])),
                            onTap: () => Navigator.pop(context, b),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateBrandDialog extends StatefulWidget {
  final String? prefillName;
  const _CreateBrandDialog({this.prefillName});

  @override
  State<_CreateBrandDialog> createState() => _CreateBrandDialogState();
}

class _CreateBrandDialogState extends State<_CreateBrandDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  ValidatorBrand? _parentBrand;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.prefillName != null) _nameCtrl.text = widget.prefillName!;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Le nom est requis');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final brand = await ValidatorService.createBrand(
      name: name,
      parentId: _parentBrand?.id,
    );
    if (!mounted) return;
    if (brand != null) {
      Navigator.pop(context, brand);
    } else {
      setState(() {
        _submitting = false;
        _error = 'Erreur (cette marque existe peut-être déjà)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Créer une marque',
          style: TextStyle(fontSize: 48.sp, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Maison mère',
                style: TextStyle(
                    fontSize: 40.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700])),
            SizedBox(height: 8.h),
            _ParentBrandSearch(onSelected: (b) => setState(() => _parentBrand = b)),
            SizedBox(height: 20.h),
            Text('Nom *',
                style: TextStyle(
                    fontSize: 40.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700])),
            SizedBox(height: 8.h),
            TextField(
              controller: _nameCtrl,
              autofocus: widget.prefillName == null,
              decoration: InputDecoration(
                hintText: 'Nom de la marque',
                hintStyle: TextStyle(fontSize: 36.sp, color: Colors.grey[400]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              ),
              style: TextStyle(fontSize: 38.sp),
            ),
            if (_error != null) ...[
              SizedBox(height: 10.h),
              Text(_error!, style: TextStyle(fontSize: 34.sp, color: kSemanticError)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: Text('Annuler', style: TextStyle(fontSize: 40.sp)),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          child: _submitting
              ? SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text('Créer', style: TextStyle(fontSize: 40.sp, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _ParentBrandSearch extends StatefulWidget {
  final ValueChanged<ValidatorBrand?> onSelected;
  const _ParentBrandSearch({required this.onSelected});

  @override
  State<_ParentBrandSearch> createState() => _ParentBrandSearchState();
}

class _ParentBrandSearchState extends State<_ParentBrandSearch> {
  final TextEditingController _ctrl = TextEditingController();
  List<ValidatorBrand> _suggestions = [];
  ValidatorBrand? _selected;
  bool _searching = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _searching = true);
    final results = await ValidatorService.searchBrands(query);
    if (mounted) {
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    }
  }

  void _select(ValidatorBrand brand) {
    setState(() {
      _selected = brand;
      _ctrl.text = brand.name;
      _suggestions = [];
    });
    widget.onSelected(brand);
  }

  void _clear() {
    setState(() {
      _selected = null;
      _ctrl.clear();
      _suggestions = [];
    });
    widget.onSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _ctrl,
          onChanged: _selected != null ? null : _onChanged,
          readOnly: _selected != null,
          decoration: InputDecoration(
            hintText: 'Aucune (marque indépendante)',
            hintStyle: TextStyle(fontSize: 34.sp, color: Colors.grey[400]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            suffixIcon: _selected != null
                ? IconButton(icon: const Icon(Icons.close), onPressed: _clear)
                : _searching
                    ? Padding(
                        padding: EdgeInsets.all(12.w),
                        child: SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
          ),
          style: TextStyle(fontSize: 36.sp),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: squircleBorder(
                radius: 8.r,
                side: BorderSide(color: Colors.grey[200]!),
              ),
              shadows: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
              ],
            ),
            child: Column(
              children: _suggestions.map((b) {
                return InkWell(
                  onTap: () => _select(b),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    child: Row(
                      children: [
                        Icon(Icons.storefront_outlined, size: 36.sp, color: Colors.grey[500]),
                        SizedBox(width: 10.w),
                        Text(b.name, style: TextStyle(fontSize: 36.sp, color: Colors.grey[800])),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
