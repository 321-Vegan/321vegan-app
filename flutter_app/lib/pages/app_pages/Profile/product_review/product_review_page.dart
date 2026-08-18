import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/models/validator_product.dart';
import 'package:vegan_app/services/validator_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_spacing.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'constants.dart';
import 'shared_widgets.dart';
import 'validating_phase.dart';

class ProductReviewPage extends StatefulWidget {
  const ProductReviewPage({super.key});

  @override
  State<ProductReviewPage> createState() => _ProductReviewPageState();
}

class _ProductReviewPageState extends State<ProductReviewPage> {
  // Phases: setup | validating | completed
  String _phase = 'setup';

  List<ValidatorProduct> _allProducts = [];
  List<ValidatorProduct> _sessionProducts = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await ValidatorService.getCreatedProducts();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _allProducts = result.items;
      });
    }
  }

  void _onStart(List<String> selectedStatuses) {
    final filtered = selectedStatuses.isEmpty
        ? List<ValidatorProduct>.from(_allProducts)
        : _allProducts.where((p) => selectedStatuses.contains(p.status)).toList();

    // Shuffle to reduce collision when multiple contributors are active
    final shuffled = List<ValidatorProduct>.from(filtered);
    final rng = Random();
    for (var i = shuffled.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = tmp;
    }

    setState(() {
      _sessionProducts = shuffled;
      _currentIndex = 0;
      _phase = 'validating';
    });
  }

  void _advance() {
    final next = _currentIndex + 1;
    if (next >= _sessionProducts.length) {
      setState(() => _phase = 'completed');
    } else {
      setState(() => _currentIndex = next);
    }
  }

  void _skip() => _advance();

  void _goBack() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  void _quit() {
    setState(() {
      _phase = 'setup';
      _sessionProducts = [];
      _currentIndex = 0;
    });
  }

  void _restart() {
    _quit();
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Validation des produits',
          style: AppTextStyles.baloo22,
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _buildPhase(),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case 'setup':
        return _SetupPhase(
          products: _allProducts,
          onStart: _onStart,
          onRefresh: _loadProducts,
        );
      case 'validating':
        if (_sessionProducts.isEmpty || _currentIndex >= _sessionProducts.length) {
          return _CompletedPhase(onRestart: _restart);
        }
        return ValidatingPhase(
          key: ValueKey(_sessionProducts[_currentIndex].id),
          product: _sessionProducts[_currentIndex],
          current: _currentIndex,
          total: _sessionProducts.length,
          onComplete: _advance,
          onSkip: _skip,
          onQuit: _quit,
          onBack: _currentIndex > 0 ? _goBack : null,
        );
      case 'completed':
        return _CompletedPhase(onRestart: _restart);
      default:
        return const SizedBox();
    }
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 100.sp, color: kSemanticError),
          SizedBox(height: 16.h),
          Text('Erreur de chargement',
              style: TextStyle(fontSize: 48.sp, fontWeight: FontWeight.bold)),
          SizedBox(height: 24.h),
          ElevatedButton(onPressed: _loadProducts, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

// ─── Setup phase ──────────────────────────────────────────────────────────────

class _SetupPhase extends StatefulWidget {
  final List<ValidatorProduct> products;
  final void Function(List<String>) onStart;
  final Future<void> Function() onRefresh;

  const _SetupPhase({
    required this.products,
    required this.onStart,
    required this.onRefresh,
  });

  @override
  State<_SetupPhase> createState() => _SetupPhaseState();
}

class _SetupPhaseState extends State<_SetupPhase> {
  final Set<String> _selected = {};

  int _countFor(String status) =>
      widget.products.where((p) => p.status == status).length;

  int get _filteredCount {
    if (_selected.isEmpty) return widget.products.length;
    return widget.products.where((p) => _selected.contains(p.status)).length;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal, vertical: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildReviewCard(
            child: Row(
              children: [
                Container(
                  width: 120.w,
                  height: 120.w,
                  decoration: ShapeDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    shape: squircleBorder(radius: 16.r),
                  ),
                  child: Icon(Icons.edit_note_outlined,
                      size: 120.sp, color: Theme.of(context).colorScheme.primary),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vérification des produits',
                        style: TextStyle(
                          fontSize: 46.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${widget.products.length} produit${widget.products.length != 1 ? "s" : ""} en attente',
                        style: TextStyle(
                          fontSize: 36.sp,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),

          buildReviewCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filtrer par statut',
                    style: TextStyle(
                        fontSize: 42.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800])),
                SizedBox(height: 6.h),
                Text(
                  'Sélectionnez les statuts des produits que vous souhaitez vérifier. Les produits seront présentés un par un.',
                  style: TextStyle(fontSize: 34.sp, color: Colors.grey[600]),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Si aucun statut n\'est sélectionné, tous les produits seront inclus dans la validation.',
                  style: TextStyle(fontSize: 34.sp, color: Colors.grey[500]),
                ),
                SizedBox(height: 16.h),
                ...productReviewStatuses.where((s) => s.value != 'NOT_FOUND').map((s) {
                  final count = _countFor(s.value);
                  final checked = _selected.contains(s.value);
                  return Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: Material(
                      color: Colors.transparent,
                      shape: squircleBorder(radius: 14.r),
                      child: InkWell(
                        customBorder: squircleBorder(radius: 14.r),
                        onTap: count == 0
                            ? null
                            : () => setState(() {
                                  if (checked) {
                                    _selected.remove(s.value);
                                  } else {
                                    _selected.add(s.value);
                                  }
                                }),
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                          decoration: ShapeDecoration(
                            color: checked ? s.color.withValues(alpha: 0.08) : Colors.grey[50],
                            shape: squircleBorder(
                              radius: 14.r,
                              side: BorderSide(
                                color: checked ? s.color : Colors.grey[200]!,
                                width: checked ? 2 : 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 5.w,
                                height: 38.h,
                                decoration: BoxDecoration(
                                  color: count == 0 ? Colors.grey[300] : s.color,
                                  borderRadius: BorderRadius.circular(3.r),
                                ),
                              ),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: Text(s.label,
                                    style: TextStyle(
                                      fontSize: 40.sp,
                                      fontWeight: checked
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: count == 0
                                          ? Colors.grey[400]
                                          : (checked ? s.color : Colors.grey[700]),
                                    )),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12.w, vertical: 4.h),
                                decoration: ShapeDecoration(
                                  color: count > 0
                                      ? s.color.withValues(alpha: 0.12)
                                      : Colors.grey[100],
                                  shape: squircleBorder(radius: 12.r),
                                ),
                                child: Text('$count',
                                    style: TextStyle(
                                      fontSize: 36.sp,
                                      fontWeight: FontWeight.bold,
                                      color: count > 0 ? s.color : Colors.grey[400],
                                    )),
                              ),
                              SizedBox(width: 10.w),
                              Icon(
                                checked
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 44.sp,
                                color: checked ? s.color : Colors.grey[300],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                Divider(color: Colors.grey[100], height: 1),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 56.sp,
                        color: Theme.of(context).colorScheme.primary),
                    SizedBox(width: 8.w),
                    Text(
                      '$_filteredCount produit${_filteredCount != 1 ? "s" : ""} sélectionné${_filteredCount != 1 ? "s" : ""}',
                      style: TextStyle(
                        fontSize: 38.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          Center(
            child: Text(
              'Merci pour votre contribution ! 💚',
              style: TextStyle(
                  fontSize: 38.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 16.h),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _filteredCount == 0 ? null : () => widget.onStart(_selected.toList()),
              icon: Icon(Icons.play_arrow_rounded, size: 52.sp),
              label: Text('Commencer la vérification',
                  style: TextStyle(fontSize: 44.sp, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 20.h),
                shape: squircleBorder(radius: 14.r),
              ),
            ),
          ),
          SizedBox(height: 80.h),
        ],
      ),
    );
  }
}

// ─── Completed phase ──────────────────────────────────────────────────────────

class _CompletedPhase extends StatelessWidget {
  final VoidCallback onRestart;
  const _CompletedPhase({required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('💚', style: TextStyle(fontSize: 120.sp)),
            SizedBox(height: 24.h),
            Text(
              'Validation terminée',
              style: TextStyle(
                  fontSize: 56.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            Text(
              'La session est terminée. Merci infiniment pour votre contribution !',
              style: TextStyle(fontSize: 42.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40.h),
            ElevatedButton(
              onPressed: onRestart,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 16.h),
                shape: squircleBorder(radius: 14.r),
              ),
              child: Text('Retour',
                  style: TextStyle(fontSize: 44.sp, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
