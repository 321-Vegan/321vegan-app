import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/models/error_report.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/services/auth_service.dart';
import 'package:vegan_app/services/error_report_badge_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/shared/app_background.dart';

/// Full-screen page listing the error reports sent by the current user,
/// with their status and the team's response once handled.
/// Pushed from Settings and from the Dashboard.
///
/// [initialData] lets the caller reuse an already fetched first page instead
/// of refetching it; it must have been fetched with [pageSize] items.
class ErrorReportsPage extends StatefulWidget {
  /// Must match [initialData]'s page size so "load more" page numbers line
  /// up. Owned by the badge service, which performs the initial fetch.
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
  int _page = 1;
  int _pages = 1;
  String? _avatar;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialData;
    if (initial != null) {
      _isLoading = false;
      _reports.addAll(initial.items);
      _pages = initial.pages;
    } else {
      _loadFirstPage();
    }
    _scrollController.addListener(_onScroll);
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final avatar = await PreferencesHelper.getAvatar();
    if (mounted) setState(() => _avatar = avatar);
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
          title: Text(
            'Mes signalements',
            style: AppTextStyles.baloo22,
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
              'lib/assets/images/characters/lemon-mby.webp',
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
                  shape: squircleBorder(radius: 42.r),
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
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(48.w, 12.h, 48.w, 32.h),
      children: [
        ..._buildGroupedItems(),
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }

  /// Flattens [_reports] into date-header / card widgets, one header per
  /// calendar day.
  List<Widget> _buildGroupedItems() {
    final items = <Widget>[];
    DateTime? lastDay;
    for (final report in _reports) {
      final created = report.createdAt;
      final day =
          created != null ? DateTime(created.year, created.month, created.day) : null;
      if (day != null && day != lastDay) {
        items.add(Padding(
          padding: EdgeInsets.only(top: lastDay == null ? 0 : 12.h, bottom: 16.h),
          child: Text(
            DateFormat('d MMMM y', 'fr_FR').format(day),
            style: AppTextStyles.baloo22
          ),
        ));
        lastDay = day;
      }
      items.add(Padding(
        padding: EdgeInsets.only(bottom: 20.h),
        child: _buildReportCard(report),
      ));
    }
    return items;
  }

  /// "Aujourd'hui/Hier à HH:mm" for a recent message, falling back to a full
  /// date for anything older.
  String _relativeTimeLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final time = DateFormat('HH:mm').format(date);
    switch (today.difference(day).inDays) {
      case 0:
        return 'Aujourd\'hui à $time';
      case 1:
        return 'Hier à $time';
      default:
        return '${DateFormat.yMMMd('fr_FR').format(date)} à $time';
    }
  }

  Widget _buildReportCard(ErrorReport report) {
    final statusColor = report.handled ? kSemanticSuccess : kAccentYellow;
    final statusBackground = report.handled ? kPrimaryTag : kSecondaryTag;
    final statusLabel = report.handled ? 'Traitée' : 'En cours';
    final nickname = AuthService.currentUser?.nickname;
    final userName = nickname != null && nickname.isNotEmpty ? nickname : 'Vous';

    return Container(
      padding: EdgeInsets.all(30.w),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 36.r,
          side: const BorderSide(color: kBorderDefault),
        ),
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
                      style: AppTextStyles.baloo17
                    ),
                    if (report.productName != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        report.ean,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLight15,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                decoration: ShapeDecoration(
                  color: statusBackground,
                  shape: squircleBorder(radius: 20.r),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 34.sp,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          _messageRow(
            avatar: _userAvatar(),
            name: userName,
            time: report.createdAt,
            message: report.comment,
          ),
          if (report.response != null && report.response!.isNotEmpty) ...[
            SizedBox(height: 20.h),
            _messageRow(
              avatar: _staffAvatar(context),
              name: "L'équipe 321 Vegan",
              time: report.createdAt,
              message: report.response!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _messageRow({
    required Widget avatar,
    required String name,
    required DateTime? time,
    required String message,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        avatar,
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 38.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                  if (time != null) ...[
                    SizedBox(width: 10.w),
                    Text(
                      _relativeTimeLabel(time),
                      style: TextStyle(fontSize: 32.sp, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                message,
                style: TextStyle(fontSize: 40.sp, color: kTextPrimary, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Contain-fit rather than clipped/cover: the avatar assets are irregular
  /// transparent shapes that crop oddly under a hard circle clip.
  Widget _userAvatar() {
    return SizedBox(
      width: 128.w,
      height: 128.w,
      child: Image.asset(
        'lib/assets/avatars/${_avatar ?? 'cochon.png'}',
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _staffAvatar(BuildContext context) {
    return Container(
      width: 128.w,
      height: 128.w,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        'lib/assets/app_icon.png'),
    );
  }
}
