import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import '../../models/restaurants/restaurant.dart';
import '../../services/geocoding_service.dart';
import '../../services/restaurant_api_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_background.dart';
import '../shared/app_button.dart';
import '../shared/app_dialog.dart';
import '../shared/animated_reveal.dart';
import '../shared/app_text_field.dart';
import '../shared/form_error_banner.dart';
import '../shared/info_box.dart';
import '../shared/picked_photos_row.dart';
import '../../helpers/osm_place_info.dart';
import '../../helpers/restaurant_drafts.dart';
import 'opening_hours_editor.dart';
import 'pin_picker_page.dart';
import 'restaurant_detail_page.dart';
import 'restaurant_labels.dart';
import 'restaurant_pin.dart';
import 'stop_editor_page.dart';

// noHotDrinks is sent as serves_hot_drinks false, without surcharge
enum _MilkPrice { unknown, noHotDrinks, same, plantCostsMore, cowCostsMore }

/// Full-screen form to submit a restaurant. Its position comes from the
/// address (suggestions while typing), or from a pin placed on the map.
///
/// Pops `true` once the restaurant is created (even if some photos failed
/// to upload and the user gave up retrying). When the user finds it was
/// already referenced, pops its position ([LatLng]) for the map to show it.
///
/// With [CreateRestaurantPage.suggest], the same form prefilled with a
/// validated restaurant proposes a change of it instead: only the changed
/// fields are sent, with outdated photos to remove. Pops `true` once sent.
class CreateRestaurantPage extends StatefulWidget {
  /// Where the pin picker starts when there is no position yet.
  final LatLng mapCenter;

  /// The restaurant to propose a change of, null to create one.
  final Restaurant? original;

  /// A creation left unfinished, to go on with.
  final RestaurantDraft? draft;

  const CreateRestaurantPage({super.key, required this.mapCenter, this.draft})
      : original = null;

  CreateRestaurantPage.suggest({super.key, required Restaurant restaurant})
      : original = restaurant,
        draft = null,
        mapCenter = LatLng(restaurant.latitude, restaurant.longitude);

  @override
  State<CreateRestaurantPage> createState() => _CreateRestaurantPageState();
}

