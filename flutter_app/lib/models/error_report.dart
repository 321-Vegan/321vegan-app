/// An error report sent by the user about a product, as returned by
/// GET /me/error-reports (includes the team's response once handled).
class ErrorReport {
  final int id;
  final String ean;
  final String comment;
  final bool handled;
  final String? response;
  final DateTime? createdAt;
  final String? productName;

  ErrorReport({
    required this.id,
    required this.ean,
    required this.comment,
    required this.handled,
    this.response,
    this.createdAt,
    this.productName,
  });

  factory ErrorReport.fromJson(Map<String, dynamic> json) {
    return ErrorReport(
      id: json['id'] as int,
      ean: json['ean'] ?? '',
      comment: json['comment'] ?? '',
      handled: json['handled'] ?? false,
      response: json['response'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      productName: (json['product'] as Map<String, dynamic>?)?['name'],
    );
  }
}

class ErrorReportPaginated {
  final List<ErrorReport> items;
  final int total;
  // Note: the API's `page` field is not exposed here on purpose — it echoes
  // back a row offset ((page-1)*page_size), not the requested page number.
  final int pages;

  ErrorReportPaginated({
    required this.items,
    required this.total,
    required this.pages,
  });

  factory ErrorReportPaginated.fromJson(Map<String, dynamic> json) {
    return ErrorReportPaginated(
      items: (json['items'] as List<dynamic>)
          .map((item) => ErrorReport.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: json['total'] ?? 0,
      pages: json['pages'] ?? 1,
    );
  }
}
