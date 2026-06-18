import 'package:vegan_app/models/askable_product.dart';

/// Hardcoded list of brands/products the user can ask a store to add.
///
/// ⚠️ PLACEHOLDER DATA — replace the EANs, names and images with the real
/// Happyvore products before shipping:
///   1. Put the real EAN-13 of each product (the one printed on the packaging).
///   2. Drop the product photo in
///      `lib/assets/images/ask_products/happyvore/` and point `imageAsset` to it.
///   3. (Optional) Add a brand logo and set `logoAsset`.
///
/// When the backend is ready, replace this constant with a fetched list — the
/// pages only depend on `List<AskableBrand>`, nothing else needs to change.
const List<AskableBrand> askableBrands = [
  // HappyVore
  AskableBrand(
    name: 'HappyVore',
    logoAsset: 'lib/assets/images/ask_products/happyvore/happyvore-logo.png',
    products: [
      AskableProduct(
        name: 'Saucisses Chipo',
        ean: '3770016162098',
        imageAsset: 'lib/assets/images/ask_products/happyvore/chipo.webp',
      ),
      AskableProduct(
        name: 'Produit Happyvore 2',
        ean: '3300000000022',
        imageAsset: 'lib/assets/images/ask_products/happyvore/product2.webp',
      ),
      AskableProduct(
        name: 'Produit Happyvore 3',
        ean: '3300000000039',
        imageAsset: 'lib/assets/images/ask_products/happyvore/product3.webp',
      ),
      AskableProduct(
        name: 'Produit Happyvore 4',
        ean: '3300000000046',
        imageAsset: 'lib/assets/images/ask_products/happyvore/product4.webp',
      ),
    ],
  ),

  // La Vie
  AskableBrand(
    name: 'La Vie',
    logoAsset: 'lib/assets/la-vie-logo.png',
    products: [
      AskableProduct(
        name: 'Le British',
        ean: '3770016162098',
        imageAsset: 'lib/assets/images/ask_products/lavie/british.webp',
      ),
      AskableProduct(
        name: 'Produit Happyvore 2',
        ean: '3300000000022',
        imageAsset: 'lib/assets/images/ask_products/happyvore/product2.webp',
      ),
      AskableProduct(
        name: 'Produit Happyvore 3',
        ean: '3300000000039',
        imageAsset: 'lib/assets/images/ask_products/happyvore/product3.webp',
      ),
      AskableProduct(
        name: 'Produit Happyvore 4',
        ean: '3300000000046',
        imageAsset: 'lib/assets/images/ask_products/happyvore/product4.webp',
      ),
    ],
  ),
];
