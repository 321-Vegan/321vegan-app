class ValidatorBrand {
  final int id;
  final String name;
  final String? background;

  ValidatorBrand({required this.id, required this.name, this.background});

  factory ValidatorBrand.fromJson(Map<String, dynamic> json) {
    return ValidatorBrand(
      id: json['id'] as int,
      name: json['name'] as String,
      background: json['background'] as String?,
    );
  }
}

class ValidatorProduct {
  final int id;
  final String ean;
  final String? name;
  final String? description;
  final String? problemDescription;
  final String status;
  final String state;
  final DateTime? createdAt;
  final String? image;
  final ValidatorBrand? brand;

  ValidatorProduct({
    required this.id,
    required this.ean,
    this.name,
    this.description,
    this.problemDescription,
    required this.status,
    required this.state,
    this.createdAt,
    this.image,
    this.brand,
  });

  factory ValidatorProduct.fromJson(Map<String, dynamic> json) {
    return ValidatorProduct(
      id: json['id'] as int,
      ean: json['ean'] as String,
      name: json['name'] as String?,
      description: json['description'] as String?,
      problemDescription: json['problem_description'] as String?,
      status: json['status'] as String? ?? 'VEGAN',
      state: json['state'] as String? ?? 'CREATED',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      image: json['image'] as String?,
      brand: json['brand'] != null
          ? ValidatorBrand.fromJson(json['brand'] as Map<String, dynamic>)
          : null,
    );
  }
}

class OffProductData {
  final String? productName;
  final String? brandName;
  final String? ingredients;
  final String? imageUrl;
  final List<String> additives;

  const OffProductData({
    this.productName,
    this.brandName,
    this.ingredients,
    this.imageUrl,
    this.additives = const [],
  });
}
