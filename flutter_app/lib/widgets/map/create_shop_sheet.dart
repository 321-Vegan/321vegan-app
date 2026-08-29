import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';
import 'package:vegan_app/widgets/shared/app_text_field.dart';
import 'package:vegan_app/widgets/shared/bottom_sheet_shell.dart';

class CreateShopSheet extends StatefulWidget {
  final LatLng coordinates;

  const CreateShopSheet({super.key, required this.coordinates});

  @override
  State<CreateShopSheet> createState() => _CreateShopSheetState();
}

class _CreateShopSheetState extends State<CreateShopSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _shopTypeController = TextEditingController();

  bool _isLoadingAddress = true;
  bool _isSubmitting = false;
  String _shopType = 'supermarket';

  static const _shopTypes = [
    ('supermarket', 'Supermarché'),
    ('convenience', 'Épicerie'),
    ('vegan', 'Boutique vegan'),
    ('other', 'Autre'),
  ];

  String _labelForType(String type) =>
      _shopTypes.firstWhere((t) => t.$1 == type).$2;

  @override
  void initState() {
    super.initState();
    _shopTypeController.text = _labelForType(_shopType);
    _reverseGeocode();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _shopTypeController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode() async {
    try {
      final lat = widget.coordinates.latitude;
      final lon = widget.coordinates.longitude;
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lon&format=json&accept-language=fr',
      );
      final response = await http.get(url, headers: {'User-Agent': 'fr.321vegan.app'});

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final addr = data['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final road = (addr['road'] ?? addr['pedestrian'] ?? addr['path'] ?? '') as String;
          final houseNumber = (addr['house_number'] ?? '') as String;
          final address = houseNumber.isNotEmpty ? '$houseNumber $road' : road;
          final city = (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['municipality'] ?? '') as String;
          final country = (addr['country'] ?? '') as String;

          setState(() {
            if (address.trim().isNotEmpty) _addressController.text = address.trim();
            if (city.isNotEmpty) _cityController.text = city;
            if (country.isNotEmpty) _countryController.text = country;
          });
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoadingAddress = false);
  }

  Future<void> _showShopTypePicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BottomSheetShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type de magasin', style: AppTextStyles.baloo22),
            SizedBox(height: 24.h),
            for (final type in _shopTypes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(type.$2, style: AppTextStyles.bodyRegular15),
                trailing: type.$1 == _shopType
                    ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () => Navigator.of(ctx).pop(type.$1),
              ),
          ],
        ),
      ),
    );

    if (selected != null && selected != _shopType) {
      setState(() {
        _shopType = selected;
        _shopTypeController.text = _labelForType(selected);
      });
    }
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _isSubmitting = true);
    // Capture before any async gap — context may be unmounted after pop()
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final success = await ApiService.postShop(
      name: _nameController.text.trim(),
      latitude: widget.coordinates.latitude,
      longitude: widget.coordinates.longitude,
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      country: _countryController.text.trim(),
      shopType: _shopType,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      navigator.pop(true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Magasin ajouté avec succès !'),
          backgroundColor: kSemanticSuccess,
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'ajout du magasin'),
          backgroundColor: kSemanticError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final lat = widget.coordinates.latitude.toStringAsFixed(5);
    final lon = widget.coordinates.longitude.toStringAsFixed(5);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: BottomSheetShell(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ajouter un magasin', style: AppTextStyles.baloo22),
                    IconButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      iconSize: 64.sp,
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  _isLoadingAddress
                      ? 'Chargement de l\'adresse…'
                      : 'Coordonnées : $lat, $lon',
                  style: TextStyle(fontSize: 42.sp, color: Colors.grey[600]),
                ),
                SizedBox(height: 48.h),
                AppTextField(
                  controller: _nameController,
                  hintText: 'Nom du magasin',
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                ),
                SizedBox(height: 24.h),
                AppTextField(
                  controller: _addressController,
                  hintText: 'Addresse',
                  textCapitalization: TextCapitalization.sentences,
                ),
                SizedBox(height: 24.h),
                AppTextField(
                  controller: _cityController,
                  hintText: 'Ville',
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: 24.h),
                AppTextField(
                  controller: _countryController,
                  hintText: 'Pays',
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: 24.h),
                AppTextField(
                  controller: _shopTypeController,
                  labelText: 'Type de magasin',
                  readOnly: true,
                  onTap: _isSubmitting ? null : _showShopTypePicker,
                  suffixIcon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[500]),
                ),
                SizedBox(height: 42.h),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Annuler',
                        backgroundColor: kAccentYellow,
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      ),
                    ),
                    SizedBox(width: 20.w),
                    Expanded(
                      child: AppButton(
                        label: 'Ajouter',
                        backgroundColor: primary,
                        isLoading: _isSubmitting,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
