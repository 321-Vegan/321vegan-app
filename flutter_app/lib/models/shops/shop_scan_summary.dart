/// A product seen at a shop: scanned there, or reported as found there
/// without a scan (seen-only products have no scan).
class ShopScanSummary {
  final String ean;
  final int scanCount;

  /// Null when the product was only reported as found, never scanned here.
  final DateTime? lastScannedAt;
  final int? daysSinceLastScan;
  final int notFoundCount;
  final DateTime? lastNotFoundAt;

  /// "Found" reports: the product was seen at the shop without a scan.
  final int foundCount;
  final DateTime? lastFoundAt;
  final int? daysSinceLastFound;
  final double presenceScore;

  ShopScanSummary({
    required this.ean,
    required this.scanCount,
    this.lastScannedAt,
    this.daysSinceLastScan,
    required this.notFoundCount,
    this.lastNotFoundAt,
    this.foundCount = 0,
    this.lastFoundAt,
    this.daysSinceLastFound,
    required this.presenceScore,
  });

  /// Seen at the shop without anyone scanning it there yet.
  bool get isSeenOnly => lastScannedAt == null;

  factory ShopScanSummary.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final lastScannedAt = json['last_scanned_at'] != null
        ? DateTime.parse(json['last_scanned_at'])
        : null;
    final lastFoundAt = json['last_found_at'] != null
        ? DateTime.parse(json['last_found_at'])
        : null;
    return ShopScanSummary(
      ean: json['ean'] ?? '',
      scanCount: json['scan_count'] ?? 0,
      lastScannedAt: lastScannedAt,
      daysSinceLastScan:
          lastScannedAt != null ? now.difference(lastScannedAt).inDays : null,
      notFoundCount: json['not_found_count'] ?? 0,
      lastNotFoundAt: json['last_not_found_at'] != null
          ? DateTime.parse(json['last_not_found_at'])
          : null,
      foundCount: json['found_count'] ?? 0,
      lastFoundAt: lastFoundAt,
      daysSinceLastFound:
          lastFoundAt != null ? now.difference(lastFoundAt).inDays : null,
      presenceScore: (json['presence_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
