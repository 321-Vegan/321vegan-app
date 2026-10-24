import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Kinds of place, mirrors the API tags (app/models/restaurant.py).
class RestaurantTags {
  RestaurantTags._();

  static const all = [
    ('restaurant', 'Restaurant'),
    ('cafe', 'Café'),
    ('bakery', 'Boulangerie'),
    ('food_truck', 'Food truck'),
    ('fast_food', 'Fast food'),
    ('ice_cream', 'Glacier'),
    ('bar', 'Bar'),
    ('caterer', 'Traiteur'),
    ('hotel', 'Hôtel'),
    ('guesthouse', 'Chambre d\'hôtes'),
    ('hostel', 'Auberge de jeunesse'),
  ];

  static const caterer = 'caterer';

  /// Accommodations are listed for their restaurant or breakfast.
  static const accommodations = {'hotel', 'guesthouse', 'hostel'};

  static String label(String value) =>
      all.firstWhere((t) => t.$1 == value, orElse: () => (value, value)).$2;
}

/// How to eat there, mirrors the API service options.
class RestaurantServiceOptions {
  RestaurantServiceOptions._();

  static const dineIn = 'dine_in';
  static const takeaway = 'takeaway';
  static const delivery = 'delivery';

  static const all = [
    (dineIn, 'Sur place'),
    (takeaway, 'À emporter'),
    (delivery, 'Livraison'),
  ];

  static String label(String value) =>
      all.firstWhere((o) => o.$1 == value, orElse: () => (value, value)).$2;
}

class VeganStatus {
  VeganStatus._();

  static const fullyVegan = 'FULLY_VEGAN';
  static const veganOptions = 'VEGAN_OPTIONS';
}

class OperatingStatus {
  OperatingStatus._();

  static const open = 'OPEN';
  static const temporarilyClosed = 'TEMPORARILY_CLOSED';
  static const permanentlyClosed = 'PERMANENTLY_CLOSED';
}

const _dayNames = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];

/// Day name (0 = monday), capitalized when [capitalize].
String dayName(int day, {bool capitalize = false}) {
  final name = _dayNames[day % 7];
  return capitalize ? '${name[0].toUpperCase()}${name.substring(1)}' : name;
}

/// One opening slot of a week day. [close] before [open] means the slot
/// ends after midnight (friday 18:00 → 02:00 ends on saturday).
class OpeningSlot {
  /// 0 = monday, 6 = sunday.
  final int day;
  final String open;
  final String close;

  const OpeningSlot({
    required this.day,
    required this.open,
    required this.close,
  });

