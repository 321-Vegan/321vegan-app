import 'scanned_product.dart';

class User {
  final int id;
  final String email;
  final String nickname;
  final String? avatar;
  final bool isActive;
  final int? nbProductsSent;
  final int? supporterLevel;
  final int? nbErrorReports;
  final int? nbProductsModified;
  final int? nbCheckings;
  final int scanCount;
  final DateTime? veganSince;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ScannedProduct>? scannedProducts;
  final bool subscriptionBypass;
  final String? role;

  User({
    required this.id,
    required this.email,
    required this.nickname,
    this.avatar,
    required this.isActive,
    required this.nbProductsSent,
    required this.supporterLevel,
    required this.nbErrorReports,
    this.nbProductsModified,
    this.nbCheckings,
    this.scanCount = 0,
    required this.veganSince,
    this.createdAt,
    this.updatedAt,
    this.scannedProducts,
    this.subscriptionBypass = false,
    this.role,
  });

  bool get isContributor => role == 'contributor' || role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int? ?? 0,
      email: json['email'] ?? '',
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] as String?,
      isActive: json['is_active'] ?? false,
      nbProductsSent: json['nb_products_sent'] ?? 0,
      supporterLevel: json['supporter'] ?? 0,
      nbErrorReports: json['nb_error_reports'] ?? 0,
      nbProductsModified: json['nb_products_modified'] ?? 0,
      nbCheckings: json['nb_checkings'] ?? 0,
      scanCount: json['scan_count'] ?? 0,
      veganSince: json['vegan_since'] != null
          ? DateTime.tryParse(json['vegan_since'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      scannedProducts: json['scanned_products'] != null
          ? (json['scanned_products'] as List)
              .map((item) => ScannedProduct.fromJson(item))
              .toList()
          : null,
      subscriptionBypass: json['subscription_bypass'] == true ||
          json['subscription_bypass'] == 1,
      role: json['role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nickname': nickname,
      'avatar': avatar,
      'is_active': isActive,
      'nb_products_sent': nbProductsSent,
      'supporter': supporterLevel,
      'vegan_since': veganSince?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