class _CreateRestaurantPageState extends State<CreateRestaurantPage>
    with WidgetsBindingObserver {
  static const int _maxPhotosPerKind = 10;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController();
  final _description = TextEditingController();
  final _veganOptions = TextEditingController();
  final _serviceArea = TextEditingController();
  final _hoursNote = TextEditingController();
  final _surcharge = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();
  final _facebook = TextEditingController();
  final _instagram = TextEditingController();
  final _menuUrl = TextEditingController();
  final _comment = TextEditingController();

  final Set<String> _tags = {};
  final Set<String> _serviceOptions = {};
  String? _veganStatus;
  bool _hasStorefront = true;
  bool _hasGlutenFreeOptions = false;
  List<OpeningSlot> _hours = [];
  bool _hoursUnknown = false;

  /// A food truck changing place with the days: its [_stops] replace the
  /// address and the hours.
  bool _hasStops = false;
  List<RestaurantStop> _stops = [];
  _MilkPrice _milkPrice = _MilkPrice.unknown;
  List<File> _menuPhotos = [];
  List<File> _placePhotos = [];

  /// Main photo of the place, chosen among [_placePhotos]: the first one
  /// unless the user picked another.
  File? _chosenMainPhoto;
  File? get _mainPhoto => _placePhotos.contains(_chosenMainPhoto)
      ? _chosenMainPhoto
      : _placePhotos.firstOrNull;

  bool _isSubmitting = false;
  String? _progress;
  String? _error;

  // Position: from a picked address suggestion, or from the pin picker
  LatLng? _position;
  bool _positionFromPin = false;

  /// Address text the [_position] was found for: once the address is
  /// edited, it's geocoded again on submit (unless the pin was placed).
  String? _geocodedAddress;
  List<PlaceResult> _suggestions = [];

  /// What was prefilled from the OpenStreetMap place picked, to tell the
  /// user to check it.
  String? _osmNotice;

  /// Position already checked for restaurants referenced there (creation
  /// only), so sending doesn't ask again.
  LatLng? _nearbyPosition;
  int _nearbyRequestId = 0;
  Timer? _debounce;

  /// Set while fields are filled from a geocoding result, so it doesn't
  /// trigger a new address search.
  bool _fillingFields = false;

  // Suggestion mode: the form as prefilled, to send only what changed
  bool get _isSuggestion => widget.original != null;
  Map<String, dynamic> _originalPayload = {};
  bool _positionChanged = false;
  final Set<int> _photosToRemove = {};

  /// Photo proposed to show first instead of the current one (suggestion).
  int? _proposedFeaturedId;
  int? get _currentFeaturedId => widget.original?.featuredPhoto?.id;
  int? get _featuredId => _proposedFeaturedId ?? _currentFeaturedId;

  /// The draft this creation is saved to, once saved (or opened from one).
  late String? _draftId = widget.draft?.id;

  /// The form as opened, to tell whether leaving loses anything.
  String _savedSnapshot = '';

  /// The form as last saved in the background, not to save it twice.
  String? _autosavedSnapshot;

  /// The draft was created by a background save only: leaving without
  /// saving removes it.
  bool _draftFromAutosave = false;

  /// A caterer and nothing else: the only kind of place that may have no
  /// storefront (a restaurant or a shop that also caters has one).
  bool get _isCaterer =>
      _tags.length == 1 && _tags.contains(RestaurantTags.caterer);

  /// A grocery and nothing else: no menu to show (link or photos), as
  /// [Restaurant.hasNoMenu].
  bool get _hasNoMenu =>
      _tags.length == 1 && _tags.contains(RestaurantTags.grocery);

  /// No cow milk in a fully vegan place: the surcharge question is moot.
  bool get _asksMilkPrice => _veganStatus != VeganStatus.fullyVegan;
  bool get _withStorefront => !_isCaterer || _hasStorefront;
  bool get _isFoodTruck => _tags.contains(RestaurantTags.foodTruck);
  bool get _withStops => _isFoodTruck && _hasStops && _withStorefront;

  /// As many as the API takes.
  static const int _maxStops = 14;

  @override
  void initState() {
    super.initState();
    final original = widget.original;
    if (original != null) _prefill(original);
    final draft = widget.draft;
    if (draft != null) _restoreDraft(draft);
    _savedSnapshot = _snapshot();
    _address.addListener(_onAddressChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  /// The app may be closed for good once in the background: a creation in
  /// progress is saved as a draft then.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _autosave();
    }
  }

  Future<void> _autosave() async {
    if (_isSuggestion || !_hasUnsavedChanges) return;
    final snapshot = _snapshot();
    if (snapshot == _autosavedSnapshot) return;
    _autosavedSnapshot = snapshot;
    final isNew = _draftId == null;
    await _saveDraft();
    if (isNew) _draftFromAutosave = true;
  }

  // ── Drafts and leaving ───────────────────────────────────────────────────

  /// The form's state, for a draft.
  Map<String, dynamic> _draftFields() => {
        'name': _name.text,
        'address': _address.text,
        'city': _city.text,
        'country': _country.text,
        'description': _description.text,
        'vegan_options': _veganOptions.text,
        'service_area': _serviceArea.text,
        'hours_note': _hoursNote.text,
        'surcharge': _surcharge.text,
        'phone': _phone.text,
        'website': _website.text,
        'facebook': _facebook.text,
        'instagram': _instagram.text,
        'menu_url': _menuUrl.text,
        'tags': _tags.toList(),
        'service_options': _serviceOptions.toList(),
        'vegan_status': _veganStatus,
        'has_storefront': _hasStorefront,
        'gluten_free': _hasGlutenFreeOptions,
        'hours': _hours.map((s) => s.toJson()).toList(),
        'hours_unknown': _hoursUnknown,
        'has_stops': _hasStops,
        'stops': _stops.map((s) => s.toJson()).toList(),
        'milk_price': _milkPrice.name,
        if (_position != null) ...{
          'latitude': _position!.latitude,
          'longitude': _position!.longitude,
        },
        'position_from_pin': _positionFromPin,
        'geocoded_address': _geocodedAddress,
      };

  void _restoreDraft(RestaurantDraft draft) {
    final f = draft.fields;
    String text(String key) => f[key] as String? ?? '';
    _name.text = text('name');
    _address.text = text('address');
    _city.text = text('city');
    _country.text = text('country');
    _description.text = text('description');
    _veganOptions.text = text('vegan_options');
    _serviceArea.text = text('service_area');
    _hoursNote.text = text('hours_note');
    _surcharge.text = text('surcharge');
    _phone.text = text('phone');
    _website.text = text('website');
    _facebook.text = text('facebook');
    _instagram.text = text('instagram');
    _menuUrl.text = text('menu_url');
    _tags.addAll((f['tags'] as List?)?.cast<String>() ?? []);
    _serviceOptions
        .addAll((f['service_options'] as List?)?.cast<String>() ?? []);
    _veganStatus = f['vegan_status'] as String?;
    _hasStorefront = f['has_storefront'] as bool? ?? true;
    _hasGlutenFreeOptions = f['gluten_free'] as bool? ?? false;
    _hours = [
      for (final slot in (f['hours'] as List?) ?? [])
        OpeningSlot.fromJson((slot as Map).cast<String, dynamic>()),
    ];
    _hoursUnknown = f['hours_unknown'] as bool? ?? false;
    _hasStops = f['has_stops'] as bool? ?? false;
    _stops = [
      for (final stop in (f['stops'] as List?) ?? [])
        RestaurantStop.fromJson((stop as Map).cast<String, dynamic>()),
    ];
    _milkPrice =
        _MilkPrice.values.asNameMap()[f['milk_price']] ?? _MilkPrice.unknown;
    final lat = (f['latitude'] as num?)?.toDouble();
    final lng = (f['longitude'] as num?)?.toDouble();
    _position = lat != null && lng != null ? LatLng(lat, lng) : null;
    _positionFromPin = f['position_from_pin'] as bool? ?? false;
    _geocodedAddress = f['geocoded_address'] as String?;
    // Photos the system may have removed are left out
    _menuPhotos = [
      for (final path in draft.menuPhotos)
        if (File(path).existsSync()) File(path),
    ];
    _placePhotos = [
      for (final path in draft.placePhotos)
        if (File(path).existsSync()) File(path),
    ];
    _chosenMainPhoto = _placePhotos
        .where((photo) => photo.path == draft.mainPhoto)
        .firstOrNull;
  }

  String _snapshot() => jsonEncode({
        'fields': _draftFields(),
        'menu': _menuPhotos.map((p) => p.path).toList(),
        'place': _placePhotos.map((p) => p.path).toList(),
        'main': _mainPhoto?.path,
      });

  bool get _hasUnsavedChanges =>
      !_isSubmitting && _snapshot() != _savedSnapshot;

  Future<void> _saveDraft() async {
    final draft = await RestaurantDrafts.save(
      id: _draftId,
      fields: _draftFields(),
      menuPhotos: _menuPhotos,
      placePhotos: _placePhotos,
      mainPhoto: _mainPhoto,
    );
    _draftId = draft.id;
  }

  /// Asks before leaving a form with changes: a creation can be kept as a
  /// draft, a suggestion is just dropped. Dismissed: stays on the form.
  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => _isSuggestion
          ? AppDialog(
              image: 'lib/assets/images/characters/cow-mby.webp',
              title: 'Abandonner la proposition ?',
              message: 'Vos modifications ne seront pas envoyées.',
              primaryLabel: 'Continuer la proposition',
              onPrimary: () => Navigator.of(ctx).pop(false),
              secondaryLabel: 'Abandonner',
              onSecondary: () => Navigator.of(ctx).pop(true),
            )
          : AppDialog(
              image: 'lib/assets/images/characters/cow-mby.webp',
              title: 'Quitter la création ?',
              message: 'Gardez-la en brouillon sur ce téléphone pour la '
                  'reprendre plus tard, depuis « Ajouter un lieu » ou vos '
                  'contributions.',
              primaryLabel: 'Enregistrer le brouillon',
              onPrimary: () async {
                await _saveDraft();
                _draftFromAutosave = false;
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              },
              secondaryLabel: 'Quitter sans enregistrer',
              onSecondary: () async {
                // Saved in the background only: not wanted after all
                final draftId = _draftId;
                if (_draftFromAutosave && draftId != null) {
                  await RestaurantDrafts.delete(draftId);
                }
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              },
            ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  void _prefill(Restaurant r) {
    _name.text = r.name;
    _address.text = r.address ?? '';
    _city.text = r.city ?? '';
    _country.text = r.country ?? '';
    _description.text = r.description ?? '';
    _veganOptions.text = r.veganOptionsDetails ?? '';
    _serviceArea.text = r.serviceArea ?? '';
    _hoursNote.text = r.openingHoursNote ?? '';
    _phone.text = r.phone ?? '';
    _website.text = r.website ?? '';
    _facebook.text = r.facebook ?? '';
    _instagram.text = r.instagram ?? '';
    _menuUrl.text = r.menuUrl ?? '';
    _tags.addAll(r.tags);
    _serviceOptions.addAll(r.serviceOptions);
    _veganStatus = r.veganStatus;
    _hasStorefront = r.hasStorefront;
    _hasGlutenFreeOptions = r.hasGlutenFreeOptions;
    _hours = [...r.openingHours];
    _hoursUnknown = r.openingHours.isEmpty;
    _hasStops = r.stops.isNotEmpty;
    _stops = [...r.stops];
    final surcharge = r.plantMilkSurcharge;
    _milkPrice = switch (surcharge) {
      null when r.servesHotDrinks == false => _MilkPrice.noHotDrinks,
      null => _MilkPrice.unknown,
      0 => _MilkPrice.same,
      > 0 => _MilkPrice.plantCostsMore,
      _ => _MilkPrice.cowCostsMore,
    };
    if (surcharge != null && surcharge != 0) {
      _surcharge.text = surcharge.abs().toStringAsFixed(2).replaceAll('.', ',');
    }
    _position = widget.mapCenter;
    _positionFromPin = true;
    _geocodedAddress = _address.text;
    _originalPayload = _payload(widget.mapCenter);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    for (final c in [
      _name,
      _address,
      _city,
      _country,
      _description,
      _veganOptions,
      _serviceArea,
      _hoursNote,
      _surcharge,
      _phone,
      _website,
      _facebook,
      _instagram,
      _menuUrl,
      _comment,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Address and position ─────────────────────────────────────────────────

  String get _addressQuery => [_address.text.trim(), _city.text.trim()]
      .where((part) => part.isNotEmpty)
      .join(', ');

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
      final results = await GeocodingService.search(query,
          addressDetails: true, extraTags: true);
      if (mounted && query == _addressQuery) {
        setState(() => _suggestions = results);
      }
    });
  }

  void _fillAddress(PlaceResult place) {
    _fillingFields = true;
    if (place.street != null) _address.text = place.street!;
    if (place.city != null) _city.text = place.city!;
    if (place.country != null) _country.text = place.country!;
    _fillingFields = false;
    _geocodedAddress = _address.text;
  }

  void _selectSuggestion(PlaceResult place) {
    FocusScope.of(context).unfocus();
    setState(() {
      _positionChanged = true;
      _fillAddress(place);
      _position = LatLng(place.latitude, place.longitude);
      _positionFromPin = false;
      _suggestions = [];
      _prefillFromOsm(OsmPlaceInfo.from(place));
    });
    _checkNearby(LatLng(place.latitude, place.longitude));
  }

  /// Warns right away when restaurants are already referenced there,
  /// rather than only when sending.
  Future<void> _checkNearby(LatLng position) async {
    if (_isSuggestion) return;
    final requestId = ++_nearbyRequestId;
    final nearby = await RestaurantApiService.getNearbyRestaurants(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    // A newer address was picked meanwhile
    if (!mounted || requestId != _nearbyRequestId) return;
    // Failed check: the one at sending still runs
    _nearbyPosition = nearby == null ? null : position;
    if (nearby != null && nearby.isNotEmpty) {
      await _askDuplicate(nearby, position);
    }
  }

  /// Fills the fields still empty with what OpenStreetMap knows about the
  /// place picked (never what the user already entered).
  void _prefillFromOsm(OsmPlaceInfo? info) {
    if (info == null) return;
    final filled = <String>[];
    void text(TextEditingController controller, String? value, String label) {
      if (value == null || controller.text.trim().isNotEmpty) return;
      controller.text = value;
      filled.add(label);
    }

    text(_name, info.name, 'nom');
    if (_tags.isEmpty && info.tags.isNotEmpty) {
      _tags.addAll(info.tags);
      filled.add('type');
    }
    if (_veganStatus == null && info.veganStatus != null) {
      _veganStatus = info.veganStatus;
      filled.add('statut végane');
    }
    if (!_hasGlutenFreeOptions && info.glutenFree) {
      _hasGlutenFreeOptions = true;
      filled.add('sans gluten');
    }
    if (_serviceOptions.isEmpty && info.serviceOptions.isNotEmpty) {
      _serviceOptions.addAll(info.serviceOptions);
      filled.add('sur place / à emporter / livraison');
    }
    final hours = info.openingHours;
    if (_hours.isEmpty && hours != null) {
      _hours = hours;
      _hoursUnknown = false;
      filled.add('horaires');
    }
    // Same characters as the phone field accepts
    text(_phone, info.phone?.replaceAll(RegExp(r'[^0-9+ .()-]'), ''),
        'téléphone');
    text(_website, info.website, 'site');
    text(_facebook, info.facebook, 'Facebook');
    text(_instagram, info.instagram, 'Instagram');
    text(_menuUrl, info.menuUrl, 'menu');

    _osmNotice = filled.isEmpty
        ? null
        : 'Pré-rempli depuis OpenStreetMap (${filled.join(', ')}) : '
            'vérifiez ces infos.';
  }

  /// Places the restaurant with the pin, then fills the address from it.
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
      _positionChanged = true;
      _suggestions = [];
    });
    _checkNearby(picked);
    final place =
        await GeocodingService.reverse(picked.latitude, picked.longitude);
    if (place != null && mounted) setState(() => _fillAddress(place));
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  String? _text(TextEditingController c) {
    final value = c.text.trim();
    return value.isEmpty ? null : value;
  }

  /// Checks what the form fields can't, returns the first problem.
  String? _check() {
    if (_tags.isEmpty) return 'Choisissez au moins un type de lieu.';
    if (_veganStatus == null) return 'Indiquez si le lieu est 100 % végane.';
    if (_withStops && _stops.isEmpty) {
      return 'Ajoutez au moins un emplacement du food truck.';
    }
    if (!_withStorefront &&
        [_phone, _website, _facebook, _instagram]
            .every((c) => _text(c) == null)) {
      return 'Sans boutique, indiquez au moins un moyen de commander '
          '(téléphone, site, Facebook ou Instagram).';
    }
    if (_asksMilkPrice &&
        (_milkPrice == _MilkPrice.plantCostsMore ||
            _milkPrice == _MilkPrice.cowCostsMore) &&
        _surchargeAmount() == null) {
      return 'Indiquez le montant du supplément (entre 0,01 et 5 €).';
    }
    return null;
  }

  double? _surchargeAmount() {
    final value = double.tryParse(_surcharge.text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0 || value > 5) return null;
    return value;
  }

  double? get _plantMilkSurcharge => !_asksMilkPrice
      ? null
      : switch (_milkPrice) {
          _MilkPrice.unknown || _MilkPrice.noHotDrinks => null,
          _MilkPrice.same => 0,
          _MilkPrice.plantCostsMore => _surchargeAmount(),
          _MilkPrice.cowCostsMore => -(_surchargeAmount() ?? 0),
        };

  /// Known only when the milk price question was answered (a known price
  /// means hot drinks, as the API assumes).
  bool? get _servesHotDrinks => !_asksMilkPrice
      ? null
      : switch (_milkPrice) {
          _MilkPrice.unknown => null,
          _MilkPrice.noHotDrinks => false,
          _ => true,
        };

  /// The slots of all the stops, in week order.
  List<OpeningSlot> get _stopSlots => [
        for (final stop in _stops) ...stop.openingHours
      ]..sort((a, b) => (a.day * 24 * 60 + a.openMinutes)
          .compareTo(b.day * 24 * 60 + b.openMinutes));

  /// The restaurant as the API expects it, from the form. With stops, the
  /// first one is the position and the hours are all of theirs, as the API
  /// sets them anyway.
  Map<String, dynamic> _payload(LatLng position) {
    final firstStop = _withStops ? _stops.firstOrNull : null;
    final stopSlots = _stopSlots;
    return {
      'name': _name.text.trim(),
      'latitude': firstStop?.latitude ?? position.latitude,
      'longitude': firstStop?.longitude ?? position.longitude,
      'address': firstStop != null ? firstStop.address : _text(_address),
      'city': firstStop != null ? firstStop.city ?? _text(_city) : _text(_city),
      'country': _text(_country),
      'description': _text(_description),
      'vegan_status': _veganStatus,
      'vegan_options_details': _veganStatus == VeganStatus.veganOptions
          ? _text(_veganOptions)
          : null,
      'has_gluten_free_options': _hasGlutenFreeOptions,
      'tags': _tags.toList(),
      // In the usual order; no dine-in without storefront
      'service_options': [
        for (final (value, _) in RestaurantServiceOptions.all)
          if (_serviceOptions.contains(value) &&
              (_withStorefront || value != RestaurantServiceOptions.dineIn))
            value,
      ],
      'plant_milk_surcharge': _plantMilkSurcharge,
      'serves_hot_drinks': _servesHotDrinks,
      'has_storefront': _withStorefront,
      'service_area': _withStorefront ? null : _text(_serviceArea),
      'opening_hours': _withStops
          ? stopSlots.isEmpty
              ? null
              : stopSlots.map((s) => s.toJson()).toList()
          : _hoursUnknown || _hours.isEmpty
              ? null
              : _hours.map((s) => s.toJson()).toList(),
      'opening_hours_note': _text(_hoursNote),
      'stops': _withStops ? _stops.map((s) => s.toJson()).toList() : null,
      'phone': _text(_phone),
      'website': _text(_website),
      'facebook': _text(_facebook),
      'instagram': _text(_instagram),
      'menu_url': _hasNoMenu ? null : _text(_menuUrl),
    };
  }

  /// Sends the fields that differ from the prefilled form, and the photos
  /// to remove, as a suggestion.
  Future<void> _submitSuggestion() async {
    final original = widget.original!;
    // The pin only moves when the user picked a new address or placed it
    final position =
        _positionChanged && _position != null ? _position! : widget.mapCenter;
    final payload = _payload(position);
    final changes = {
      for (final entry in payload.entries)
        if (jsonEncode(entry.value) != jsonEncode(_originalPayload[entry.key]))
          entry.key: entry.value,
    };
    final featuredChanged = _proposedFeaturedId != null &&
        _proposedFeaturedId != _currentFeaturedId;
    if (changes.isEmpty && _photosToRemove.isEmpty && !featuredChanged) {
      setState(() => _error = 'Vous n\'avez rien modifié.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
      _progress = 'Envoi de la proposition…';
      _suggestions = [];
    });
    final result = await RestaurantApiService.createSuggestion(
      restaurantId: original.id,
      changes: changes,
      removePhotoIds: _photosToRemove.toList(),
      featuredPhotoId: featuredChanged ? _proposedFeaturedId : null,
      comment: _text(_comment),
    );
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isSubmitting = false;
      _progress = null;
      _error = result.error ??
          'L\'envoi a échoué. Vérifiez votre connexion et réessayez !';
    });
  }

  /// The restaurant's position, null when it can't be found. Without
  /// storefront the pin goes to the city center, never to the caterer's own
  /// address.
  Future<LatLng?> _resolvePosition() async {
    final firstStop = _withStops ? _stops.firstOrNull : null;
    if (firstStop != null) {
      return LatLng(firstStop.latitude, firstStop.longitude);
    }
    if (!_withStorefront) {
      final query =
          [_text(_city), _text(_country)].whereType<String>().join(', ');
      final places = await GeocodingService.search(query);
      return places.isEmpty
          ? null
          : LatLng(places.first.latitude, places.first.longitude);
    }
    final position = _position;
    if (position != null &&
        (_positionFromPin || _address.text == _geocodedAddress)) {
      return position;
    }
    final query = [_text(_address), _text(_city), _text(_country)]
        .whereType<String>()
        .join(', ');
    final places = await GeocodingService.search(query);
    return places.isEmpty
        ? null
        : LatLng(places.first.latitude, places.first.longitude);
  }

  /// Restaurants already referenced right there, checked when sending:
  /// true to go on creating.
  Future<bool> _confirmNoDuplicate(LatLng position) async {
    final nearby = await RestaurantApiService.getNearbyRestaurants(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    if (nearby == null || nearby.isEmpty || !mounted) return true;
    return _askDuplicate(nearby, position);
  }

  /// Shows the restaurants already referenced there; each opens over the
  /// form (kept as is when coming back). True to go on creating; "it's the
  /// same place" closes the form, popping [position] for the map to show
  /// it. Dismissed counts as no (when sending).
  Future<bool> _askDuplicate(List<Restaurant> nearby, LatLng position) async {
    final goOn = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        image: 'lib/assets/images/characters/cow-mby.webp',
        title: 'Déjà sur la carte ?',
        message: nearby.length > 1
            ? 'Ces lieux sont déjà référencés à cette adresse. Touchez-en un '
                'pour vérifier.'
            : 'Ce lieu est déjà référencé à cette adresse. Touchez-le pour '
                'vérifier.',
        content: Column(
          children: [
            for (final restaurant in nearby.take(5))
              Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: InkWell(
                  onTap: () => RestaurantDetailPage.open(ctx, restaurant),
                  customBorder: squircleBorder(radius: 30.r),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 30.w, vertical: 24.h),
                    decoration: ShapeDecoration(
                      shape: squircleBorder(
                        radius: 30.r,
                        side: const BorderSide(color: kBorderDefault),
                      ),
                    ),
                    child: Row(
                      children: [
                        RestaurantPin(
                            restaurant: restaurant, size: 28, shadow: false),
                        SizedBox(width: 24.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(restaurant.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyBold15),
                              if (!restaurant.validated)
                                Text('En attente de validation',
                                    style: AppTextStyles.bodyRegular13
                                        .copyWith(color: kAccentYellow)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey[500]),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Leaving in orange, going on in green, as the app's other pairs
        primaryLabel: 'C\'est le même lieu',
        primaryColor: kAccentYellow,
        onPrimary: () => Navigator.of(ctx).pop(false),
        secondaryLabel: 'Continuer, c\'est un autre lieu',
        secondaryColor: kSemanticSuccess,
        onSecondary: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (goOn == false && mounted) {
      Navigator.of(context).pop(position);
      return false;
    }
    return goOn == true;
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    final problem = _check();
    if (form == null || !form.validate() || problem != null) {
      setState(() => _error = problem ?? 'Vérifiez les champs en rouge.');
      return;
    }
    if (_isSuggestion) return _submitSuggestion();

    setState(() {
      _isSubmitting = true;
      _error = null;
      _progress = 'Recherche de la position…';
      _suggestions = [];
    });

    final position = await _resolvePosition();
    if (!mounted) return;
    if (position == null) {
      setState(() {
        _isSubmitting = false;
        _progress = null;
        _error = _withStorefront
            ? 'Adresse introuvable : choisissez une suggestion ou placez le '
                'lieu sur la carte.'
            : 'Ville introuvable : vérifiez la ville et le pays.';
      });
      return;
    }
    // Asked again only when not already shown for this very position
    if (position != _nearbyPosition && !await _confirmNoDuplicate(position)) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _progress = null;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _progress = 'Envoi du restaurant…');

    final result =
        await RestaurantApiService.createRestaurant(_payload(position));
    if (!mounted) return;

    final restaurant = result.restaurant;
    if (restaurant == null) {
      setState(() {
        _isSubmitting = false;
        _progress = null;
        _error = result.error ??
            'L\'envoi a échoué. Vérifiez votre connexion et réessayez !';
      });
      return;
    }

    await _uploadPhotos(
      restaurant.id,
      [
        if (!_hasNoMenu)
          for (final photo in _menuPhotos) (RestaurantPhoto.kindMenu, photo),
        for (final photo in _placePhotos) (RestaurantPhoto.kindPlace, photo),
      ],
      mainPhoto: _mainPhoto,
    );
  }

  /// Uploads the photos one by one, then makes [mainPhoto] the one shown
  /// first; on failure, offers to retry the failed ones. The restaurant
  /// exists either way, so the page then closes.
  Future<void> _uploadPhotos(int restaurantId, List<(String, File)> photos,
      {File? mainPhoto}) async {
    final failed = <(String, File)>[];
    final reasons = <String>{};
    int? mainPhotoId;
    for (var i = 0; i < photos.length; i++) {
      if (mounted) {
        setState(
            () => _progress = 'Envoi des photos ${i + 1}/${photos.length}…');
      }
      final (kind, file) = photos[i];
      final result = await RestaurantApiService.uploadRestaurantPhoto(
        restaurantId: restaurantId,
        kind: kind,
        photo: file,
      );
      if (!result.ok) {
        failed.add(photos[i]);
        if (result.error != null) reasons.add(result.error!);
      } else if (file == mainPhoto) {
        mainPhotoId = result.photoId;
      }
    }
    // Best effort: by default the first place photo is the main one anyway
    if (mainPhotoId != null) {
      await RestaurantApiService.featureRestaurantPhoto(
          restaurantId: restaurantId, photoId: mainPhotoId);
    }
    if (!mounted) return;

    if (failed.isNotEmpty) {
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AppDialog(
          image: 'lib/assets/images/characters/cow-not.webp',
          title: 'Photos non envoyées',
          message: 'Le lieu est bien enregistré, mais ${failed.length} '
              'photo${failed.length > 1 ? 's n\'ont' : ' n\'a'} pas pu être '
              'envoyée${failed.length > 1 ? 's' : ''}.',
          content: reasons.isEmpty
              ? null
              : InfoBox(
                  text: reasons.join('\n'),
                  symbol: '!',
                  color: kSemanticError,
                  backgroundColor: kSemanticError.withValues(alpha: 0.08),
                ),
          primaryLabel: 'Réessayer',
          onPrimary: () => Navigator.of(ctx).pop(true),
          secondaryLabel: 'Terminer sans ces photos',
          onSecondary: () => Navigator.of(ctx).pop(false),
        ),
      );
      if (retry == true && mounted) {
        return _uploadPhotos(restaurantId, failed, mainPhoto: mainPhoto);
      }
    }
    // Created: the draft it came from is done
    final draftId = _draftId;
    if (draftId != null) await RestaurantDrafts.delete(draftId);
    if (mounted) Navigator.of(context).pop(true);
  }

  // ── Build helpers ─────────────────────────────────────────────────────────

  /// [isRequired] adds a red asterisk after [title].
  Widget _section(String title, List<Widget> children,
      {String? subtitle, bool isRequired = false}) {
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: title),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: kSemanticError),
                ),
            ]),
            style: AppTextStyles.baloo22,
          ),
          if (subtitle != null) ...[
            SizedBox(height: 6.h),
            Text(subtitle,
                style: AppTextStyles.bodyRegular13
                    .copyWith(color: Colors.grey[600])),
          ],
          SizedBox(height: 24.h),
          ...children,
        ],
      ),
    );
  }

  /// [icon] (in [iconColor]) before the label, e.g. a kind of place's.
  Widget _choiceChip(String label, bool selected, VoidCallback onTap,
      {IconData? icon, Color? iconColor}) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: _isSubmitting ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 39.w, vertical: 24.h),
        decoration: ShapeDecoration(
          color: selected ? primary.withValues(alpha: 0.08) : Colors.white,
          shape: squircleBorder(
            radius: 100.r,
            side: BorderSide(
              color: selected ? primary : kBorderDefault,
              width: selected ? 1.5 : 1,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 42.sp, color: iconColor),
              SizedBox(width: 12.w),
            ],
            Text(
              label,
              style: AppTextStyles.bodyMedium13
                  .copyWith(color: selected ? primary : kTextPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gap() => SizedBox(height: 24.h);

  /// Approved place and menu photos: the API only removes those.
  List<RestaurantPhoto> get _removablePhotos => [
        for (final photo in widget.original?.photos ?? <RestaurantPhoto>[])
          if (photo.reviewId == null && !photo.isPending) photo,
      ];

  /// Tapping a photo marks it to remove (tap again to keep it); the removal
  /// is sent with the suggestion, and applied once validated.
  Widget _buildRemovablePhotos() {
    final size = 220.w;
    final count = _photosToRemove.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24.w,
          runSpacing: 24.w,
          children: [
            for (final photo in _removablePhotos)
              Builder(builder: (context) {
                final marked = _photosToRemove.contains(photo.id);
                return GestureDetector(
                  onTap: _isSubmitting
                      ? null
                      : () => setState(() {
                            if (marked) {
                              _photosToRemove.remove(photo.id);
                            } else {
                              _photosToRemove.add(photo.id);
                              // A removed photo can't be shown first
                              if (_proposedFeaturedId == photo.id) {
                                _proposedFeaturedId = null;
                              }
                            }
                          }),
                  child: Container(
                    width: size,
                    height: size,
                    foregroundDecoration: ShapeDecoration(
                      shape: squircleBorder(
                        radius: 30.r,
                        side: marked
                            ? const BorderSide(color: kSemanticError, width: 3)
                            : BorderSide.none,
                      ),
                    ),
                    child: Stack(
                      children: [
                        ClipSmoothRect(
                          radius: squircleRadius(30.r),
                          child: Opacity(
                            opacity: marked ? 0.4 : 1,
                            child: CachedNetworkImage(
                              imageUrl: photo.url,
                              width: size,
                              height: size,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: size,
                                height: size,
                                color: Colors.grey[200],
                              ),
                            ),
                          ),
                        ),
                        if (marked)
                          Positioned.fill(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_outline,
                                    size: 72.sp, color: kSemanticError),
                                Text('À retirer',
                                    style: AppTextStyles.bodyBold13
                                        .copyWith(color: kSemanticError)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
        if (count > 0) ...[
          SizedBox(height: 18.h),
          Text(
            '$count photo${count > 1 ? 's' : ''} '
            '${count > 1 ? 'seront retirées' : 'sera retirée'} après '
            'validation de votre proposition. Touchez une photo à nouveau '
            'pour la garder.',
            style: AppTextStyles.bodyRegular13.copyWith(color: kSemanticError),
          ),
        ],
      ],
    );
  }

  /// The approved photos to choose the one shown first among (those marked
  /// to remove left out); tapping one proposes it.
  Widget _buildFeaturedPicker() {
    final size = 220.w;
    return Wrap(
      spacing: 24.w,
      runSpacing: 24.w,
      children: [
        for (final photo in _removablePhotos)
          if (!_photosToRemove.contains(photo.id))
            GestureDetector(
              onTap: _isSubmitting
                  ? null
                  : () => setState(() => _proposedFeaturedId = photo.id),
              child: Stack(
                children: [
                  Container(
                    foregroundDecoration: photo.id == _featuredId
                        ? ShapeDecoration(
                            shape: squircleBorder(
                              radius: 30.r,
                              side: const BorderSide(
                                  color: kAccentYellow, width: 3),
                            ),
                          )
                        : null,
                    child: ClipSmoothRect(
                      radius: squircleRadius(30.r),
                      child: CachedNetworkImage(
                        imageUrl: photo.url,
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: size,
                          height: size,
                          color: Colors.grey[200],
                        ),
                      ),
                    ),
                  ),
                  if (photo.id == _featuredId)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: kAccentYellow,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                ],
              ),
            ),
      ],
    );
  }

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
            Builder(builder: (context) {
              // A place (restaurant, café...) rather than an address
              final isPlace =
                  OsmPlaceInfo.from(place) != null && place.name != null;
              return ListTile(
                dense: true,
                leading: Icon(
                    isPlace ? Icons.storefront : Icons.location_on_outlined,
                    color: Theme.of(context).colorScheme.primary),
                title: isPlace
                    ? Text(place.name!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyBold13)
                    : Text(place.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyRegular13),
                subtitle: isPlace
                    ? Text(place.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyRegular13
                            .copyWith(color: Colors.grey[600]))
                    : null,
                onTap: () => _selectSuggestion(place),
              );
            }),
        ],
      ),
    );
  }

  /// Where the restaurant will be: found from the address, or placed with
  /// the pin, which stays possible either way.
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
          onPressed: _isSubmitting ? null : _pickOnMap,
          icon: const Icon(Icons.map_outlined),
          label: Text(hasPosition ? 'Ajuster' : 'Placer sur la carte'),
        ),
      ],
    );
  }

  /// Adds a stop, or changes the one at [index].
  Future<void> _editStop([int? index]) async {
    FocusScope.of(context).unfocus();
    final last = _stops.lastOrNull;
    final stop = await Navigator.of(context).push<RestaurantStop>(
      MaterialPageRoute(
        builder: (_) => StopEditorPage(
          stop: index == null ? null : _stops[index],
          otherSlots: [
            for (final (i, other) in _stops.indexed)
              if (i != index) ...other.openingHours,
          ],
          mapCenter: last != null
              ? LatLng(last.latitude, last.longitude)
              : _position ?? widget.mapCenter,
        ),
      ),
    );
    if (stop == null || !mounted) return;
    setState(() => _stops = index == null
        ? [..._stops, stop]
        : [for (final (i, s) in _stops.indexed) i == index ? stop : s]);
    // The first stop is the truck's position, checked as an address would be
    if (index == null && _stops.length == 1) {
      _checkNearby(LatLng(stop.latitude, stop.longitude));
    }
  }

  /// A stop of the food truck: tap to change it.
  Widget _buildStopCard(int index) {
    final stop = _stops[index];
    final where = [stop.address, stop.city]
        .whereType<String>()
        .where((part) => part != stop.title)
        .join(', ');
    return Padding(
      padding: EdgeInsets.only(bottom: 18.h),
      child: InkWell(
        onTap: _isSubmitting ? null : () => _editStop(index),
        customBorder: squircleBorder(radius: 30.r),
        child: Container(
          padding: EdgeInsets.fromLTRB(30.w, 24.h, 6.w, 24.h),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: squircleBorder(
              radius: 30.r,
              side: const BorderSide(color: kBorderDefault),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on,
                  size: 52.sp, color: Theme.of(context).colorScheme.primary),
              SizedBox(width: 18.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.title, style: AppTextStyles.bodyBold15),
                    if (where.isNotEmpty)
                      Text(where,
                          style: AppTextStyles.bodyRegular13
                              .copyWith(color: Colors.grey[600])),
                    Text(
                        [stop.daysLabel ?? 'Jours variables', stop.note]
                            .whereType<String>()
                            .join(' · '),
                        style: AppTextStyles.bodyRegular13
                            .copyWith(color: Colors.grey[700])),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Retirer l\'emplacement',
                onPressed: _isSubmitting
                    ? null
                    : () =>
                        setState(() => _stops = [..._stops]..removeAt(index)),
                icon: Icon(Icons.delete_outline, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Same rule as the API: 6 to 20 digits, optional leading "+".
  String? _phoneValidator(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return null;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digits < 6 || digits > 20 || phone.lastIndexOf('+') > 0) {
      return 'Numéro de téléphone invalide';
    }
    return null;
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Champ requis' : null;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    // Typing doesn't rebuild the page, so whether something would be lost
    // is checked when leaving, not through canPop
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_hasUnsavedChanges) {
          _confirmLeave();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
                _isSuggestion ? 'Proposer une modification' : 'Ajouter un lieu',
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
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 0,
                          AppSpacing.pageHorizontal, 48.h),
                      children: [
                        SizedBox(height: 12.h),
                        InfoBox(
                          text: _isSuggestion
                              ? 'Corrigez ce qui a changé : la proposition sera '
                                  'vérifiée par l\'équipe avant d\'être appliquée.'
                              : 'Seuls les lieux 100 % véganes ou avec au moins une '
                                  'option végane bien identifiée sont référencés. '
                                  'Le lieu sera visible pour tout le monde après validation.',
                        ),
                        _section('Le lieu', [
                          AppTextField(
                            controller: _name,
                            hintText: 'Nom',
                            isRequired: true,
                            textCapitalization: TextCapitalization.words,
                            validator: _required,
                            enabled: !_isSubmitting,
                          ),
                          AnimatedReveal(
                            visible: !_withStops,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _gap(),
                                AppTextField(
                                  controller: _address,
                                  hintText: _withStorefront
                                      ? 'Adresse ou nom du lieu (ex : Le Kitchen, Lyon)'
                                      : 'Adresse (non publiée)',
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  enabled: !_isSubmitting,
                                  suffixIcon: Icon(Icons.search,
                                      color: Colors.grey[500]),
                                ),
                                if (_suggestions.isNotEmpty)
                                  _buildSuggestions(),
                                _gap(),
                                AppTextField(
                                  controller: _city,
                                  hintText: 'Ville',
                                  isRequired: !_withStorefront,
                                  textCapitalization: TextCapitalization.words,
                                  validator: _withStorefront ? null : _required,
                                  enabled: !_isSubmitting,
                                ),
                              ],
                            ),
                          ),
                          _gap(),
                          AppTextField(
                            controller: _country,
                            hintText: 'Pays',
                            textCapitalization: TextCapitalization.words,
                            enabled: !_isSubmitting,
                          ),
                          AnimatedReveal(
                            visible: _withStorefront && !_withStops,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _gap(),
                                _buildPositionRow(),
                                if (_osmNotice != null) ...[
                                  SizedBox(height: 12.h),
                                  InfoBox(text: _osmNotice!),
                                ],
                              ],
                            ),
                          ),
                          _gap(),
                          AppTextField(
                            controller: _description,
                            hintText: 'Description (facultatif)',
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 2,
                            maxLines: 5,
                            maxLength: 2000,
                            enabled: !_isSubmitting,
                          ),
                        ]),
                        _section('Type de lieu', isRequired: true, [
                          Wrap(
                            spacing: 18.w,
                            runSpacing: 18.h,
                            children: [
                              for (final (value, label) in RestaurantTags.all)
                                _choiceChip(
                                  label,
                                  _tags.contains(value),
                                  () => setState(() => _tags.contains(value)
                                      ? _tags.remove(value)
                                      : _tags.add(value)),
                                  icon: restaurantTagIcon(value),
                                  iconColor: restaurantTagColor(value),
                                ),
                            ],
                          ),
                          AnimatedReveal(
                            visible: _isFoodTruck && _withStorefront,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _gap(),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _hasStops,
                                  onChanged: _isSubmitting
                                      ? null
                                      : (v) => setState(() => _hasStops = v),
                                  title: Text('Change de lieu selon les jours',
                                      style: AppTextStyles.bodyMedium15),
                                  subtitle: Text(
                                    'Ajoutez chaque emplacement où il s\'installe, '
                                    'avec ses jours et horaires.',
                                    style: AppTextStyles.bodyRegular13
                                        .copyWith(color: Colors.grey[600]),
                                  ),
                                ),
                                AnimatedReveal(
                                  visible: _withStops,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(height: 12.h),
                                      Text(
                                          'Le premier est sa position principale.',
                                          style: AppTextStyles.bodyRegular13
                                              .copyWith(
                                                  color: Colors.grey[600])),
                                      SizedBox(height: 18.h),
                                      for (var i = 0; i < _stops.length; i++)
                                        _buildStopCard(i),
                                      if (_stops.length < _maxStops)
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: TextButton.icon(
                                            onPressed: _isSubmitting
                                                ? null
                                                : () => _editStop(),
                                            icon: const Icon(Icons
                                                .add_location_alt_outlined),
                                            label: const Text(
                                                'Ajouter un emplacement'),
                                          ),
                                        ),
                                      _gap(),
                                      AppTextField(
                                        controller: _hoursNote,
                                        hintText: 'Précision sur les horaires',
                                        enabled: !_isSubmitting,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedReveal(
                            visible: _isCaterer,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _gap(),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: !_hasStorefront,
                                  onChanged: _isSubmitting
                                      ? null
                                      : (v) =>
                                          setState(() => _hasStorefront = !v),
                                  title: Text('Sans boutique',
                                      style: AppTextStyles.bodyMedium15),
                                  subtitle: Text(
                                    'Livraison ou événements uniquement : le pin sera '
                                    'placé au centre de la ville, l\'adresse ne sera '
                                    'pas publiée.',
                                    style: AppTextStyles.bodyRegular13
                                        .copyWith(color: Colors.grey[600]),
                                  ),
                                ),
                                AnimatedReveal(
                                  visible: !_hasStorefront,
                                  child: AppTextField(
                                    controller: _serviceArea,
                                    hintText:
                                        'Zone servie (ex : Lyon et 30 km autour)',
                                    isRequired: true,
                                    validator: _required,
                                    enabled: !_isSubmitting,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]),
                        _section(
                          'Sur place, à emporter, livraison ?',
                          subtitle: 'Plusieurs choix possibles',
                          [
                            Wrap(
                              spacing: 18.w,
                              runSpacing: 18.h,
                              children: [
                                for (final (value, label)
                                    in RestaurantServiceOptions.all)
                                  // Nothing to eat on site without storefront
                                  if (_withStorefront ||
                                      value != RestaurantServiceOptions.dineIn)
                                    _choiceChip(
                                      label,
                                      _serviceOptions.contains(value),
                                      () => setState(() =>
                                          _serviceOptions.contains(value)
                                              ? _serviceOptions.remove(value)
                                              : _serviceOptions.add(value)),
                                    ),
                              ],
                            ),
                          ],
                        ),
                        _section('Végane ?', isRequired: true, [
                          Wrap(
                            spacing: 18.w,
                            runSpacing: 18.h,
                            children: [
                              _choiceChip(
                                '100 % végane',
                                _veganStatus == VeganStatus.fullyVegan,
                                () => setState(() =>
                                    _veganStatus = VeganStatus.fullyVegan),
                              ),
                              _choiceChip(
                                'Options véganes',
                                _veganStatus == VeganStatus.veganOptions,
                                () => setState(() =>
                                    _veganStatus = VeganStatus.veganOptions),
                              ),
                            ],
                          ),
                          AnimatedReveal(
                            visible: _veganStatus == VeganStatus.veganOptions,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _gap(),
                                AppTextField(
                                  controller: _veganOptions,
                                  hintText:
                                      'Quelles options, et comment elles sont '
                                      'signalées sur la carte',
                                  isRequired: true,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  minLines: 2,
                                  maxLines: 5,
                                  maxLength: 2000,
                                  validator: _required,
                                  enabled: !_isSubmitting,
                                ),
                              ],
                            ),
                          ),
                          AnimatedReveal(
                            visible: _veganStatus != null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _gap(),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _hasGlutenFreeOptions,
                                  onChanged: _isSubmitting
                                      ? null
                                      : (v) => setState(
                                          () => _hasGlutenFreeOptions = v),
                                  title: Text('Options sans gluten',
                                      style: AppTextStyles.bodyMedium15),
                                  subtitle: Text(
                                    'Au moins une option végane est aussi sans '
                                    'gluten.',
                                    style: AppTextStyles.bodyRegular13
                                        .copyWith(color: Colors.grey[600]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedReveal(
                            visible: !_hasNoMenu,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _gap(),
                                AppTextField(
                                  controller: _menuUrl,
                                  hintText:
                                      'Lien vers le menu en ligne (facultatif)',
                                  keyboardType: TextInputType.url,
                                  enabled: !_isSubmitting,
                                ),
                              ],
                            ),
                          ),
                        ]),
                        AnimatedReveal(
                          visible: !_withStops,
                          child: _section(
                            _withStorefront
                                ? 'Horaires'
                                : 'Horaires de commande',
                            subtitle: RestaurantTags.accommodations
                                    .any(_tags.contains)
                                ? 'Pour un hébergement : les horaires du restaurant, '
                                    'ou à défaut du petit-déjeuner.'
                                : null,
                            [
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _hoursUnknown,
                                onChanged: _isSubmitting
                                    ? null
                                    : (v) => setState(
                                        () => _hoursUnknown = v ?? false),
                                title: Text('Je ne connais pas les horaires',
                                    style: AppTextStyles.bodyRegular15),
                              ),
                              AnimatedReveal(
                                visible: !_hoursUnknown,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    OpeningHoursEditor(
                                      slots: _hours,
                                      enabled: !_isSubmitting,
                                      onChanged: (slots) =>
                                          setState(() => _hours = slots),
                                    ),
                                    _gap(),
                                    AppTextField(
                                      controller: _hoursNote,
                                      hintText:
                                          'Précision (ex : fermé les jours fériés)',
                                      enabled: !_isSubmitting,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedReveal(
                          visible: _asksMilkPrice,
                          child: _section(
                            'Supplément lait végétal',
                            subtitle:
                                'Pour les boissons chaudes, s\'il y en a.',
                            [
                              Wrap(
                                spacing: 18.w,
                                runSpacing: 18.h,
                                children: [
                                  for (final (price, label) in const [
                                    (_MilkPrice.unknown, 'Je ne sais pas'),
                                    (_MilkPrice.noHotDrinks, 'Pas concerné'),
                                    (_MilkPrice.same, 'Même prix'),
                                    (
                                      _MilkPrice.plantCostsMore,
                                      'Végétal plus cher'
                                    ),
                                    (
                                      _MilkPrice.cowCostsMore,
                                      'Végétal moins cher'
                                    ),
                                  ])
                                    _choiceChip(
                                      label,
                                      _milkPrice == price,
                                      () => setState(() => _milkPrice = price),
                                      // Plant milk price compared to cow's
                                      icon: switch (price) {
                                        _MilkPrice.same => Icons.drag_handle,
                                        _MilkPrice.plantCostsMore =>
                                          Icons.trending_up,
                                        _MilkPrice.cowCostsMore =>
                                          Icons.trending_down,
                                        _ => null,
                                      },
                                      iconColor: switch (price) {
                                        _MilkPrice.plantCostsMore =>
                                          kSemanticError,
                                        _MilkPrice.cowCostsMore =>
                                          kSemanticSuccess,
                                        _ => Colors.grey[600],
                                      },
                                    ),
                                ],
                              ),
                              AnimatedReveal(
                                visible:
                                    _milkPrice == _MilkPrice.plantCostsMore ||
                                        _milkPrice == _MilkPrice.cowCostsMore,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _gap(),
                                    AppTextField(
                                      controller: _surcharge,
                                      hintText:
                                          'Différence de prix en € (ex : 0,50)',
                                      isRequired: true,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      enabled: !_isSubmitting,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _section(
                          'Contact',
                          isRequired: !_withStorefront,
                          subtitle: _withStorefront
                              ? 'Facultatif'
                              : 'Au moins un moyen de commander',
                          [
                            AppTextField(
                              controller: _phone,
                              hintText: 'Téléphone',
                              keyboardType: TextInputType.phone,
                              // Digits and the usual separators, nothing else
                              // (the phone keyboard alone lets letters through)
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9+ .()-]')),
                              ],
                              validator: _phoneValidator,
                              enabled: !_isSubmitting,
                            ),
                            _gap(),
                            AppTextField(
                              controller: _website,
                              hintText: 'Site web',
                              keyboardType: TextInputType.url,
                              enabled: !_isSubmitting,
                            ),
                            _gap(),
                            AppTextField(
                              controller: _facebook,
                              hintText: 'Facebook (lien ou nom de la page)',
                              keyboardType: TextInputType.url,
                              enabled: !_isSubmitting,
                            ),
                            _gap(),
                            AppTextField(
                              controller: _instagram,
                              hintText: 'Instagram (ex. @govegan)',
                              enabled: !_isSubmitting,
                            ),
                          ],
                        ),
                        if (_isSuggestion) ...[
                          if (_removablePhotos.isNotEmpty)
                            _section(
                              'Photos à retirer',
                              subtitle: 'Touchez les photos qui ne sont plus à '
                                  'jour (ancien menu...) pour les marquer. '
                                  'Elles seront retirées à l\'envoi, après '
                                  'validation. Pour en ajouter, passez par '
                                  'l\'onglet Photos.',
                              [_buildRemovablePhotos()],
                            ),
                          if (_removablePhotos.length > 1)
                            _section(
                              'Photo principale',
                              subtitle: 'Celle affichée en haut de la fiche '
                                  '(★). Touchez-en une autre pour la proposer.',
                              [_buildFeaturedPicker()],
                            ),
                          _section('Commentaire', subtitle: 'Facultatif', [
                            AppTextField(
                              controller: _comment,
                              hintText:
                                  'Ex : horaires d\'hiver affichés sur la '
                                  'porte',
                              textCapitalization: TextCapitalization.sentences,
                              minLines: 2,
                              maxLines: 5,
                              maxLength: 2000,
                              enabled: !_isSubmitting,
                            ),
                          ]),
                        ] else ...[
                          if (!_hasNoMenu)
                            _section(
                              'Photos du menu',
                              subtitle: _veganStatus == VeganStatus.veganOptions
                                  ? 'Fortement conseillé : elles prouvent l\'option '
                                      'végane à la validation.'
                                  : 'Facultatif',
                              [
                                PickedPhotosRow(
                                  photos: _menuPhotos,
                                  max: _maxPhotosPerKind,
                                  enabled: !_isSubmitting,
                                  onChanged: (p) =>
                                      setState(() => _menuPhotos = p),
                                ),
                              ],
                            ),
                          _section(
                            'Photos du lieu',
                            subtitle: _placePhotos.length > 1
                                ? 'Facultatif. Touchez une photo pour en faire '
                                    'la photo principale (★).'
                                : 'Facultatif. La première sera la photo '
                                    'principale.',
                            [
                              PickedPhotosRow(
                                photos: _placePhotos,
                                max: _maxPhotosPerKind,
                                enabled: !_isSubmitting,
                                onChanged: (p) =>
                                    setState(() => _placePhotos = p),
                                featured: _mainPhoto,
                                onFeaturedChanged: (photo) =>
                                    setState(() => _chosenMainPhoto = photo),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
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
                      if (_progress != null) ...[
                        Text(_progress!,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyRegular13
                                .copyWith(color: Colors.grey[600])),
                        SizedBox(height: 12.h),
                      ],
                      AppButton(
                        label: _isSuggestion
                            ? 'Envoyer la proposition'
                            : 'Envoyer',
                        backgroundColor: primary,
                        isLoading: _isSubmitting,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
