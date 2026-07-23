import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:vegan_app/models/error_report.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/services/error_report_badge_service.dart';

/// Lists the error reports sent by the current user, with their status and
/// the team's response once handled (GET /me/error-reports).
///
/// [initialData] lets the caller reuse an already fetched first page (the
/// profile fetches one for the unread-responses badge) instead of
/// refetching it; it must have been fetched with [pageSize] items.
class ErrorReportsModal extends StatefulWidget {
  /// Page size used for every fetch; initial data must match it so the
  /// "load more" page numbers line up. The badge service owns the value
  /// because it performs the initial fetch.
  static const int pageSize = ErrorReportBadgeService.pageSize;

  final ErrorReportPaginated? initialData;

  const ErrorReportsModal({super.key, this.initialData});

  @override
  State<ErrorReportsModal> createState() => _ErrorReportsModalState();
}

class _ErrorReportsModalState extends State<ErrorReportsModal> {
  final ScrollController _scrollController = ScrollController();
  final List<ErrorReport> _reports = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  int _total = 0;
  int _page = 1;
  int _pages = 1;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialData;
    if (initial != null) {
      _isLoading = false;
      _reports.addAll(initial.items);
      _total = initial.total;
      _pages = initial.pages;
    } else {
      _loadFirstPage();
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  // The requested page is tracked locally: the API echoes back a row
  // offset in its `page` field ((page-1)*page_size), not the page number.
  Future<void> _loadFirstPage() async {
    final result = await ApiService.getMyErrorReports(
        page: 1, pageSize: ErrorReportsModal.pageSize);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result == null) {
        _hasError = true;
      } else {
        _reports.addAll(result.items);
        _total = result.total;
        _pages = result.pages;
      }
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoading || _page >= _pages) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _page + 1;
    final result = await ApiService.getMyErrorReports(
        page: nextPage, pageSize: ErrorReportsModal.pageSize);
    if (!mounted) return;
    setState(() {
      _isLoadingMore = false;
      if (result != null) {
        _reports.addAll(result.items);
        _page = nextPage;
        _pages = result.pages;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? _buildMessage(
                        icon: Icons.wifi_off,
                        title: 'Impossible de charger vos signalements',
                        subtitle: 'Vérifiez votre connexion et réessayez',
                      )
                    : _reports.isEmpty
                        ? _buildMessage(
                            icon: Icons.inbox_outlined,
                            title: 'Aucun signalement',
                            subtitle:
                                'Signalez une erreur depuis la fiche d\'un produit pour la voir apparaître ici',
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.all(16.w),
                            itemCount: _reports.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _reports.length) {
                                return Padding(
                                  padding: EdgeInsets.all(16.w),
                                  child: const Center(
                                      child: CircularProgressIndicator()),
                                );
                              }
                              return _buildReportCard(_reports[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.flag_outlined,
            color: Colors.white,
            size: 80.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mes signalements',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 50.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$_total au total',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 35.sp,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: Colors.white,
              size: 40.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80.sp, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 50.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 40.sp,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(ErrorReport report) {
    final statusColor = report.handled ? Colors.green : Colors.orange;
    final statusLabel = report.handled ? 'Traité' : 'En attente';

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.productName ?? report.ean,
                        style: TextStyle(
                          fontSize: 40.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (report.productName != null)
                        Text(
                          report.ean,
                          style: TextStyle(
                            fontSize: 36.sp,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (report.createdAt != null)
                        Text(
                          DateFormat.yMMMd('fr_FR').format(report.createdAt!),
                          style: TextStyle(
                            fontSize: 36.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 36.sp,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              report.comment,
              style: TextStyle(fontSize: 40.sp),
            ),
            if (report.response != null && report.response!.isNotEmpty) ...[
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Réponse de l\'équipe',
                      style: TextStyle(
                        fontSize: 36.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      report.response!,
                      style: TextStyle(fontSize: 40.sp),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
