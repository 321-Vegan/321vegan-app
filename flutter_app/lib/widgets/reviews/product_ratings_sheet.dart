import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/product_rating.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';
import '../auth/auth_bottom_sheet.dart';
import '../shared/app_button.dart';
import '../shared/tag_chip.dart';
import 'rating_status_chip.dart';
import 'rating_summary.dart';
import 'review_card.dart';
import 'review_form_sheet.dart';
import 'reviews_empty_state.dart';

/// Opens a product's ratings: average + distribution, the current user's
/// own rating (to add or edit it) and the community's approved ratings.
/// Same sheet from the scan result, the Vegandex and "Mes notes".
///
/// Resolves once closed; callers refresh what they display then, since the
/// user may have rated in between (a pop result would be lost on a drag
/// dismiss).
Future<void> showProductRatingsSheet(
  BuildContext context, {
  required String ean,
  String? productName,
  String? brandName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProductRatingsSheet(
      ean: ean,
      productName: productName,
      brandName: brandName,
    ),
  );
}

class _ProductRatingsSheet extends StatefulWidget {
  final String ean;
  final String? productName;
  final String? brandName;

  const _ProductRatingsSheet({
    required this.ean,
    this.productName,
    this.brandName,
  });

  @override
  State<_ProductRatingsSheet> createState() => _ProductRatingsSheetState();
}

class _ProductRatingsSheetState extends State<_ProductRatingsSheet> {
  static const _pageSize = 10;

  ProductRatingSummary? _summary;
  ProductRating? _myRating;
  final List<ProductRating> _ratings = [];
  int _page = 1;
  int _pages = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  bool _isSending = false;

  /// Star value the community list is filtered on (tap on a distribution
  /// bar), null for all ratings.
  int? _ratingFilter;
  bool _isFiltering = false;

  /// Shown above the community list when changing the filter failed (the
  /// previous list and filter are kept).
  String? _listError;

  /// Key of this product's unsent entry in [ReviewDrafts].
  String get _draftKey => 'product:${widget.ean}';

  /// Inline confirmation/error under the user's rating — a SnackBar would
  /// render behind this modal sheet.
  ({String text, Color color})? _feedback;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    // A failed "my rating" fetch must not pass for "not rated yet": the
    // button would then post a duplicate rating instead of editing it.
    var myRatingFailed = false;
    final results = await Future.wait([
      ApiService.getProductRatingSummary(ean: widget.ean),
      ApiService.getProductRatings(
          ean: widget.ean, pageSize: _pageSize, rating: _ratingFilter),
      ApiService.getMyProductRating(ean: widget.ean).catchError((_) {
        myRatingFailed = true;
        return null;
      }),
    ]);
    if (!mounted) return;
    final summary = results[0] as ProductRatingSummary?;
    final page = results[1] as ProductRatingPaginated?;
    setState(() {
      _isLoading = false;
      _hasError = summary == null || page == null || myRatingFailed;
      _listError = null;
      _summary = summary;
      _myRating = results[2] as ProductRating?;
      _ratings
        ..clear()
        ..addAll(page?.items ?? []);
      _page = 1;
      _pages = page?.pages ?? 1;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoading || _page >= _pages) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final filter = _ratingFilter;
    final result = await ApiService.getProductRatings(
        ean: widget.ean, page: nextPage, pageSize: _pageSize, rating: filter);
    if (!mounted || filter != _ratingFilter) return;
    setState(() {
      _isLoadingMore = false;
      if (result != null) {
        _ratings.addAll(result.items);
        _page = nextPage;
        _pages = result.pages;
      }
    });
  }

