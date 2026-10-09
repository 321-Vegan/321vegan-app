/// Outcome of looking up a scanned barcode in the local product database.
enum ScanStatus {
  /// In the database and approved: the product is vegan.
  vegan,

  /// In the database but rejected ('R'): the product is not vegan.
  notVegan,

  /// In the database, pending manual verification ('M').
  pending,

  /// Submitted before but the product could not be identified ('N').
  notFound,

  /// Not in the database, but this user already submitted it.
  alreadyScanned,

  /// Not in the database.
  unknown,
}

/// Typed result of a barcode lookup, displayed by the scan UI.
class ScanResult {
  final String code;
  final String name;
  final String brand;
  final ScanStatus status;
  final bool hasNonVeganOldRecipe;
  final String? problem;
  final bool biodynamic;

  /// Object-storage key of the photo of the brand's reply, when one exists.
  final String? brandAnswer;

  const ScanResult({
    required this.code,
    required this.name,
    required this.brand,
    required this.status,
    this.hasNonVeganOldRecipe = false,
    this.problem,
    this.biodynamic = false,
    this.brandAnswer,
  });

  ScanResult withBrandAnswer(String? brandAnswer) => ScanResult(
        code: code,
        name: name,
        brand: brand,
        status: status,
        hasNonVeganOldRecipe: hasNonVeganOldRecipe,
        problem: problem,
        biodynamic: biodynamic,
        brandAnswer: brandAnswer,
      );

  /// EAN-8 barcodes can collide across products, so the UI shows a warning.
  bool get isEan8 => code.length == 8;
}
