import 'package:vegan_app/models/partners/partners_category.dart';

class Partners {
  final int id;
  final String name;
  final String url;
  final String logoPath;
  final String discountText;
  final String discountCode;
  final bool isAffiliate;
  final bool isActive;
  final int displayOrder;
  final PartnersCategory category;

  Partners({
    required this.id,
    required this.name,
    required this.url,
    required this.logoPath,
    required this.discountText,
    required this.discountCode,
    required this.isAffiliate,
    required this.isActive,
    this.displayOrder = 0,
    required this.category,
  });

  factory Partners.fromJson(Map<String, dynamic> json) {
    return Partners(
      id: json['id'] as int,
      name: json['name'] as String,
      url: json['url'] as String,
      logoPath: json['logo_path'] as String,
      discountText: json['discount_text'] as String,
      discountCode: json['discount_code'] as String,
      isAffiliate: json['is_affiliate'] as bool,
      isActive: json['is_active'] as bool,
      displayOrder: json['display_order'] as int? ?? 0,
      category: PartnersCategory.fromJson(json['category']),
    );
  }
}