  static int _minutes(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  int get openMinutes => _minutes(open);
  int get closeMinutes => _minutes(close);
  bool get crossesMidnight => closeMinutes <= openMinutes;

  /// "12:00 – 14:30"
  String get label => '$open – $close';

  OpeningSlot copyWith({int? day}) =>
      OpeningSlot(day: day ?? this.day, open: open, close: close);

  /// Same rule as the API: no two slots may overlap, including a slot
  /// running past midnight into the next day's first one.
  static bool anyOverlap(List<OpeningSlot> slots) {
    const week = 7 * 24 * 60;
    final intervals = [
      for (final s in slots)
        (
          s.day * 24 * 60 + s.openMinutes,
          s.day * 24 * 60 +
              s.openMinutes +
              (s.closeMinutes - s.openMinutes) % (24 * 60),
        ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    for (var i = 1; i < intervals.length; i++) {
      if (intervals[i].$1 < intervals[i - 1].$2) return true;
    }
    return intervals.isNotEmpty &&
        intervals.last.$2 - week > intervals.first.$1;
  }

  factory OpeningSlot.fromJson(Map<String, dynamic> json) => OpeningSlot(
        day: json['day'] as int,
        open: json['open'] as String,
        close: json['close'] as String,
      );

  Map<String, dynamic> toJson() => {'day': day, 'open': open, 'close': close};
}

/// Open/closed state of a schedule at a given time, with the next change
/// spelled out ("ferme à 14:30", "ouvre demain à 12:00").
class OpeningState {
  final bool isOpen;
  final String detail;

  const OpeningState({required this.isOpen, required this.detail});

  /// Null when the schedule is unknown (no slot at all).
  static OpeningState? of(List<OpeningSlot> slots, DateTime now) {
    if (slots.isEmpty) return null;
    final today = now.weekday - 1;
    final yesterday = (today + 6) % 7;
    final minutes = now.hour * 60 + now.minute;

    for (final slot in slots) {
      final openToday = slot.day == today &&
          minutes >= slot.openMinutes &&
          (slot.crossesMidnight || minutes < slot.closeMinutes);
      final openSinceYesterday = slot.crossesMidnight &&
          slot.day == yesterday &&
          minutes < slot.closeMinutes;
      if (openToday || openSinceYesterday) {
        return OpeningState(isOpen: true, detail: 'ferme à ${slot.close}');
      }
    }

    // Next opening within the coming week
    for (var offset = 0; offset <= 7; offset++) {
      final day = (today + offset) % 7;
      final candidates = slots
          .where((s) => s.day == day && (offset > 0 || s.openMinutes > minutes))
          .toList()
        ..sort((a, b) => a.openMinutes.compareTo(b.openMinutes));
      if (candidates.isEmpty) continue;
      final open = candidates.first.open;
      final when = switch (offset) {
        0 => 'ouvre à $open',
        1 => 'ouvre demain à $open',
        _ => 'ouvre ${dayName(day)} à $open',
      };
      return OpeningState(isOpen: false, detail: when);
    }
    return const OpeningState(isOpen: false, detail: 'fermé');
  }
}

/// Place or menu photo, or a review photo, stored in the S3 bucket.
class RestaurantPhoto {
  static const kindPlace = 'PLACE';
  static const kindMenu = 'MENU';

  final int id;
  final int? reviewId;
  final String? kind;
  final String path;
  final String status;
  final bool isFeatured;
  final int? userId;

  const RestaurantPhoto({
    required this.id,
    this.reviewId,
    this.kind,
    required this.path,
    required this.status,
    this.isFeatured = false,
    this.userId,
  });

  bool get isPending => status == 'PENDING';

  String get url => '${dotenv.env['S3_STORAGE_URL'] ?? ''}/$path';

  factory RestaurantPhoto.fromJson(Map<String, dynamic> json) =>
      RestaurantPhoto(
        id: json['id'] as int,
        reviewId: json['review_id'] as int?,
        kind: json['kind'] as String?,
        path: json['path'] as String,
        status: json['status'] as String? ?? 'PENDING',
        isFeatured: json['is_featured'] as bool? ?? false,
        userId: json['user_id'] as int?,
      );
}

/// A restaurant, café, caterer... that is fully vegan or has at least one
/// clearly identified vegan option. Map pins (GET /restaurants/in-area)
/// only carry part of the fields, plus the rating stats.
class Restaurant {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? country;
  final String? description;
  final String veganStatus;
  final String? veganOptionsDetails;
  final List<String> tags;

  /// [RestaurantServiceOptions] values; empty when unknown.
  final List<String> serviceOptions;
  final double? plantMilkSurcharge;
  final bool hasStorefront;
  final String? serviceArea;
  final List<OpeningSlot> openingHours;
  final String? openingHoursNote;
  final String? phone;
  final String? website;
  final String? facebook;
  final String? instagram;
  final String operatingStatus;
  final DateTime? closedFrom;
  final DateTime? closedUntil;
  final String? closureNote;
  final bool isClosedNow;
  final bool validated;
  final List<RestaurantPhoto> photos;

  /// Approved photo shown first on the restaurant page (also on map pins).
  final RestaurantPhoto? featuredPhoto;
  final double? ratingAvg;
  final int reviewCount;

  const Restaurant({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.country,
    this.description,
    required this.veganStatus,
    this.veganOptionsDetails,
    this.tags = const [],
    this.serviceOptions = const [],
    this.plantMilkSurcharge,
    this.hasStorefront = true,
    this.serviceArea,
    this.openingHours = const [],
    this.openingHoursNote,
    this.phone,
    this.website,
    this.facebook,
    this.instagram,
    this.operatingStatus = OperatingStatus.open,
    this.closedFrom,
    this.closedUntil,
    this.closureNote,
    this.isClosedNow = false,
    this.validated = true,
    this.photos = const [],
    this.featuredPhoto,
    this.ratingAvg,
    this.reviewCount = 0,
  });

  bool get isFullyVegan => veganStatus == VeganStatus.fullyVegan;
  bool get isCaterer => tags.contains(RestaurantTags.caterer);

  List<RestaurantPhoto> photosOfKind(String kind) =>
      photos.where((p) => p.kind == kind).toList();

  /// Open/closed now from the schedule; null when unknown or closed for a
  /// period (see [isClosedNow]).
  OpeningState? openingStateAt(DateTime now) =>
      isClosedNow ? null : OpeningState.of(openingHours, now);

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      description: json['description'] as String?,
      veganStatus: json['vegan_status'] as String? ?? VeganStatus.veganOptions,
      veganOptionsDetails: json['vegan_options_details'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
      serviceOptions:
          (json['service_options'] as List<dynamic>? ?? []).cast<String>(),
      plantMilkSurcharge: (json['plant_milk_surcharge'] as num?)?.toDouble(),
      hasStorefront: json['has_storefront'] as bool? ?? true,
      serviceArea: json['service_area'] as String?,
      openingHours: (json['opening_hours'] as List<dynamic>? ?? [])
          .map((e) => OpeningSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      openingHoursNote: json['opening_hours_note'] as String?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      facebook: json['facebook'] as String?,
      instagram: json['instagram'] as String?,
      operatingStatus:
          json['operating_status'] as String? ?? OperatingStatus.open,
      closedFrom: _date(json['closed_from']),
      closedUntil: _date(json['closed_until']),
      closureNote: json['closure_note'] as String?,
      isClosedNow: json['is_closed_now'] as bool? ?? false,
      validated: json['validated'] as bool? ?? true,
      photos: (json['photos'] as List<dynamic>? ?? [])
          .map((e) => RestaurantPhoto.fromJson(e as Map<String, dynamic>))
          .toList(),
      featuredPhoto: json['featured_photo'] is Map<String, dynamic>
          ? RestaurantPhoto.fromJson(json['featured_photo'])
          : null,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble(),
      reviewCount: json['review_count'] as int? ?? 0,
    );
  }
}
