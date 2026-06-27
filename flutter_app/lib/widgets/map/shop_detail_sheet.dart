import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/models/shops/shop.dart';
import 'package:vegan_app/models/shops/shop_review.dart';
import 'package:vegan_app/models/shops/shop_scan_summary.dart';
import 'package:vegan_app/models/product_of_interest.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/services/auth_service.dart';
import 'package:vegan_app/services/products_of_interest_cache.dart';

class ShopDetailSheet extends StatefulWidget {
  final Shop shop;

  const ShopDetailSheet({super.key, required this.shop});

  @override
  State<ShopDetailSheet> createState() => _ShopDetailSheetState();
}

class _ShopDetailSheetState extends State<ShopDetailSheet>
    with SingleTickerProviderStateMixin {
  // Products tab state
  List<ShopScanSummary> _scanSummaries = [];
  Map<String, ProductOfInterest> _productsMap = {};
  bool _isLoadingProducts = true;
  bool _unscannedExpanded = false;
  final Set<String> _notFoundEans = {};
  final Set<String> _foundEans = {};
  String? _detailExpandedEan;

  // Reviews tab state
  List<ShopReview> _reviews = [];
  bool _isLoadingReviews = true;
  int _reviewsPage = 1;
  int _reviewsTotalPages = 1;
  ShopReview? _myReview;
  ShopReviewSummary? _reviewSummary;

  late TabController _tabController;

  String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://api.321vegan.fr';

  bool get _isLoggedIn => AuthService.isLoggedIn;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _isLoadingReviews) {
        _loadReviews();
      }
    });
    _loadProducts();
    _loadReviewSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Products ──────────────────────────────────────────────────────────────

  Future<void> _loadProducts() async {
    final results = await Future.wait([
      ApiService.getShopProducts(shopId: widget.shop.id),
      ProductsOfInterestCache.loadProductsOfInterest(),
    ]);

    final summaries = results[0] as List<ShopScanSummary>;
    final products = results[1] as List<ProductOfInterest>;

    final now = DateTime.now();
    final persistedNotFound = <String>{};
    final persistedFound = <String>{};
    for (final summary in summaries) {
      final notFoundAt = await PreferencesHelper.getProductNotFoundReportedAt(
          summary.ean, widget.shop.id);
      if (notFoundAt != null && now.difference(notFoundAt).inHours < 24) {
        persistedNotFound.add(summary.ean);
      }
      final foundAt = await PreferencesHelper.getProductFoundReportedAt(
          summary.ean, widget.shop.id);
      if (foundAt != null && now.difference(foundAt).inHours < 24) {
        persistedFound.add(summary.ean);
      }
    }

    if (mounted) {
      setState(() {
        _scanSummaries = summaries;
        _productsMap = {for (var p in products) p.ean: p};
        _notFoundEans.addAll(persistedNotFound);
        _foundEans.addAll(persistedFound);
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _reportFound(String ean) async {
    final success = await ApiService.postProductFoundReport(
      ean: ean,
      shopId: widget.shop.id,
    );
    if (success) {
      await PreferencesHelper.saveProductFoundReport(ean, widget.shop.id);
      if (mounted) setState(() => _foundEans.add(ean));
      final summaries =
          await ApiService.getShopProducts(shopId: widget.shop.id);
      if (mounted) setState(() => _scanSummaries = summaries);
    }
  }

  Future<void> _reportNotFound(String ean) async {
    final success = await ApiService.postProductNotFoundReport(
      ean: ean,
      shopId: widget.shop.id,
    );
    if (success) {
      await PreferencesHelper.saveProductNotFoundReport(ean, widget.shop.id);
      if (mounted) setState(() => _notFoundEans.add(ean));
      final summaries =
          await ApiService.getShopProducts(shopId: widget.shop.id);
      if (mounted) setState(() => _scanSummaries = summaries);
    }
  }

  Map<String, List<ShopScanSummary>> _groupByCategory() {
    final grouped = <String, List<ShopScanSummary>>{};
    for (final summary in _scanSummaries) {
      final product = _productsMap[summary.ean];
      final category = product?.categoryName.isNotEmpty == true
          ? product!.categoryName
          : 'Autre';
      grouped.putIfAbsent(category, () => []).add(summary);
    }
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  List<ProductOfInterest> _getUnscannedProducts() {
    final scannedEans = _scanSummaries.map((s) => s.ean).toSet();
    return _productsMap.values
        .where((p) => !scannedEans.contains(p.ean))
        .toList()
      ..sort((a, b) => a.categoryName.compareTo(b.categoryName));
  }

  // ── Reviews ───────────────────────────────────────────────────────────────

  Future<void> _loadReviewSummary() async {
    final summary =
        await ApiService.getShopReviewSummary(shopId: widget.shop.id);
    if (mounted) setState(() => _reviewSummary = summary);
  }

  Future<void> _loadReviews({int page = 1}) async {
    if (!mounted) return;
    setState(() => _isLoadingReviews = true);

    final results = await Future.wait([
      ApiService.getShopReviews(shopId: widget.shop.id, page: page),
      if (_isLoggedIn) ApiService.getMyShopReview(shopId: widget.shop.id),
    ]);

    final paginated = results[0] as ShopReviewPaginated?;
    final myReview = _isLoggedIn ? results[1] as ShopReview? : null;

    if (mounted) {
      setState(() {
        final currentUserId = AuthService.currentUser?.id;
        _reviews = (paginated?.items ?? [])
            .where((r) => currentUserId == null || r.userId != currentUserId)
            .toList();
        _reviewsPage = page;
        _reviewsTotalPages = paginated?.pages ?? 1;
        _myReview = myReview;
        _isLoadingReviews = false;
      });
    }
  }

  Future<void> _showReviewDialog({ShopReview? existing}) async {
    int selectedRating = existing?.rating ?? 0;
    final commentController =
        TextEditingController(text: existing?.comment ?? '');

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).scaffoldBackgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            padding: EdgeInsets.only(
              left: 24.w,
              right: 24.w,
              top: 12.h,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 64.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  existing == null ? 'Laisser un avis' : 'Modifier votre avis',
                  style:
                      TextStyle(fontSize: 52.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return GestureDetector(
                      onTap: () =>
                          setSheetState(() => selectedRating = i + 1),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Icon(
                          i < selectedRating ? Icons.star : Icons.star_border,
                          size: 80.r,
                          color: Colors.amber,
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: 20.h),
                TextFormField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Dites-nous ce que vous pensez !',
                    border: const OutlineInputBorder(),
                    labelStyle: TextStyle(fontSize: 44.sp),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 44.sp),
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child:
                            Text('Annuler', style: TextStyle(fontSize: 44.sp)),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedRating == 0
                            ? null
                            : () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child:
                            Text('Envoyer', style: TextStyle(fontSize: 44.sp)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );

    if (confirmed != true) return;

    ShopReview? result;
    if (existing == null) {
      result = await ApiService.postShopReview(
        shopId: widget.shop.id,
        rating: selectedRating,
        comment: commentController.text.trim().isEmpty
            ? null
            : commentController.text.trim(),
      );
    } else {
      result = await ApiService.updateShopReview(
        reviewId: existing.id,
        rating: selectedRating,
        comment: commentController.text.trim().isEmpty
            ? null
            : commentController.text.trim(),
      );
    }

    if (result != null && mounted) {
      setState(() => _myReview = result);
      await _loadReviews(page: _reviewsPage);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Avis soumis, en attente de validation.',
              style: TextStyle(fontSize: 44.sp),
            ),
          ),
        );
      }
    }
  }

  // ── Itinerary ─────────────────────────────────────────────────────────────

  Future<void> _openItinerary() async {
    final shop = widget.shop;
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${shop.latitude},${shop.longitude}',
    );
    final launched =
        await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible d\'ouvrir l\'itinéraire.',
            style: TextStyle(fontSize: 44.sp),
          ),
        ),
      );
    }
  }

  // ── Build helpers ─────────────────────────────────────────────────────────

  Color _scoreColor(double score) {
    if (score >= 0.7) return Colors.green;
    if (score >= 0.4) return Colors.orange;
    return Colors.red;
  }

  Widget _buildProductsTab(ScrollController scrollController) {
    if (_isLoadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    return _buildGroupedList(scrollController);
  }

  Widget _buildGroupedList(ScrollController scrollController) {
    final grouped = _groupByCategory();
    final unscanned = _getUnscannedProducts();

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 64.h + MediaQuery.of(context).padding.bottom),
      children: [
        if (grouped.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Text(
              'Aucun produit scanné dans ce magasin',
              style: TextStyle(
                fontSize: 50.sp,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final entry in grouped.entries) ...[
            Padding(
              padding: EdgeInsets.only(top: 12.h, bottom: 4.h),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 48.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            for (final s in entry.value) ...[
              _buildProductRow(s),
            ],
          ],
        if (unscanned.isNotEmpty) ...[
          SizedBox(height: 16.h),
          Divider(height: 1.h),
          GestureDetector(
            onTap: () =>
                setState(() => _unscannedExpanded = !_unscannedExpanded),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Row(
                children: [
                  Icon(
                    _unscannedExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Pas présent ou pas encore scanné (${unscanned.length})',
                    style: TextStyle(
                      fontSize: 46.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_unscannedExpanded) _buildUnscannedGrid(unscanned),
        ],
      ],
    );
  }

  Widget _buildUnscannedGrid(List<ProductOfInterest> products) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.w,
        mainAxisSpacing: 8.h,
        childAspectRatio: 0.75,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: product.image.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: '$_baseUrl/${product.image}',
                        fit: BoxFit.contain,
                        placeholder: (_, __) => Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.image, color: Colors.grey[400]),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.image, color: Colors.grey[400]),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.image, color: Colors.grey[400]),
                      ),
              ),
            ),
            Text(
              product.name,
              style: TextStyle(
                fontSize: 34.sp,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  Widget _buildScorePill(ShopScanSummary summary) {
    final score = summary.presenceScore;
    final color = _scoreColor(score);
    final percent = (score * 100).round();
    final isExpanded = _detailExpandedEan == summary.ean;

    return Row(
      children: [
        Container(
          width: 100.w,
          height: 12.h,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: score,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6.r),
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          '$percent%',
          style: TextStyle(
            fontSize: 40.sp,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          'probabilité de présence',
          style: TextStyle(
            fontSize: 38.sp,
            color: Colors.grey[500],
          ),
        ),
        Icon(
          isExpanded ? Icons.expand_less : Icons.expand_more,
          size: 44.r,
          color: Colors.grey[400],
        ),
      ],
    );
  }

  Widget _buildScoreDetails(ShopScanSummary summary, bool isNotFound) {
    final score = summary.presenceScore;
    final color = _scoreColor(score);
    final relevantCount = summary.notFoundCount;

    return Container(
      margin: EdgeInsets.only(top: 8.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailLine(
            Icons.schedule,
            'Dernier scan il y a ${summary.daysSinceLastScan} jours',
            Colors.blueGrey,
          ),
          SizedBox(height: 6.h),
          _buildDetailLine(
            Icons.bar_chart,
            'Scanné ${summary.scanCount} fois',
            Colors.indigo,
          ),
          SizedBox(height: 6.h),
          _buildDetailLine(
            Icons.search_off,
            relevantCount > 0
                ? '$relevantCount signalement(s) d\'absence'
                : 'Aucun signalement d\'absence',
            relevantCount > 0 ? Colors.orange : Colors.green,
          ),
          SizedBox(height: 12.h),
          Divider(height: 1.h, color: color.withValues(alpha: 0.15)),
          SizedBox(height: 10.h),
          if (isNotFound)
            Row(
              children: [
                Icon(Icons.check_circle,
                    size: 44.r, color: Colors.orange.withValues(alpha: 0.8)),
                SizedBox(width: 6.w),
                Text(
                  'Absence signalée',
                  style: TextStyle(
                    fontSize: 42.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                GestureDetector(
                  onTap: () => _reportNotFound(summary.ean),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.r),
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 44.r, color: Colors.red[400]),
                        SizedBox(width: 4.w),
                        Text(
                          'Pas trouvé',
                          style: TextStyle(
                            fontSize: 42.sp,
                            color: Colors.red[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                if (_foundEans.contains(summary.ean))
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 44.r, color: Colors.green.withValues(alpha: 0.8)),
                      SizedBox(width: 6.w),
                      Text(
                        'Présence signalée',
                        style: TextStyle(
                          fontSize: 42.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  )
                else
                  GestureDetector(
                    onTap: () => _reportFound(summary.ean),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 18.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.r),
                        color: Colors.green[50],
                        border: Border.all(color: Colors.green[400]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search,
                              size: 44.r, color: Colors.green[600]),
                          SizedBox(width: 4.w),
                          Text(
                            'Trouvé',
                            style: TextStyle(
                              fontSize: 42.sp,
                              color: Colors.green[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailLine(IconData icon, String text, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 42.r, color: iconColor.withValues(alpha: 0.7)),
        SizedBox(width: 8.w),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 38.sp, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildProductRow(ShopScanSummary summary) {
    final product = _productsMap[summary.ean];
    final isNotFound = _notFoundEans.contains(summary.ean);

    return GestureDetector(
      onTap: () {
        setState(() {
          _detailExpandedEan =
              _detailExpandedEan == summary.ean ? null : summary.ean;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: SizedBox(
                width: 200.w,
                height: 200.w,
                child: product != null && product.image.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: '$_baseUrl/${product.image}',
                        fit: BoxFit.contain,
                        placeholder: (_, __) => Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.image, color: Colors.grey[400]),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.image, color: Colors.grey[400]),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.image, color: Colors.grey[400]),
                      ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: product?.name ?? summary.ean,
                          style: TextStyle(
                            fontSize: 52.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (product?.brandName != null &&
                            product!.brandName.isNotEmpty)
                          TextSpan(
                            text: '  ${product.brandName}',
                            style: TextStyle(
                              fontSize: 40.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  _buildScorePill(summary),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: _buildScoreDetails(summary, isNotFound),
                    crossFadeState: _detailExpandedEan == summary.ean
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reviews tab ───────────────────────────────────────────────────────────

  Widget _buildReviewsTab(ScrollController scrollController) {
    if (_isLoadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 24.h + MediaQuery.of(context).padding.bottom),
      children: [
        if (_reviews.isEmpty) ...[
          _buildEmptyReviews(),
          SizedBox(height: 20.h),
          _buildMyReviewSection(),
        ] else ...[
          _buildMyReviewSection(),
          SizedBox(height: 16.h),
          for (final review in _reviews) _buildReviewCard(review),
          SizedBox(height: 12.h),
          _buildPaginationControls(),
        ],
      ],
    );
  }

  Widget _buildEmptyReviews() {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
      child: Column(
        children: [
          // Speech bubble with a little tail
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(28.r),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 110.r,
                  color: primary,
                ),
              ),
              Positioned(
                right: 18.w,
                top: 14.h,
                child: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.star, size: 40.r, color: Colors.white),
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Text(
            'Aucun avis pour le moment',
            style: TextStyle(
              fontSize: 50.sp,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            'Soyez le premier à mettre un avis 🌱',
            style: TextStyle(fontSize: 44.sp, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMyReviewSection() {
    if (!_isLoggedIn) {
      return Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Text(
          'Connectez-vous pour laisser un avis.',
          style: TextStyle(fontSize: 46.sp, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_myReview != null) {
      return Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Votre avis',
                  style: TextStyle(
                    fontSize: 48.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showReviewDialog(existing: _myReview),
                  child: Icon(Icons.edit,
                      size: 48.r,
                      color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            _buildStars(_myReview!.rating),
            if (_myReview!.comment != null &&
                _myReview!.comment!.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                _myReview!.comment!,
                style: TextStyle(fontSize: 44.sp, color: Colors.grey[700]),
              ),
            ],
            SizedBox(height: 4.h),
            Text(
              _myReview!.status == 'approved'
                  ? 'Validé'
                  : 'En attente de validation',
              style: TextStyle(
                fontSize: 38.sp,
                fontStyle: FontStyle.italic,
                color: _myReview!.status == 'approved'
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
      onTap: () => _showReviewDialog(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rate_review,
              color: Colors.white,
              size: 60.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              'Laisser un avis',
              style: TextStyle(
                fontSize: 45.sp,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildReviewCard(ShopReview review) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                review.userNickname ?? 'Anonyme',
                style: TextStyle(
                  fontSize: 46.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (review.createdAt != null)
                Text(
                  _formatDate(review.createdAt!),
                  style:
                      TextStyle(fontSize: 38.sp, color: Colors.grey[500]),
                ),
            ],
          ),
          SizedBox(height: 4.h),
          _buildStars(review.rating),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              review.comment!,
              style: TextStyle(fontSize: 44.sp, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStars(int rating) {
    return Row(
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star : Icons.star_border,
          size: 48.r,
          color: Colors.amber,
        );
      }),
    );
  }

  Widget _buildPaginationControls() {
    if (_reviewsTotalPages <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, size: 56.r),
          onPressed: _reviewsPage > 1
              ? () => _loadReviews(page: _reviewsPage - 1)
              : null,
        ),
        Text(
          '$_reviewsPage / $_reviewsTotalPages',
          style: TextStyle(fontSize: 46.sp),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right, size: 56.r),
          onPressed: _reviewsPage < _reviewsTotalPages
              ? () => _loadReviews(page: _reviewsPage + 1)
              : null,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // ── Main build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
          children: [
            // Handle bar
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            // Shop header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      shop.shopType == 'vegan'
                          ? Icon(
                              Icons.eco,
                              color: Colors.green,
                              size: 64.r,
                            )
                          : Icon(
                              Icons.storefront,
                              color: Theme.of(context).colorScheme.primary,
                              size: 64.r,
                            ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                shop.name,
                                style: TextStyle(
                                  fontSize: 64.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (shop.shopType == 'vegan')
                              Container(
                                margin: EdgeInsets.only(left: 24.w),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4.r),
                                  border: Border.all(
                                    color: Colors.green.shade300,
                                  ),
                                ),
                                child: Text(
                                  '100% Vegan',
                                  style: TextStyle(
                                    fontSize: 36.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                    Padding(
                      padding: EdgeInsets.only(top: 4.h, left: 32.w),
                      child: Text(
                        () {
                          final address = [shop.address, shop.city]
                              .where((s) => s != null)
                              .join(', ');
                          return address.isEmpty ? 'Adresse inconnue' : address;
                        }(),
                        style: TextStyle(
                          fontSize: 50.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  if (_reviewSummary != null && _reviewSummary!.reviewCount > 0)
                    Padding(
                      padding: EdgeInsets.only(top: 6.h, left: 32.w),
                      child: Row(
                        children: [
                          ...List.generate(5, (i) {
                            final avg = _reviewSummary!.ratingAvg;
                            IconData icon;
                            if (i < avg.floor()) {
                              icon = Icons.star;
                            } else if (i < avg && avg - i >= 0.5) {
                              icon = Icons.star_half;
                            } else {
                              icon = Icons.star_border;
                            }
                            return Icon(icon,
                                size: 44.r, color: Colors.amber);
                          }),
                          SizedBox(width: 6.w),
                          Text(
                            _reviewSummary!.ratingAvg.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 44.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            '(${_reviewSummary!.reviewCount})',
                            style: TextStyle(
                              fontSize: 42.sp,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Tab bar
            TabBar(
              controller: _tabController,
              tabs: [
                const Tab(text: 'Produits'),
                Tab(
                  text: _reviewSummary != null && _reviewSummary!.reviewCount > 0
                      ? 'Avis (${_reviewSummary!.reviewCount})'
                      : 'Avis',
                ),
              ],
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProductsTab(scrollController),
                  _buildReviewsTab(scrollController),
                ],
              ),
            ),
          ],
        ),
            // Floating itinerary button (straddles the top edge)
            Positioned(
              top: -50.h,
              right: 16.w,
              child: GestureDetector(
                onTap: _openItinerary,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(24.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.directions,
                        color: Colors.white,
                        size: 56.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Itinéraire',
                        style: TextStyle(
                          fontSize: 45.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
