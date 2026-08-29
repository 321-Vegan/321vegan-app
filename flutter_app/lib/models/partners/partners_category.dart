class PartnersCategory {
  final int id;
  final String name;
  final int displayOrder;

  PartnersCategory({
    required this.id,
    required this.name,
    this.displayOrder = 0,
  });

  factory PartnersCategory.fromJson(Map<String, dynamic> json) {
    return PartnersCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      displayOrder: json['display_order'] as int? ?? 0,
    );
  }
}
