import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import '../../models/restaurants/restaurant.dart';
import '../../services/geocoding_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../shared/animated_reveal.dart';
import '../shared/app_background.dart';
import '../shared/app_button.dart';
import '../shared/app_text_field.dart';
import '../shared/form_error_banner.dart';
import '../shared/form_section.dart';
import 'opening_hours_editor.dart';
import 'pin_picker_page.dart';

/// Full-screen form for one of a food truck's stops: its name, where it is
/// (address suggestions or a pin), and its hours there. Pops the
/// [RestaurantStop], or null when left.
///
/// [otherSlots] are the hours of the truck's other stops: it can't be at two
/// of them at once.
class StopEditorPage extends StatefulWidget {
  final RestaurantStop? stop;
  final List<OpeningSlot> otherSlots;

  /// Where the pin picker starts when the stop has no position yet.
  final LatLng mapCenter;

  const StopEditorPage({
    super.key,
    this.stop,
    this.otherSlots = const [],
    required this.mapCenter,
  });

  @override
  State<StopEditorPage> createState() => _StopEditorPageState();
}

class _StopEditorPageState extends State<StopEditorPage> {
  late final _label = TextEditingController(text: widget.stop?.label);
  late final _address = TextEditingController(text: widget.stop?.address);
  late final _city = TextEditingController(text: widget.stop?.city);
  late final _note = TextEditingController(text: widget.stop?.note);
  late List<OpeningSlot> _hours = [...?widget.stop?.openingHours];
  late bool _daysVary =
      widget.stop != null && widget.stop!.openingHours.isEmpty;

  late LatLng? _position = widget.stop == null
      ? null
      : LatLng(widget.stop!.latitude, widget.stop!.longitude);
  late bool _positionFromPin = widget.stop != null;

  /// Address text the [_position] was found for: once edited, it's geocoded
  /// again on saving (unless the pin was placed).
  late String? _geocodedAddress = widget.stop?.address;
  List<PlaceResult> _suggestions = [];
  Timer? _debounce;
  bool _fillingFields = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _address.addListener(_onAddressChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_label, _address, _city, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController c) {
    final value = c.text.trim();
    return value.isEmpty ? null : value;
  }

  String get _addressQuery =>
      [_text(_address), _text(_city)].whereType<String>().join(', ');