  /// Filters the community list on [value], or clears the filter when it's
  /// already the selected one. Only the list reloads, not the summary.
  Future<void> _toggleRatingFilter(int value) async {
    final previousFilter = _ratingFilter;
    final filter = _ratingFilter == value ? null : value;
    setState(() {
      _ratingFilter = filter;
      _isFiltering = true;
      _listError = null;
    });
    final page = await ApiService.getProductRatings(
        ean: widget.ean, pageSize: _pageSize, rating: filter);
    // A quicker tap on another bar may have superseded this request.
    if (!mounted || filter != _ratingFilter) return;
    if (page == null) {
      // Keep showing the list that matches the previous filter
      setState(() {
        _ratingFilter = previousFilter;
        _isFiltering = false;
        _listError = 'Impossible de filtrer les avis. '
            'Vérifiez votre connexion et réessayez.';
      });
      return;
    }
    setState(() {
      _isFiltering = false;
      _ratings
        ..clear()
        ..addAll(page.items);
      _page = 1;
      _pages = page.pages;
    });
  }

  static String _starsLabel(int value) =>
      '$value étoile${value > 1 ? 's' : ''}';

  void _login() {
    showAuthBottomSheet(context, onSuccess: () {
      if (mounted) _load();
    });
  }

  Future<void> _openForm() async {
    final existing = _myRating;
    final draft = ReviewDrafts.get(_draftKey);
    final result = await showReviewFormSheet(
      context,
      title: existing == null ? 'Noter ce produit' : 'Modifier ma note',
      subtitle: widget.productName,
      initialRating: draft?.rating ?? existing?.rating,
      initialComment: draft != null ? draft.comment : existing?.comment,
      moderationNotice:
          'Les commentaires sont relus par l\'équipe avant d\'être publiés. '
          'Une note sans commentaire est publiée directement.',
    );
    if (result == null || !mounted) return;

    setState(() {
      _isSending = true;
      _feedback = null;
    });
    final saved = existing == null
        ? await ApiService.postProductRating(
            ean: widget.ean,
            rating: result.rating,
            comment: result.comment,
          )
        : await ApiService.updateProductRating(
            ratingId: existing.id,
            rating: result.rating,
            comment: result.comment,
          );
    if (!mounted) return;

    if (saved == null) {
      ReviewDrafts.save(_draftKey, result);
      setState(() {
        _isSending = false;
        _feedback = (
          text: 'L\'envoi a échoué. Vérifiez votre connexion et réessayez : '
              'votre avis a été gardé.',
          color: kSemanticError,
        );
      });
      return;
    }
    ReviewDrafts.clear(_draftKey);

    await _load();
    if (!mounted) return;
    setState(() {
      _isSending = false;
      _feedback = (
        text: saved.status == ReviewStatus.pending
            ? 'Merci ! Votre commentaire sera visible après validation.'
            : 'Merci pour votre note !',
        color: kSemanticSuccess,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: squircleBorderOnly(topLeft: 72.r, topRight: 72.r),
          ),
          clipBehavior: Clip.antiAlias,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 300) _loadMore();
              return false;
            },
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                36.h,
                AppSpacing.pageHorizontal,
                MediaQuery.of(context).padding.bottom + AppSpacing.section,
              ),
              children: [
                Center(
                  child: Container(
                    width: 70.w,
                    height: 8.h,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  ),
                ),
                SizedBox(height: 48.h),
                _buildHeader(),
                SizedBox(height: AppSpacing.section),
                ..._buildBody(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.productName ?? 'Produit',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.baloo26,
        ),
        if (widget.brandName != null && widget.brandName!.isNotEmpty) ...[
          SizedBox(height: 6.h),
          Text(
            widget.brandName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                AppTextStyles.bodyRegular15.copyWith(color: Colors.grey[500]),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildBody() {
    if (_isLoading) {
      return [
        Padding(
          padding: EdgeInsets.only(top: AppSpacing.section),
          child: const Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_hasError) {
      return [
        const ReviewsEmptyState(
          title: 'Impossible de charger les avis',
          subtitle: 'Vérifiez votre connexion et réessayez.',
        ),
        SizedBox(height: AppSpacing.item),
        Center(
          child: AppButton(
            label: 'Réessayer',
            backgroundColor: kAccentYellow,
            onPressed: _load,
          ),
        ),
      ];
    }

    final summary = _summary!;
    final myId = _myRating?.id;
    final others = _ratings.where((r) => r.id != myId).toList();

    return [
      if (summary.hasRatings) ...[
        RatingSummary(
          average: summary.ratingAvg,
          count: summary.ratingCount,
          distribution: summary.distribution,
          selectedValue: _ratingFilter,
          onValueTap: _toggleRatingFilter,
        ),
        SizedBox(height: AppSpacing.section),
      ],
      Text('Votre note', style: AppTextStyles.baloo22),
      SizedBox(height: AppSpacing.afterTitle),
      _buildMyRating(),
      if (_feedback != null) ...[
        SizedBox(height: 18.h),
        Text(
          _feedback!.text,
          style: AppTextStyles.bodyMedium13.copyWith(color: _feedback!.color),
        ),
      ],
      SizedBox(height: AppSpacing.section),
      if (_listError != null) ...[
        Text(
          _listError!,
          style: AppTextStyles.bodyMedium13.copyWith(color: kSemanticError),
        ),
        SizedBox(height: AppSpacing.item),
      ],
      if (_ratingFilter == null && others.isEmpty)
        // hasRatings with no others means the only rating is the user's own
        summary.hasRatings
            ? const ReviewsEmptyState(
                title: 'Pas d\'autre avis pour le moment',
                subtitle:
                    'Les avis des autres utilisateur·ices apparaîtront ici.',
              )
            : const ReviewsEmptyState(
                title: 'Pas encore de note',
                subtitle: 'Soyez le premier à donner votre avis 🌱',
              )
      else ...[
        Row(
          children: [
            Expanded(
              child:
                  Text('Avis de la communauté', style: AppTextStyles.baloo22),
            ),
            if (_ratingFilter != null)
              TagChip(
                icon: Icons.close,
                label: _starsLabel(_ratingFilter!),
                color: kAccentYellow,
                backgroundColor: kSecondaryTag,
                onTap: () => _toggleRatingFilter(_ratingFilter!),
              ),
          ],
        ),
        SizedBox(height: AppSpacing.afterTitle),
        if (_isFiltering)
          const Center(child: CircularProgressIndicator(strokeWidth: 2))
        else if (others.isEmpty)
          ReviewsEmptyState(
            title: 'Aucun autre avis à ${_starsLabel(_ratingFilter!)}',
            subtitle: 'Touchez une autre note pour changer de filtre.',
          ),
        if (!_isFiltering)
          for (final rating in others) ...[
            ReviewCard(
              nickname: rating.userNickname,
              isPremium: rating.userIsPremium,
              rating: rating.rating,
              comment: rating.comment,
              date: rating.createdAt,
            ),
            SizedBox(height: AppSpacing.item),
          ],
        if (_isLoadingMore)
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ],
    ];
  }

  Widget _buildMyRating() {
    final primary = Theme.of(context).colorScheme.primary;

    if (!AuthService.isLoggedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Connectez-vous pour noter ce produit et partager votre avis.',
            style:
                AppTextStyles.bodyRegular15.copyWith(color: Colors.grey[600]),
          ),
          SizedBox(height: AppSpacing.item),
          AppButton(
            label: 'Se connecter',
            backgroundColor: primary,
            onPressed: _login,
          ),
        ],
      );
    }

    final mine = _myRating;
    if (mine == null) {
      return SizedBox(
        width: double.infinity,
        child: AppButton(
          label: 'Noter ce produit',
          icon: Icons.star_rounded,
          backgroundColor: primary,
          isLoading: _isSending,
          onPressed: _openForm,
        ),
      );
    }

    return ReviewCard(
      nickname: mine.userNickname ?? AuthService.currentUser?.nickname,
      isPremium: mine.userIsPremium,
      rating: mine.rating,
      comment: mine.comment,
      date: mine.createdAt,
      highlighted: true,
      badge: RatingStatusChip(status: mine.status),
      trailing: _isSending
          ? SizedBox(
              width: 48.sp,
              height: 48.sp,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.edit_outlined, size: 54.sp, color: primary),
      onTap: _isSending ? null : _openForm,
    );
  }
}
