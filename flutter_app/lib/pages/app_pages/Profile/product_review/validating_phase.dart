import 'dart:convert';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vegan_app/models/e_number.dart';
import 'package:vegan_app/models/validator_product.dart';
import 'package:vegan_app/services/translation_service.dart';
import 'package:vegan_app/services/validator_service.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'constants.dart';
import 'shared_widgets.dart';
import 'brand_widgets.dart';

class ValidatingPhase extends StatefulWidget {
  final ValidatorProduct product;
  final int current;
  final int total;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onQuit;
  final VoidCallback? onBack;

  const ValidatingPhase({
    super.key,
    required this.product,
    required this.current,
    required this.total,
    required this.onComplete,
    required this.onSkip,
    required this.onQuit,
    this.onBack,
  });

  @override
  State<ValidatingPhase> createState() => _ValidatingPhaseState();
}

class _ValidatingPhaseState extends State<ValidatingPhase> {
  // While true, we are verifying the product is still untreated (CREATED)
  // before showing the form. If another contributor already treated it, we
  // skip to the next product without ever rendering it.
  bool _checkingTreated = true;

  OffProductData? _offData;
  bool _loadingOff = true;
  Map<String, ENumberItem> _eNumberLookup = {};

  // Translation
  String? _translatedIngredients;
  bool _translating = false;
  bool _showTranslated = false;

  // Form state
  String _selectedState = 'WAITING_PUBLISH';
  String? _selectedStatus;
  ValidatorBrand? _selectedBrand;
  String? _offBrandQuery;
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _problemCtrl = TextEditingController();
  final Set<String> _activeIngredients = {};
  bool _biodynamic = false;
  bool _hasOldRecipe = false;
  bool _submitting = false;

  bool get _needsProblem =>
      _selectedStatus == 'NON_VEGAN' || _selectedStatus == 'MAYBE_VEGAN';
      