  /// Suggests matching addresses while the user types (debounced, as the
  /// Nominatim usage policy asks).
  void _onAddressChanged() {
    if (_fillingFields) return;
    _debounce?.cancel();
    if (_address.text.trim().length < 5) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }
    final query = _addressQuery;
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      final results = await GeocodingService.search(query);
      if (mounted && query == _addressQuery) {
        setState(() => _suggestions = results);
      }
    });
  }

  void _fillAddress(PlaceResult place) {
    _fillingFields = true;
    if (place.street != null) _address.text = place.street!;
    if (place.city != null) _city.text = place.city!;
    _fillingFields = false;
    _geocodedAddress = _address.text;
  }

  void _selectSuggestion(PlaceResult place) {
    FocusScope.of(context).unfocus();
    setState(() {
      _fillAddress(place);
      _position = LatLng(place.latitude, place.longitude);
      _positionFromPin = false;
      _suggestions = [];
    });
  }

  Future<void> _pickOnMap() async {
    FocusScope.of(context).unfocus();
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) =>
            PinPickerPage(initialPosition: _position ?? widget.mapCenter),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _position = picked;
      _positionFromPin = true;
      _suggestions = [];
    });
    final place =
        await GeocodingService.reverse(picked.latitude, picked.longitude);
    if (place != null && mounted) setState(() => _fillAddress(place));
  }

  /// The stop's position: placed, picked from a suggestion, else found
  /// from the address. Null when it can't be found.
  Future<LatLng?> _resolvePosition() async {
    final position = _position;
    if (position != null &&
        (_positionFromPin || _address.text == _geocodedAddress)) {
      return position;
    }
    final places = await GeocodingService.search(_addressQuery);
    return places.isEmpty
        ? null
        : LatLng(places.first.latitude, places.first.longitude);
  }

  Future<void> _save() async {
    final hours = _daysVary ? <OpeningSlot>[] : _hours;
    if (!_daysVary && hours.isEmpty) {
      setState(() => _error = 'Ajoutez ses horaires ici, ou cochez « Jours '
          'variables ».');
      return;
    }
    if (OpeningSlot.anyOverlap([...widget.otherSlots, ...hours])) {
      setState(() => _error = 'Ces horaires chevauchent ceux d\'un autre '
          'emplacement.');
      return;
    }
    if (_position == null && _addressQuery.isEmpty) {
      setState(() => _error = 'Indiquez l\'adresse ou placez l\'emplacement '
          'sur la carte.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
      _suggestions = [];
    });
    final position = await _resolvePosition();
    if (!mounted) return;
    if (position == null) {
      setState(() {
        _isSaving = false;
        _error = 'Adresse introuvable : choisissez une suggestion ou placez '
            'l\'emplacement sur la carte.';
      });
      return;
    }
    Navigator.of(context).pop(RestaurantStop(
      label: _text(_label),
      note: _text(_note),
      address: _text(_address),
      city: _text(_city),
      latitude: position.latitude,
      longitude: position.longitude,
      openingHours: hours,
    ));
  }

  Widget _section(String title, List<Widget> children, {String? subtitle}) =>
      FormSection(title: title, subtitle: subtitle, children: children);

  Widget _gap() => SizedBox(height: 24.h);

  Widget _buildSuggestions() {
    return Container(
      margin: EdgeInsets.only(top: 12.h),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 36.r,
          side: const BorderSide(color: kBorderDefault),
        ),
      ),
      child: Column(
        children: [
          for (final place in _suggestions)
            ListTile(
              dense: true,
              leading: Icon(Icons.location_on_outlined,
                  color: Theme.of(context).colorScheme.primary),
              title: Text(place.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyRegular13),
              onTap: () => _selectSuggestion(place),
            ),
        ],
      ),
    );
  }

  Widget _buildPositionRow() {
    final primary = Theme.of(context).colorScheme.primary;
    final hasPosition = _position != null;
    final label = !hasPosition
        ? 'La position sera trouvée à partir de l\'adresse'
        : _positionFromPin
            ? 'Position placée sur la carte'
            : 'Position trouvée depuis l\'adresse';
    return Row(
      children: [
        Icon(
          hasPosition ? Icons.location_on : Icons.location_searching,
          size: 52.sp,
          color: hasPosition ? primary : Colors.grey[500],
        ),
        SizedBox(width: 18.w),
        Expanded(
          child: Text(label,
              style: AppTextStyles.bodyRegular13
                  .copyWith(color: Colors.grey[700])),
        ),
        TextButton.icon(
          onPressed: _isSaving ? null : _pickOnMap,
          icon: const Icon(Icons.map_outlined),
          label: Text(hasPosition ? 'Ajuster' : 'Placer sur la carte'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
              widget.stop == null ? 'Nouvel emplacement' : 'Emplacement',
              style: AppTextStyles.baloo22
                  .copyWith(fontWeight: const FontWeight(500))),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kTextPrimary,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 0,
                      AppSpacing.pageHorizontal, 48.h),
                  children: [
                    _section('Où ?', [
                      AppTextField(
                        controller: _label,
                        hintText: 'Nom du lieu (ex : Marché de Wazemmes)',
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 100,
                        enabled: !_isSaving,
                      ),
                      _gap(),
                      AppTextField(
                        controller: _address,
                        hintText: 'Adresse',
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !_isSaving,
                        suffixIcon: Icon(Icons.search, color: Colors.grey[500]),
                      ),
                      if (_suggestions.isNotEmpty) _buildSuggestions(),
                      _gap(),
                      AppTextField(
                        controller: _city,
                        hintText: 'Ville',
                        textCapitalization: TextCapitalization.words,
                        enabled: !_isSaving,
                      ),
                      _gap(),
                      _buildPositionRow(),
                    ]),
                    _section(
                      'Quand ?',
                      subtitle: 'Les jours et horaires où il est à cet '
                          'emplacement.',
                      [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _daysVary,
                          onChanged: _isSaving
                              ? null
                              : (v) => setState(() => _daysVary = v ?? false),
                          title: Text('Jours variables',
                              style: AppTextStyles.bodyRegular15),
                          subtitle: Text(
                            'Il y vient régulièrement, mais pas à jour fixe.',
                            style: AppTextStyles.bodyRegular13
                                .copyWith(color: Colors.grey[600]),
                          ),
                        ),
                        AnimatedReveal(
                          visible: !_daysVary,
                          child: OpeningHoursEditor(
                            slots: _hours,
                            enabled: !_isSaving,
                            onChanged: (slots) =>
                                setState(() => _hours = slots),
                          ),
                        ),
                        _gap(),
                        AppTextField(
                          controller: _note,
                          hintText: _daysVary
                              ? 'Quand y vient-il ? (ex : un samedi sur deux)'
                              : 'Précision (facultatif, ex : sauf en août)',
                          textCapitalization: TextCapitalization.sentences,
                          maxLength: 200,
                          enabled: !_isSaving,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(48.w, 18.h, 48.w, 24.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      FormErrorBanner(message: _error!),
                      SizedBox(height: 18.h),
                    ],
                    AppButton(
                      label: 'Valider l\'emplacement',
                      backgroundColor: primary,
                      isLoading: _isSaving,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
