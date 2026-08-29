/// EAN-8 / EAN-13 checksum validation, shared between the camera scanner
/// (`scan.dart`) and the manual barcode search (`product_search_page.dart`).
class BarcodeHelper {
  static bool isValidEAN13(String barcode) {
    if (barcode.length != 13) return false;
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.parse(barcode[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    final checksum = (10 - (sum % 10)) % 10;
    return checksum == int.parse(barcode[12]);
  }

  static bool isValidEAN8(String barcode) {
    if (barcode.length != 8) return false;
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      final digit = int.parse(barcode[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    final checksum = (10 - (sum % 10)) % 10;
    return checksum == int.parse(barcode[7]);
  }

  /// True if [raw] is a valid EAN-8 or EAN-13 barcode, after the same
  /// 12-digit-scanned-as-13 workaround used when handling camera scans.
  static bool isValid(String raw) {
    String normalized = raw.trim();
    if (normalized.length == 12) normalized = '0$normalized';
    if (normalized.length == 13 && isValidEAN13(normalized)) return true;
    if (normalized.length == 8 && isValidEAN8(normalized)) return true;
    return false;
  }
}
