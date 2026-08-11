import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/themes/app_shapes.dart';

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

  bool _isLoadingAddress = true;
  bool _isSubmitting = false;
  String _shopType = 'supermarket';

  static const _shopTypes = [
    ('supermarket', 'Supermarché'),
    ('convenience', 'Épicerie'),
    ('vegan', 'Boutique vegan'),
    ('other', 'Autre'),
  ];

  @override
  void initState() {
    super.initState();
    _reverseGeocode();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
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
          backgroundColor: Colors.green,
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'ajout du magasin'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final lat = widget.coordinates.latitude.toStringAsFixed(5);
    final lon = widget.coordinates.longitude.toStringAsFixed(5);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ajouter un magasin',
                  style: TextStyle(fontSize: 42.sp, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: ShapeDecoration(
                        color: primary.withValues(alpha: 0.08),
                        shape: squircleBorder(
                          radius: 8.r,
                          side: BorderSide(color: primary.withValues(alpha: 0.2)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_pin, color: primary, size: 36.sp),
                          SizedBox(width: 6.w),
                          if (_isLoadingAddress) ...[
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Chargement de l\'adresse…',
                              style: TextStyle(fontSize: 30.sp, color: primary),
                            ),
                          ] else
                            Text(
                              '$lat, $lon',
                              style: TextStyle(
                                fontSize: 30.sp,
                                color: primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du magasin *',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Adresse',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'Ville',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: _countryController,
                      decoration: const InputDecoration(
                        labelText: 'Pays',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<String>(
                      initialValue: _shopType,
                      decoration: const InputDecoration(
                        labelText: 'Type de magasin',
                        border: OutlineInputBorder(),
                      ),
                      items: _shopTypes
                          .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _shopType = v);
                      },
                    ),
                    SizedBox(height: 24.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: squircleBorder(radius: 12.r),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Ajouter le magasin',
                                style: TextStyle(
                                    fontSize: 42.sp, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
