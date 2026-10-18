import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/models/product_rating.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_spacing.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/reviews/product_ratings_sheet.dart';
import 'package:vegan_app/widgets/reviews/rating_status_chip.dart';
import 'package:vegan_app/widgets/reviews/review_card.dart';
import 'package:vegan_app/widgets/shared/app_background.dart';
import 'package:vegan_app/widgets/shared/empty_state_view.dart';

/// Full-screen page listing the products rated by the current user, with
/// each rating's moderation status. Tapping one opens the product's
/// ratings sheet to edit it. Pushed from Settings.
class MyProductRatingsPage extends StatefulWidget {
  const MyProductRatingsPage({super.key});

  @override
  State<MyProductRatingsPage> createState() => _MyProductRatingsPageState();
}

class _MyProductRatingsPageState extends State<MyProductRatingsPage> {
  static const _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<ProductRating> _ratings = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  int _page = 1;
  int _pages = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
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

  Future<void> _loadFirstPage({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    final result =
        await ApiService.getMyProductRatings(page: 1, pageSize: _pageSize);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result == null) {
        _hasError = true;
      } else {
        _hasError = false;
        _ratings
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
    final result = await ApiService.getMyProductRatings(
        page: nextPage, pageSize: _pageSize);
    if (!mounted) return;
    setState(() {
      _isLoadingMore = false;
      if (result != null) {
        _ratings.addAll(result.items);
        _page = nextPage;
        _pages = result.pages;
      }
    });
  }

  Future<void> _openProduct(ProductRating rating) async {
    await showProductRatingsSheet(
      context,
      ean: rating.ean,
      productName: rating.productName,
      brandName: rating.brandName,
    );
    // The rating may have been edited in the sheet.
    if (mounted) _loadFirstPage(showLoader: false);
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Mes notes', style: AppTextStyles.baloo22),
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
                  ? EmptyStateView(
                      title: 'Impossible de charger vos notes',
                      subtitle: 'Vérifiez votre connexion et réessayez.',
                      buttonLabel: 'Réessayer',
                      onButtonTap: _loadFirstPage,
                    )
                  : _ratings.isEmpty
                      ? const EmptyStateView(
                          title: 'Aucune note',
                          subtitle:
                              'Notez un produit vegan depuis le scan ou le Vegandex pour le retrouver ici.',
                        )
                      : _buildList(),
        ),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: () => _loadFirstPage(showLoader: false),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal, 12.h, AppSpacing.pageHorizontal, 32.h),
        itemCount: _ratings.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => SizedBox(height: AppSpacing.item),
        itemBuilder: (context, index) {
          if (index >= _ratings.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final rating = _ratings[index];
          return ReviewCard(
            nickname: rating.userNickname,
            showAuthor: false,
            rating: rating.rating,
            comment: rating.comment,
            date: rating.createdAt,
            badge: RatingStatusChip(status: rating.status),
            header: _buildProductHeader(rating),
            onTap: () => _openProduct(rating),
          );
        },
      ),
    );
  }

  Widget _buildProductHeader(ProductRating rating) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rating.productName ?? rating.ean,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.baloo17,
              ),
              if (rating.brandName != null) ...[
                SizedBox(height: 4.h),
                Text(
                  rating.brandName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLight15,
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: 16.w),
        Icon(Icons.arrow_forward_ios, size: 32.sp, color: Colors.grey[400]),
      ],
    );
  }
}
