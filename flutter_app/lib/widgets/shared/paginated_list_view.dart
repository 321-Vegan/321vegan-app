import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_spacing.dart';
import 'empty_state_view.dart';

/// One page of items and the total number of pages, null on failure.
typedef PageLoader<T> = Future<({List<T> items, int pages})?> Function(
    int page);

/// List loaded page by page as the user scrolls, with pull-to-refresh and
/// the standard empty/error states. [itemBuilder] gets a `reload` callback
/// to refresh the list after an item changed (e.g. edited in a sheet).
/// Keeps its content when it scrolls out of a TabBarView. [header] scrolls
/// with the items, above them (or above the empty state).
class PaginatedListView<T> extends StatefulWidget {
  final PageLoader<T> loadPage;
  final Widget Function(BuildContext context, T item, VoidCallback reload)
      itemBuilder;
  final String emptyTitle;
  final String emptySubtitle;
  final String errorTitle;
  final Widget? header;

  const PaginatedListView({
    super.key,
    required this.loadPage,
    required this.itemBuilder,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.errorTitle,
    this.header,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final List<T> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  int _page = 1;
  int _pages = 1;

  @override
  bool get wantKeepAlive => true;

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
    final result = await widget.loadPage(1);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result == null) {
        _hasError = true;
      } else {
        _hasError = false;
        _items
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
    final result = await widget.loadPage(nextPage);
    if (!mounted) return;
    setState(() {
      _isLoadingMore = false;
      if (result != null) {
        _items.addAll(result.items);
        _page = nextPage;
        _pages = result.pages;
      }
    });
  }

  void _reload() => _loadFirstPage(showLoader: false);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_hasError) {
      return EmptyStateView(
        title: widget.errorTitle,
        subtitle: 'Vérifiez votre connexion et réessayez.',
        buttonLabel: 'Réessayer',
        onButtonTap: _loadFirstPage,
      );
    }
    final header = widget.header;
    if (_items.isEmpty) {
      final empty = EmptyStateView(
        title: widget.emptyTitle,
        subtitle: widget.emptySubtitle,
      );
      if (header == null) return empty;
      return ListView(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal, 24.h, AppSpacing.pageHorizontal, 32.h),
        children: [header, SizedBox(height: 60.h), empty],
      );
    }
    final offset = header == null ? 0 : 1;
    return RefreshIndicator(
      onRefresh: () => _loadFirstPage(showLoader: false),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal, 24.h, AppSpacing.pageHorizontal, 32.h),
        itemCount: offset + _items.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => SizedBox(height: AppSpacing.item),
        itemBuilder: (context, position) {
          if (position < offset) return header!;
          final index = position - offset;
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return widget.itemBuilder(context, _items[index], _reload);
        },
      ),
    );
  }
}
