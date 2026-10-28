import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vegan_app/helpers/external_links.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/models/shops/shop.dart';
import 'package:vegan_app/models/shops/shop_review.dart';
import 'package:vegan_app/models/shops/shop_scan_summary.dart';
import 'package:vegan_app/models/product_of_interest.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/services/auth_service.dart';
import 'package:vegan_app/services/products_of_interest_cache.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/models/review_status.dart';
import 'package:vegan_app/themes/app_spacing.dart';
import 'package:vegan_app/widgets/reviews/rating_status_chip.dart';
import 'package:vegan_app/widgets/reviews/review_card.dart';
import 'package:vegan_app/widgets/reviews/review_form_sheet.dart';
import 'package:vegan_app/widgets/reviews/reviews_empty_state.dart';
import 'package:vegan_app/widgets/shared/app_button.dart';
import 'package:vegan_app/widgets/shared/square_icon_button.dart';

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

  // Once dismissed, don't show the probability-score explainer again for the
  // rest of the app session (any shop).
  static bool _probaBannerDismissed = false;

  // Reviews tab state
  List<ShopReview> _reviews = [];
  bool _isLoadingReviews = true;
  int _reviewsPage = 1;
  int _reviewsTotalPages = 1;
  ShopReview? _myReview;
  ShopReviewSummary? _reviewSummary;
  bool _reviewsError = false;
  bool _isSendingReview = false;

  /// Key of this shop's unsent entry in [ReviewDrafts].
  String get _reviewDraftKey => 'shop:${widget.shop.id}';

  /// Inline confirmation/error under the user's review — a SnackBar would
  /// render behind this modal sheet.
  ({String text, Color color})? _reviewFeedback;

  late TabController _tabController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  static const double _minSheetSize = 0.3;
  static const double _maxSheetSize = 0.85;

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
    _sheetController.dispose();
    super.dispose();
  }

  void _onHandleDragUpdate(DragUpdateDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;
    final newSize = _sheetController.size - details.delta.dy / screenHeight;
    _sheetController.jumpTo(newSize.clamp(_minSheetSize, _maxSheetSize));
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
    setState(() {
      _isLoadingReviews = true;
      _reviewsError = false;
    });

    // A failed "my review" fetch must not pass for "no review yet": the
    // button would then post a duplicate instead of editing it.
    var myReviewFailed = false;
    final results = await Future.wait([
      ApiService.getShopReviews(shopId: widget.shop.id, page: page),
      if (_isLoggedIn)
        ApiService.getMyShopReview(shopId: widget.shop.id).catchError((_) {
          myReviewFailed = true;
          return null;
        }),
    ]);

    final paginated = results[0] as ShopReviewPaginated?;
    final myReview = _isLoggedIn ? results[1] as ShopReview? : null;

    if (paginated == null || myReviewFailed) {
      if (mounted) {
        setState(() {
          _isLoadingReviews = false;
          _reviewsError = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        final currentUserId = AuthService.currentUser?.id;
        _reviews = paginated.items
            .where((r) => currentUserId == null || r.userId != currentUserId)
            .toList();
        _reviewsPage = page;
        _reviewsTotalPages = paginated.pages;
        _myReview = myReview;
        _isLoadingReviews = false;
      });
    }
  }

  Future<void> _showReviewDialog({ShopReview? existing}) async {
    final draft = ReviewDrafts.get(_reviewDraftKey);
    final entry = await showReviewFormSheet(
      context,
      title: existing == null ? 'Laisser un avis' : 'Modifier votre avis',
      subtitle: widget.shop.name,
      initialRating: draft?.rating ?? existing?.rating,
      initialComment: draft != null ? draft.comment : existing?.comment,
    );
    if (entry == null || !mounted) return;

    setState(() {
      _isSendingReview = true;
      _reviewFeedback = null;
    });
    final result = existing == null
        ? await ApiService.postShopReview(
            shopId: widget.shop.id,
            rating: entry.rating,
            comment: entry.comment,
          )
        : await ApiService.updateShopReview(
            reviewId: existing.id,
            rating: entry.rating,
            comment: entry.comment,
          );
    if (!mounted) return;

    if (result == null) {
      ReviewDrafts.save(_reviewDraftKey, entry);
      setState(() {
        _isSendingReview = false;
        _reviewFeedback = (
          text: 'L\'envoi a échoué. Vérifiez votre connexion et réessayez !',
          color: kSemanticError,
        );
      });
      return;
    }

    ReviewDrafts.clear(_reviewDraftKey);
    setState(() {
      _isSendingReview = false;
      _myReview = result;
      _reviewFeedback = (
        text: 'Avis soumis, en attente de validation.',
        color: kSemanticSuccess,
      );
    });
    _loadReviewSummary();
    await _loadReviews(page: _reviewsPage);
  }

  // ── Itinerary ─────────────────────────────────────────────────────────────

  Future<void> _openItinerary() =>
      openItinerary(context, widget.shop.latitude, widget.shop.longitude);

  // ── Build helpers ─────────────────────────────────────────────────────────

  Color _scoreColor(double score) {
    if (score >= 0.7) return kSemanticSuccess;
    if (score >= 0.4) return kAccentYellow;
    return kSemanticError;
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
      padding: EdgeInsets.fromLTRB(
          48.w, 60.h, 48.w, 64.h + MediaQuery.of(context).padding.bottom),
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
        else ...[
          // Explains that tapping a probability ring expands the details
          if (!_probaBannerDismissed)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 30.h),
              decoration: ShapeDecoration(
                color: kSecondaryTag,
                shape: squircleBorder(
                  radius: 42.r,
                  side: const BorderSide(color: kAccentYellow),
                ),
              ),
              // Stack instead of a Row so the text can run as far right as
              // possible, only clearing the close cross itself.
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.only(right: 64.w),
                    child: Text(
                      'Cliquez sur le score de probabilité pour en savoir '
                      'plus et indiquer si vous avez trouvé l\'article.',
                      style: TextStyle(
                        fontSize: 40.sp,
                        color: kAccentYellow,
                        height: 1.3,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _probaBannerDismissed = true),
                      child:
                          Icon(Icons.close, size: 52.sp, color: kAccentYellow),
                    ),
                  ),
                ],
              ),
            ),
          for (final entry in grouped.entries) ...[
            Padding(
              padding: EdgeInsets.only(top: 60.h, bottom: 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: AppTextStyles.baloo22,
                    ),
                  ),
                  Text(
                    'Probabilité',
                    style: AppTextStyles.bodyMedium13
                        .copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            for (final s in entry.value) ...[
              _buildProductRow(s),
            ],
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
              child: ClipSmoothRect(
                radius: squircleRadius(8.r),
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

  /// Circular presence-score gauge with the percentage inside (Figma).
  Widget _buildScoreRing(ShopScanSummary summary) {
    final score = summary.presenceScore;
    final color = _scoreColor(score);
    final percent = (score * 100).round();

    return SizedBox(
      width: 130.w,
      height: 130.w,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score,
            strokeWidth: 18.w,
            strokeCap: StrokeCap.round,
            backgroundColor: color.withValues(alpha: 0.2),
            color: color,
          ),
          Center(
            child: Text(
              '$percent%',
              style: AppTextStyles.bodyMedium13.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreDetails(ShopScanSummary summary, bool isNotFound) {
    final relevantCount = summary.notFoundCount;

    return Container(
      margin: EdgeInsets.only(top: 18.h),
      padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 30.h),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 42.r,
          side: const BorderSide(color: kBorderDefault),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailLine(
            Icons.schedule,
            'Dernier scan il y a ${summary.daysSinceLastScan} jours',
          ),
          SizedBox(height: 14.h),
          _buildDetailLine(
            Icons.bar_chart,
            'Scanné ${summary.scanCount} fois',
          ),
          SizedBox(height: 14.h),
          _buildDetailLine(
            Icons.search_off,
            relevantCount > 0
                ? '$relevantCount signalement(s) d\'absence'
                : 'Aucun signalement d\'absence',
          ),
          SizedBox(height: 24.h),
          const Divider(height: 1, color: kBorderDefault),
          SizedBox(height: 24.h),
          if (isNotFound)
            _buildReportedStatus('Absence signalée')
          else
            Row(
              children: [
                _buildReportPill(
                  icon: Icons.search_off,
                  label: 'Pas trouvé',
                  color: kSemanticError,
                  onTap: () => _reportNotFound(summary.ean),
                ),
                SizedBox(width: 24.w),
                if (_foundEans.contains(summary.ean))
                  _buildReportedStatus('Présence signalée')
                else
                  _buildReportPill(
                    icon: Icons.search,
                    label: 'Trouvé',
                    color: Theme.of(context).colorScheme.primary,
                    onTap: () => _reportFound(summary.ean),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// White pill with a colored border/label, matching the redesign's
  /// secondary buttons.
  Widget _buildReportPill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 14.h),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: squircleBorder(radius: 42.r, side: BorderSide(color: color)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44.sp, color: color),
            SizedBox(width: 10.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 40.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportedStatus(String label) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: 44.sp, color: primary),
        SizedBox(width: 10.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 40.sp,
            fontWeight: FontWeight.w600,
            color: primary,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 44.sp, color: Colors.grey[500]),
        SizedBox(width: 16.w),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 40.sp, color: kTextPrimary),
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
        padding: EdgeInsets.symmetric(vertical: 18.h),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 165.w,
                  height: 165.w,
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(
                    color: Colors.grey[100],
                    shape: squircleBorder(radius: 30.r),
                  ),
                  child: product != null && product.image.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: '$_baseUrl/${product.image}',
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Icon(Icons.image, color: Colors.grey[400]),
                          errorWidget: (_, __, ___) =>
                              Icon(Icons.image, color: Colors.grey[400]),
                        )
                      : Icon(Icons.image, color: Colors.grey[400]),
                ),
                SizedBox(width: 30.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product?.name ?? summary.ean,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 44.sp,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary,
                          height: 1.2,
                        ),
                      ),
                      if (product?.brandName != null &&
                          product!.brandName.isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        Text(
                          product.brandName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 38.sp,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 30.w),
                _buildScoreRing(summary),
              ],
            ),
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
    );
  }

  // ── Reviews tab ───────────────────────────────────────────────────────────

  Widget _buildReviewsTab(ScrollController scrollController) {
    if (_isLoadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
          16.w, 24.h, 16.w, 24.h + MediaQuery.of(context).padding.bottom),
      children: [
        if (_reviewsError) ...[
          const ReviewsEmptyState(
            title: 'Impossible de charger les avis',
            subtitle: 'Vérifiez votre connexion et réessayez.',
          ),
          SizedBox(height: AppSpacing.item),
          Center(
            child: AppButton(
              label: 'Réessayer',
              backgroundColor: kAccentYellow,
              onPressed: () {
                _loadReviewSummary();
                _loadReviews(page: _reviewsPage);
              },
            ),
          ),
        ] else if (_reviews.isEmpty) ...[
          _buildEmptyReviews(),
          SizedBox(height: 20.h),
          ..._buildMyReviewSection(),
        ] else ...[
          ..._buildMyReviewSection(),
          SizedBox(height: 16.h),
          for (final review in _reviews) _buildReviewCard(review),
          SizedBox(height: 12.h),
          _buildPaginationControls(),
        ],
      ],
    );
  }

  Widget _buildEmptyReviews() {
    // _reviews excludes the user's own review: if they left one, it's not
    // "no review" but "no other review".
    if (_myReview != null) {
      return const ReviewsEmptyState(
        title: 'Pas d\'autre avis pour le moment',
        subtitle: 'Les avis des autres utilisateur·ices apparaîtront ici.',
      );
    }
    return const ReviewsEmptyState(
      subtitle: 'Soyez la première personne à mettre un avis 🌱',
    );
  }

  /// The user's review (or the button to write one), followed by the
  /// inline send feedback.
  List<Widget> _buildMyReviewSection() {
    final feedback = _reviewFeedback;
    return [
      _buildMyReview(),
      if (feedback != null) ...[
        SizedBox(height: 18.h),
        Text(
          feedback.text,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium13.copyWith(color: feedback.color),
        ),
      ],
    ];
  }

  Widget _buildMyReview() {
    final primary = Theme.of(context).colorScheme.primary;

    if (!_isLoggedIn) {
      return Text(
        'Connectez-vous pour laisser un avis.',
        style: AppTextStyles.bodyRegular15.copyWith(color: Colors.grey[600]),
        textAlign: TextAlign.center,
      );
    }

    final mine = _myReview;
    if (mine != null) {
      return ReviewCard(
        nickname: mine.userNickname ?? AuthService.currentUser?.nickname,
        isPremium: mine.userIsPremium,
        rating: mine.rating,
        comment: mine.comment,
        date: mine.createdAt,
        highlighted: true,
        badge: RatingStatusChip(status: ReviewStatus.fromApi(mine.status)),
        trailing: _isSendingReview
            ? SizedBox(
                width: 48.sp,
                height: 48.sp,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.edit_outlined, size: 54.sp, color: primary),
        onTap:
            _isSendingReview ? null : () => _showReviewDialog(existing: mine),
      );
    }

    return Center(
      child: AppButton(
        label: 'Laisser un avis',
        icon: Icons.rate_review,
        backgroundColor: primary,
        isLoading: _isSendingReview,
        onPressed: _isSendingReview ? null : () => _showReviewDialog(),
      ),
    );
  }

  Widget _buildReviewCard(ShopReview review) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.item),
      child: ReviewCard(
        nickname: review.userNickname,
        isPremium: review.userIsPremium,
        rating: review.rating,
        comment: review.comment,
        date: review.createdAt,
      ),
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

  // ── Main build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.75,
      minChildSize: _minSheetSize,
      maxChildSize: _maxSheetSize,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: squircleBorderOnly(topLeft: 72.r, topRight: 72.r),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Draggable handle that resizes the sheet.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: _onHandleDragUpdate,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Icon(
                    Icons.keyboard_arrow_up,
                    size: 60.sp,
                    color: Colors.grey[500],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 48.w, vertical: 12.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  shop.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.baloo26,
                                ),
                              ),
                              if (_reviewSummary != null &&
                                  _reviewSummary!.reviewCount > 0) ...[
                                SizedBox(width: 18.w),
                                Icon(Icons.star,
                                    size: 48.sp, color: kAccentYellow),
                                SizedBox(width: 6.w),
                                Text(
                                  _reviewSummary!.ratingAvg.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 44.sp,
                                    fontWeight: FontWeight.w600,
                                    color: kAccentYellow,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  '(${_reviewSummary!.reviewCount} avis)',
                                  style: TextStyle(
                                    fontSize: 40.sp,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            () {
                              final address = [shop.address, shop.city]
                                  .where((s) => s != null)
                                  .join(', ');
                              return address.isEmpty
                                  ? 'Adresse inconnue'
                                  : address;
                            }(),
                            style: AppTextStyles.bodyMedium15
                                .copyWith(color: Colors.grey[600]),
                          ),
                          if (shop.shopType == 'vegan')
                            Padding(
                              padding: EdgeInsets.only(top: 8.h),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20.w,
                                  vertical: 4.h,
                                ),
                                decoration: ShapeDecoration(
                                  color:
                                      kSemanticSuccess.withValues(alpha: 0.1),
                                  shape: squircleBorder(
                                    radius: 12.r,
                                    side: BorderSide(
                                      color: kSemanticSuccess.withValues(
                                          alpha: 0.3),
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '100% Vegan',
                                  style: TextStyle(
                                    fontSize: 36.sp,
                                    fontWeight: FontWeight.w600,
                                    color: kSemanticSuccess,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: 24.w),
                    SquareIconButton(
                      onTap: _openItinerary,
                      size: 102.w,
                      radius: 30.r,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shadows: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      child: Icon(
                        Icons.map,
                        color: Colors.white,
                        size: 54.sp,
                      ),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                tabs: [
                  const Tab(text: 'Produits'),
                  Tab(
                    text: _reviewSummary != null &&
                            _reviewSummary!.reviewCount > 0
                        ? 'Avis (${_reviewSummary!.reviewCount})'
                        : 'Avis',
                  ),
                ],
              ),
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
        );
      },
    );
  }
}
