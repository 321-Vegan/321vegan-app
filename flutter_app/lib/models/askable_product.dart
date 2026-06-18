/// A product the user can ask a store to add to its catalogue.
///
/// For now these are hardcoded (see `lib/data/askable_products.dart`). Later
/// this can be populated from the backend without changing the UI: just feed
/// the pages a `List<AskableProduct>` from an API call instead of the static
/// list.
class AskableProduct {
  /// Display name of the product, e.g. "Cordons bleus".
  final String name;

  /// EAN-13 barcode. Must be a valid EAN-13 (correct check digit) so it can be
  /// rendered and scanned by the store's scanner.
  final String ean;

  /// Path to the bundled product photo, e.g.
  /// `lib/assets/images/ask_products/happyvore/cordon.webp`.
  final String imageAsset;

  const AskableProduct({
    required this.name,
    required this.ean,
    required this.imageAsset,
  });
}

class AskableBrand {
  final String name;
  final String? logoAsset;

  final List<AskableProduct> products;

  const AskableBrand({
    required this.name,
    required this.products,
    this.logoAsset,
  });
}