  final String _imageBaseUrl = 'https://321vegan-objects.s3.sbg.io.cloud.ovh.net/';

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.product.status;
    _nameCtrl.text = widget.product.name ?? '';
    _descCtrl.text = widget.product.description ?? '';
    _problemCtrl.text = widget.product.problemDescription ?? '';
    _selectedBrand = widget.product.brand;
    _verifyStillCreated();
  }

  // Re-fetch the product's current state. If another contributor already
  // treated it (state != CREATED) since the session list was loaded, skip it.
  // A null state means the check failed (e.g. network) — proceed rather than
  // block a legitimate validation.
  Future<void> _verifyStillCreated() async {
    final currentState = await ValidatorService.getProductState(widget.product.id);
    if (!mounted) return;
    if (currentState != null && currentState != 'CREATED') {
      widget.onSkip();
      return;
    }
    setState(() => _checkingTreated = false);
    _loadENumbers();
    _fetchOff();
  }

  Future<void> _loadENumbers() async {
    final raw = await rootBundle.loadString('lib/assets/scanner/e_numbers.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final items = ENumberItem.fromJsonList(decoded);
    if (!mounted) return;
    setState(() {
      _eNumberLookup = {for (final item in items) item.eNumber.toUpperCase(): item};
    });
  }

  Future<void> _fetchOff() async {
    final ean = widget.product.ean;
    final data = await ValidatorService.fetchOffData(ean);
    if (!mounted) return;

    ValidatorBrand? matchedBrand;
    String? offBrandQuery;

    if (_selectedBrand == null && data.brandName != null) {
      final results = await ValidatorService.searchBrands(data.brandName!);
      if (mounted) {
        if (results.isNotEmpty) {
          matchedBrand = results.first;
        } else {
          offBrandQuery = data.brandName;
        }
      }
    }

    // Guard against stale responses (user moved to next product or already picked a brand)
    if (mounted && widget.product.ean == ean) {
      setState(() {
        _offData = data;
        _loadingOff = false;
        if (_nameCtrl.text.isEmpty && data.productName != null) {
          _nameCtrl.text = data.productName!;
        }
        if (_selectedBrand == null) {
          if (matchedBrand != null) {
            _selectedBrand = matchedBrand;
          } else if (offBrandQuery != null) {
            _offBrandQuery = offBrandQuery;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _problemCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedStatus == null) {
      _showSnack('Veuillez sélectionner un statut');
      return;
    }
    if (_needsProblem && _problemCtrl.text.trim().isEmpty) {
      _showSnack('Veuillez décrire le problème');
      return;
    }
    if (_selectedStatus != 'NOT_FOUND' && _selectedBrand == null) {
      _showSnack('Veuillez sélectionner une marque');
      return;
    }

    setState(() => _submitting = true);
    final ok = await ValidatorService.validateProduct(
      id: widget.product.id,
      ean: widget.product.ean,
      state: _selectedState,
      status: _selectedStatus!,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      brandId: _selectedBrand?.id,
      problemDescription: _needsProblem ? _problemCtrl.text.trim() : null,
      biodynamic: _biodynamic,
      hasNonVeganOldRecipe: _hasOldRecipe,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      widget.onComplete();
    } else {
      _showSnack('Erreur lors de l\'enregistrement', isError: true);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (ctx) => Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Container(color: Colors.black.withValues(alpha: 0.7)),
            Center(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 40.w),
                padding: EdgeInsets.all(32.w),
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: squircleBorder(radius: 28.r),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 160.w,
                      height: 160.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kSemanticError.withValues(alpha: 0.1),
                        border: Border.all(color: kSemanticError.withValues(alpha: 0.3), width: 3),
                      ),
                      child: Icon(Icons.delete_outline, size: 80.sp, color: kSemanticError),
                    ),
                    SizedBox(height: 28.h),
                    Text(
                      'Supprimer ce produit ?',
                      style: TextStyle(
                        fontSize: 52.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      '${widget.product.name ?? widget.product.ean}\n\nCette action est irréversible.',
                      style: TextStyle(fontSize: 40.sp, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 36.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 18.h),
                              shape: squircleBorder(radius: 16.r),
                            ),
                            child: Text('Annuler',
                                style: TextStyle(fontSize: 42.sp, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kSemanticError,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 18.h),
                              shape: squircleBorder(radius: 16.r),
                              elevation: 0,
                            ),
                            child: Text('Supprimer',
                                style: TextStyle(fontSize: 42.sp, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ) ?? false;

    if (!confirmed || !mounted) return;

    setState(() => _submitting = true);
    final ok = await ValidatorService.deleteProduct(widget.product.id);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      widget.onComplete();
    } else {
      _showSnack('Erreur lors de la suppression', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? kSemanticError : Colors.grey[800],
    ));
  }

  void _showZoomableImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) =>
                      Icon(Icons.image_not_supported, color: Colors.grey[600], size: 60),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingTreated) {
      return const Center(child: CircularProgressIndicator());
    }

    final percent = widget.total > 0 ? (widget.current + 1) / widget.total : 0.0;

    return Column(
      children: [
        _buildProgressBar(percent),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProductInfo(),
                SizedBox(height: 20.h),
                _buildOffInfo(),
                SizedBox(height: 20.h),
                _buildValidationForm(),
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double percent) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Produit ${widget.current + 1} sur ${widget.total}',
                style: TextStyle(fontSize: 38.sp, color: Colors.grey[600]),
              ),
              Row(
                children: [
                  if (widget.onBack != null) ...[
                    _HeaderButton(label: '← Précédent', color: Colors.grey[500]!, onTap: widget.onBack!),
                    SizedBox(width: 12.w),
                  ],
                  _HeaderButton(label: 'Passer', color: Colors.grey[600]!, onTap: widget.onSkip),
                  SizedBox(width: 12.w),
                  _HeaderButton(label: 'Quitter', color: kSemanticError, onTap: widget.onQuit),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8.h,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    final product = widget.product;
    return buildReviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: product.ean));
              _showSnack('EAN copié : ${product.ean}');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.ean,
                  style: TextStyle(
                    fontSize: 36.sp,
                    color: Colors.grey[500],
                    fontFamily: 'monospace',
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(Icons.copy, size: 34.sp, color: Colors.grey[400]),
              ],
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            product.name ?? 'Produit sans nom',
            style: TextStyle(
              fontSize: 50.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          if (product.image != null) ...[
            SizedBox(height: 14.h),
            GestureDetector(
              onTap: () => _showZoomableImage(context, '$_imageBaseUrl${product.image}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipSmoothRect(
                    radius: squircleRadius(10.r),
                    child: CachedNetworkImage(
                      imageUrl: '$_imageBaseUrl${product.image}',
                      width: double.infinity,
                      height: 220.h,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Icon(Icons.image_not_supported, color: Colors.grey[300]),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in, size: 30.sp, color: Colors.grey[400]),
                      SizedBox(width: 4.w),
                      Text(
                        'Appuyez pour voir l\'image fournie',
                        style: TextStyle(fontSize: 32.sp, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
            decoration: ShapeDecoration(
              color: statusColor(product.status).withValues(alpha: 0.12),
              shape: squircleBorder(radius: 20.r),
            ),
            child: Text(
              'Signalé comme : ${statusLabel(product.status)}',
              style: TextStyle(
                fontSize: 36.sp,
                fontWeight: FontWeight.w600,
                color: statusColor(product.status),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse('https://www.google.com/search?q=${product.ean}'),
              mode: LaunchMode.externalApplication,
            ),
            icon: Image.asset(
              'lib/assets/images/icons/search-line.webp',
              width: 40.sp,
              height: 40.sp,
              color: Colors.white,
              colorBlendMode: BlendMode.srcIn,
            ),
            label: Text('Rechercher sur Google', style: TextStyle(fontSize: 38.sp)),
            style: OutlinedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              side: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              shape: squircleBorder(radius: 20.r),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _translateIngredients(String text) async {
    setState(() => _translating = true);
    final translated = await TranslationService.toFrench(text);
    if (!mounted) return;
    setState(() {
      _translatedIngredients = translated;
      _showTranslated = translated != null;
      _translating = false;
    });
  }

  Widget _buildOffInfo() {
    const offBg = Color(0xFFF0F4FF);

    if (_loadingOff) {
      return buildReviewCard(
        backgroundColor: offBg,
        child: Row(
          children: [
            SizedBox(
              width: 20.w,
              height: 20.w,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16.w),
            Text('Chargement OpenFoodFacts...',
                style: TextStyle(fontSize: 38.sp, color: Colors.grey[500])),
          ],
        ),
      );
    }

    final off = _offData;
    if (off == null ||
        (off.productName == null &&
            off.brandName == null &&
            off.ingredients == null &&
            off.imageUrl == null)) {
      return buildReviewCard(
        backgroundColor: offBg,
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 44.sp, color: Colors.grey[400]),
            SizedBox(width: 12.w),
            Text('Introuvable sur OpenFoodFacts',
                style: TextStyle(fontSize: 38.sp, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return buildReviewCard(
      backgroundColor: offBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 44.sp, color: Theme.of(context).colorScheme.primary),
              SizedBox(width: 12.w),
              Text(
                'Informations de OpenFoodFacts',
                style: TextStyle(
                    fontSize: 44.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800]),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (off.imageUrl != null)
            Center(
              child: ClipSmoothRect(
                radius: squircleRadius(10.r),
                child: CachedNetworkImage(
                  imageUrl: off.imageUrl!,
                  height: 200.h,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
          if (off.imageUrl != null) SizedBox(height: 16.h),
          if (off.productName != null) ...[
            _offRow('Nom', off.productName!),
            SizedBox(height: 8.h),
          ],
          if (off.brandName != null) ...[
            _offRow('Marque', off.brandName!),
            SizedBox(height: 8.h),
          ],
          if (off.ingredients != null) ...[
            _buildHighlightedIngredients(off.ingredients!),
            SizedBox(height: 8.h),
          ],
          if (off.additives.isNotEmpty) ...[
            _buildAdditiveChips(off.additives),
          ],
        ],
      ),
    );
  }

  Widget _offRow(String label, String value, {bool multiLine = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 36.sp, fontWeight: FontWeight.w600, color: Colors.black)),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(fontSize: 38.sp, color: Colors.grey[800]),
          maxLines: multiLine ? 6 : 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildHighlightedIngredients(String text) {
    const red = Color(0xFFC62828);
    const orange = Color(0xFFF57C00);

    final displayText = _showTranslated && _translatedIngredients != null
        ? _translatedIngredients!
        : text;

    // Build (keyword, color) pairs sorted longest-first so "arômes naturels"
    // matches before "arômes" in the combined regex.
    final patterns = [
      for (final k in nonVeganIngredientKeywords) (k, red),
      for (final k in maybeVeganIngredientKeywords) (k, orange),
    ]..sort((a, b) => b.$1.length.compareTo(a.$1.length));

    final regexStr = patterns.map((p) => RegExp.escape(p.$1)).join('|');
    final regex = RegExp(regexStr, caseSensitive: false);

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in regex.allMatches(displayText)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: displayText.substring(lastEnd, match.start),
          style: TextStyle(fontSize: 38.sp, color: Colors.grey[800]),
        ));
      }
      final matched = match.group(0)!;
      final matchedLower = matched.toLowerCase();
      Color matchColor = orange;
      for (final p in patterns) {
        if (p.$1.toLowerCase() == matchedLower) {
          matchColor = p.$2;
          break;
        }
      }
      spans.add(TextSpan(
        text: matched,
        style: TextStyle(
          fontSize: 38.sp,
          fontWeight: FontWeight.bold,
          color: matchColor,
          backgroundColor: matchColor.withValues(alpha: 0.12),
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < displayText.length) {
      spans.add(TextSpan(
        text: displayText.substring(lastEnd),
        style: TextStyle(fontSize: 38.sp, color: Colors.grey[800]),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Ingrédients',
                style: TextStyle(
                    fontSize: 36.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black)),
            const Spacer(),
            if (_translating)
              SizedBox(
                width: 18.w,
                height: 18.w,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_translatedIngredients != null)
              GestureDetector(
                onTap: () => setState(() => _showTranslated = !_showTranslated),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: ShapeDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    shape: squircleBorder(
                      radius: 20.r,
                      side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3)),
                    ),
                  ),
                  child: Text(
                    _showTranslated ? 'Afficher l\'original' : 'Afficher la traduction',
                    style: TextStyle(
                        fontSize: 36.sp,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () => _translateIngredients(text),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: ShapeDecoration(
                    color: Colors.grey[100],
                    shape: squircleBorder(
                      radius: 20.r,
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.translate,
                          size: 28.sp, color: Colors.grey[600]),
                      SizedBox(width: 4.w),
                      Text('Traduire',
                          style: TextStyle(
                              fontSize: 36.sp, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 4.h),
        RichText(
          maxLines: 10,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(children: spans),
        ),
      ],
    );
  }

  Color _additiveColor(String eNumber) {
    final item = _eNumberLookup[eNumber];
    if (item == null) return Colors.grey[600]!;
    switch (item.state) {
      case 'carniste':
        return kSemanticError;
      case 'Ça dépend':
        return const Color(0xFFF57C00);
      case 'vegan':
        return kSemanticSuccess;
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildAdditiveChips(List<String> additives) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Additifs',
            style: TextStyle(
                fontSize: 36.sp, fontWeight: FontWeight.w600, color: Colors.black)),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 6.w,
          runSpacing: 6.h,
          children: additives.map((e) {
            final upper = e.toUpperCase();
            final color = _additiveColor(upper);
            return GestureDetector(
              onTap: () => _showAdditiveDialog(upper),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: ShapeDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: squircleBorder(
                    radius: 8.r,
                    side: BorderSide(color: color.withValues(alpha: 0.4)),
                  ),
                ),
                child: Text(upper,
                    style: TextStyle(
                        fontSize: 32.sp, fontWeight: FontWeight.bold, color: color)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showAdditiveDialog(String eNumber) {
    final item = _eNumberLookup[eNumber];
    final stateColor = _additiveColor(eNumber);
    final stateLabel = item == null
        ? 'Inconnu'
        : switch (item.state) {
            'vegan' => 'Végane',
            'carniste' => 'Non végane',
            'Ça dépend' => 'Selon l\'origine',
            _ => item.state,
          };

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: squircleBorder(radius: 16.r),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(eNumber,
                      style: TextStyle(
                          fontSize: 52.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800])),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                    decoration: ShapeDecoration(
                      color: stateColor.withValues(alpha: 0.1),
                      shape: squircleBorder(
                        radius: 20.r,
                        side: BorderSide(color: stateColor.withValues(alpha: 0.4)),
                      ),
                    ),
                    child: Text(stateLabel,
                        style: TextStyle(
                            fontSize: 30.sp,
                            fontWeight: FontWeight.w600,
                            color: stateColor)),
                  ),
                ],
              ),
              if (item != null) ...[
                SizedBox(height: 10.h),
                Text(item.name,
                    style: TextStyle(
                        fontSize: 38.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800])),
                if (item.alternativeNames.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(item.alternativeNames.join(', '),
                      style: TextStyle(fontSize: 30.sp, color: Colors.grey[500])),
                ],
                if (item.description.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Text(item.description,
                      style: TextStyle(fontSize: 32.sp, color: Colors.grey[700])),
                ],
              ] else ...[
                SizedBox(height: 8.h),
                Text('Aucune information disponible.',
                    style: TextStyle(fontSize: 32.sp, color: Colors.grey[500])),
              ],
              SizedBox(height: 20.h),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Fermer',
                      style: TextStyle(fontSize: 36.sp)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidationForm() {
    final primary = Theme.of(context).colorScheme.primary;
    return buildReviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                decoration: ShapeDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: squircleBorder(radius: 14.r),
                ),
                child: Icon(Icons.task_alt_outlined, size: 44.sp, color: primary),
              ),
              SizedBox(width: 14.w),
              Text('Validation',
                  style: TextStyle(
                      fontSize: 48.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800])),
            ],
          ),

          Divider(color: Colors.grey[200], height: 40.h),

          // ── State ──
          _formLabel('État', required: true),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: productStates.map((s) {
              final selected = _selectedState == s.value;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedState = s.value;
                  if (s.value == 'NEED_CONTACT') {
                    _selectedStatus = 'MAYBE_VEGAN';
                  }
                }),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
                  decoration: ShapeDecoration(
                    color: selected ? s.color.withValues(alpha: 0.12) : Colors.grey[100],
                    shape: squircleBorder(
                      radius: 24.r,
                      side: BorderSide(
                        color: selected ? s.color : Colors.grey[300]!,
                        width: selected ? 2 : 1,
                      ),
                    ),
                  ),
                  child: Text(s.label,
                      style: TextStyle(
                        fontSize: 38.sp,
                        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                        color: selected ? s.color : Colors.grey[600],
                      )),
                ),
              );
            }).toList(),
          ),

          Divider(color: Colors.grey[100], height: 40.h),

          // ── Status ──
          _formLabel('Statut', required: true),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: productReviewStatuses.map((s) {
              final locked = _selectedState == 'NEED_CONTACT';
              final selectable = !locked || s.value == 'MAYBE_VEGAN';
              final selected = _selectedStatus == s.value;
              return GestureDetector(
                onTap: selectable ? () => setState(() => _selectedStatus = s.value) : null,
                child: Opacity(
                  opacity: selectable ? 1.0 : 0.35,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
                    decoration: ShapeDecoration(
                      color: selected ? s.color.withValues(alpha: 0.12) : Colors.grey[100],
                      shape: squircleBorder(
                        radius: 24.r,
                        side: BorderSide(
                          color: selected ? s.color : Colors.grey[300]!,
                          width: selected ? 2 : 1,
                        ),
                      ),
                    ),
                    child: Text(s.label,
                        style: TextStyle(
                          fontSize: 38.sp,
                          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                          color: selected ? s.color : Colors.grey[600],
                        )),
                  ),
                ),
              );
            }).toList(),
          ),

          Divider(color: Colors.grey[100], height: 40.h),

          // ── Brand ──
          _formLabel('Marque', required: _selectedStatus != 'NOT_FOUND'),
          SizedBox(height: 12.h),
          BrandSelect(
            key: ValueKey('${_selectedBrand?.id ?? ""}|${_offBrandQuery ?? ""}'),
            initialBrand: _selectedBrand,
            initialQuery: _offBrandQuery,
            onSelected: (brand) => setState(() => _selectedBrand = brand),
          ),
          SizedBox(height: 8.h),
          Text('Si introuvable, utilisez la marque « Inconnue ».',
              style: TextStyle(fontSize: 32.sp, color: Colors.grey[500])),
          if (_selectedBrand?.background != null &&
              _selectedBrand!.background!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: ShapeDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.07),
                shape: squircleBorder(
                  radius: 12.r,
                  side: BorderSide(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 38.sp, color: const Color(0xFF1565C0)),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Réponse générale de ${_selectedBrand!.name}',
                          style: TextStyle(
                              fontSize: 34.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1565C0)),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _selectedBrand!.background!,
                          style: TextStyle(
                              fontSize: 34.sp, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          Divider(color: Colors.grey[100], height: 40.h),

          // ── Name --
          _formLabel('Nom du produit', required:true),
          SizedBox(height: 12.h),
          TextField(
            controller: _nameCtrl,
            decoration: _inputDecoration('Nom du produit'),
            style: TextStyle(fontSize: 38.sp),
          ),

          Divider(color: Colors.grey[100], height: 40.h),

          // ── Description ──
          _formLabel('Description'),
          SizedBox(height: 12.h),
          TextField(
            controller: _descCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: _inputDecoration(
                'Description du produit (note interne qui ne sera pas affichée). Pas besoin de la remplir la plupart du temps'),
            style: TextStyle(fontSize: 38.sp),
          ),

          // ── Problème (conditionnel) ──
          if (_needsProblem) ...[
            Divider(color: Colors.grey[100], height: 40.h),
            if (_selectedStatus == 'NON_VEGAN')
              _formLabel('Pourquoi pas vegan ?', required: true),
            if (_selectedStatus == 'MAYBE_VEGAN')
              _formLabel('Pourquoi à contacter ?', required: true),
            SizedBox(height: 12.h),
            TextField(
              controller: _problemCtrl,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration(
                  'Raison pour laquelle le produit n\'est pas végane (ou à contacter)'),
              style: TextStyle(fontSize: 38.sp),
            ),
            SizedBox(height: 12.h),
            _buildIngredientChips(),
          ],

          Divider(color: Colors.grey[100], height: 40.h),

          // ── Autres informations ──
          _formLabel('Autres informations'),
          SizedBox(height: 4.h),
          SwitchListTile(
            value: _biodynamic,
            onChanged: (v) => setState(() => _biodynamic = v),
            title: Text('Biodynamique (label Demeter)',
                style: TextStyle(fontSize: 40.sp, color: Colors.grey[800])),
            activeThumbColor: Theme.of(context).colorScheme.primary,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          SwitchListTile(
            value: _hasOldRecipe,
            onChanged: (v) => setState(() => _hasOldRecipe = v),
            title: Text('Ancienne recette non végane',
                style: TextStyle(fontSize: 40.sp, color: Colors.grey[800])),
            activeThumbColor: Theme.of(context).colorScheme.primary,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),

          SizedBox(height: 28.h),

          // ── Submit ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? SizedBox(
                      height: 24.h,
                      width: 24.h,
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(Icons.save_outlined, size: 56.sp),
              label: Text('Enregistrer',
                  style: TextStyle(fontSize: 44.sp, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 18.h),
                shape: squircleBorder(radius: 14.r),
              ),
            ),
          ),

          SizedBox(height: 12.h),

          // ── Delete ──
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _submitting ? null : _delete,
              icon: Icon(Icons.delete_outline, size: 52.sp),
              label: Text('Supprimer le produit',
                  style: TextStyle(fontSize: 40.sp, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: kSemanticError,
                side: BorderSide(color: kSemanticError.withValues(alpha: 0.5)),
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: squircleBorder(radius: 14.r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formLabel(String text, {bool required = false}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4.w,
          height: 28.h,
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 10.w),
        Text(text,
            style: TextStyle(
                fontSize: 40.sp,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800])),
        if (required) ...[
          SizedBox(width: 4.w),
          Text('*',
              style: TextStyle(
                  fontSize: 40.sp,
                  color: kSemanticError,
                  fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 36.sp, color: Colors.grey[400]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  Widget _buildIngredientChips() {
    final chips = _selectedState == 'NEED_CONTACT'
        ? maybeVeganSelectableIngredients
        : nonVeganIngredients;
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: chips.map((ingredient) {
        final active = _activeIngredients.contains(ingredient);
        return GestureDetector(
          onTap: () => _toggleIngredient(ingredient),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: ShapeDecoration(
              color: active
                  ? const Color(0xFFC62828)
                  : const Color(0xFFC62828).withValues(alpha: 0.12),
              shape: squircleBorder(
                radius: 20.r,
                side: BorderSide(
                  color: const Color(0xFFC62828).withValues(alpha: active ? 1.0 : 0.4),
                  width: 1.5,
                ),
              ),
            ),
            child: Text(
              ingredient.toUpperCase(),
              style: TextStyle(
                fontSize: 32.sp,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : const Color(0xFFC62828),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _toggleIngredient(String ingredient) {
    final current = _problemCtrl.text;
    if (_activeIngredients.contains(ingredient)) {
      _activeIngredients.remove(ingredient);
      final parts = current
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.toLowerCase() != ingredient.toLowerCase())
          .toList();
      _problemCtrl.text = parts.join(', ');
    } else {
      _activeIngredients.add(ingredient);
      final capitalized = ingredient[0].toUpperCase() + ingredient.substring(1);
      if (current.trim().isEmpty) {
        _problemCtrl.text = capitalized;
      } else {
        _problemCtrl.text = '${current.trimRight()}, $capitalized';
      }
    }
    setState(() {});
  }
}

class _HeaderButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _HeaderButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
        decoration: ShapeDecoration(
          color: color.withValues(alpha: 0.1),
          shape: squircleBorder(
            radius: 20.r,
            side: BorderSide(color: color.withValues(alpha: 0.4)),
          ),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 36.sp, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }
}
