import 'package:flutter_test/flutter_test.dart';
import 'package:vegan_app/models/shops/shop_scan_summary.dart';

void main() {
  group('ShopScanSummary', () {
    String daysAgo(int days) =>
        DateTime.now().subtract(Duration(days: days)).toIso8601String();

    test('a scanned product has its last scan', () {
      final summary = ShopScanSummary.fromJson({
        'ean': '3760324300329',
        'scan_count': 5,
        'last_scanned_at': daysAgo(3),
        'not_found_count': 0,
        'found_count': 0,
        'presence_score': 0.85,
      });

      expect(summary.isSeenOnly, isFalse);
      expect(summary.scanCount, 5);
      expect(summary.daysSinceLastScan, 3);
      expect(summary.lastFoundAt, isNull);
      expect(summary.daysSinceLastFound, isNull);
      expect(summary.presenceScore, 0.85);
    });

    test('a product seen without a scan has no last scan', () {
      final summary = ShopScanSummary.fromJson({
        'ean': '3760324300145',
        'scan_count': 0,
        'last_scanned_at': null,
        'not_found_count': 0,
        'found_count': 2,
        'last_found_at': daysAgo(1),
        'presence_score': 0.7,
      });

      expect(summary.isSeenOnly, isTrue);
      expect(summary.lastScannedAt, isNull);
      expect(summary.daysSinceLastScan, isNull);
      expect(summary.foundCount, 2);
      expect(summary.daysSinceLastFound, 1);
    });
  });
}
