import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:vegan_app/models/error_report.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/services/error_report_badge_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/widgets/shared/app_background.dart';

/// Full-screen page listing the error reports sent by the current user,
/// with their status and the team's response once handled
/// (GET /me/error-reports). Pushed from Settings and from the Dashboard.
///
/// [initialData] lets the caller reuse an already fetched first page (the
/// dashboard/settings fetch one for the unread-responses badge) instead of
/// refetching it; it must have been fetched with [pageSize] items.
class ErrorReportsPage extends StatefulWidget {
  /// Page size used for every fetch; initial data must match it so the
  /// "load more" page numbers line up. The badge service owns the value
  /// because it performs the initial fetch.
  static const int pageSize = ErrorReportBadgeService.pageSize;

  final ErrorReportPaginated? initialData;

  const ErrorReportsPage({super.key, this.initialData});

  @override
  State<ErrorReportsPage> createState() => _ErrorReportsPageState();
}

class _ErrorReportsPageState extends State<ErrorReportsPage> {
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
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    final result = await ApiService.getMyErrorReports(
        page: 1, pageSize: ErrorReportsPage.pageSize);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result == null) {
        _hasError = true;
      } else {
        _reports
          ..clear()
          ..addAll(result.items);
        _page = 1;
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
        page: nextPage, pageSize: ErrorReportsPage.pageSize);
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
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Mes signalements',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kTextPrimary,
        ),
        body: SafeArea(
          top: false,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasError
                  ? _buildErrorState()
                  : _reports.isEmpty
                      ? _buildEmptyState()
                      : _buildList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 60.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'lib/assets/images/sun-off.webp',
              width: 220.w,
              height: 220.w,
            ),
            SizedBox(height: 36.h),
            Text(
              'Aucun signalement',
              style: TextStyle(
                fontFamily: 'Baloo2',
                fontSize: 52.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
                color: kTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'Signalez une erreur depuis la fiche d\'un produit pour la voir apparaître ici.',
              style: TextStyle(fontSize: 40.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 60.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(28.w),
              decoration: const BoxDecoration(
                color: kSecondaryTag,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off, size: 80.sp, color: kAccentYellow),
            ),
            SizedBox(height: 36.h),
            Text(
              'Impossible de charger vos signalements',
              style: TextStyle(
                fontFamily: 'Baloo2',
                fontSize: 52.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
                color: kTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'Vérifiez votre connexion et réessayez.',
              style: TextStyle(fontSize: 40.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 48.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loadFirstPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentYellow,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(42.r),
                  ),
                ),
                child: Text(
                  'Réessayer',
                  style: TextStyle(fontSize: 42.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(48.w, 12.h, 48.w, 32.h),
      itemCount: _reports.length + 1 + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: EdgeInsets.only(bottom: 20.h),
            child: Text(
              '$_total signalement${_total > 1 ? 's' : ''} au total',
              style: TextStyle(
                fontSize: 38.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          );
        }
        if (index - 1 >= _reports.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return Padding(
          padding: EdgeInsets.only(bottom: 20.h),
          child: _buildReportCard(_reports[index - 1]),
        );
      },
    );
  }

  Widget _buildReportCard(ErrorReport report) {
    final statusColor = report.handled ? Colors.green[600]! : kAccentYellow;
    final statusIcon = report.handled ? Icons.check_circle : Icons.schedule;
    final statusLabel = report.handled ? 'Traité' : 'En attente';

    return Container(
      padding: EdgeInsets.all(30.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36.r),
        border: Border.all(color: kBorderDefault),
      ),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 44.sp,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary,
                      ),
                    ),
                    if (report.productName != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        report.ean,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 38.sp, color: Colors.grey[500]),
                      ),
                    ],
                    if (report.createdAt != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        DateFormat.yMMMd('fr_FR').format(report.createdAt!),
                        style: TextStyle(fontSize: 34.sp, color: Colors.grey[400]),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 20.w),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 40.sp, color: statusColor),
                  SizedBox(width: 8.w),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 38.sp,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            report.comment,
            style: TextStyle(fontSize: 40.sp, color: kTextPrimary, height: 1.3),
          ),
          if (report.response != null && report.response!.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Réponse de l\'équipe',
                    style: TextStyle(
                      fontSize: 36.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[800],
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    report.response!,
                    style: TextStyle(fontSize: 40.sp, color: kTextPrimary, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
