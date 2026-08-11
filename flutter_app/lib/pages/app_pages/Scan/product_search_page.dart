import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, FilteringTextInputFormatter;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/barcode_helper.dart';
import 'package:vegan_app/helpers/database_helper.dart';
import 'package:vegan_app/helpers/helper.dart';
import 'package:vegan_app/models/e_number.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/themes/app_text_styles.dart';
import 'package:vegan_app/widgets/shared/app_background.dart';
import 'package:vegan_app/widgets/shared/app_card.dart';
import 'package:vegan_app/widgets/shared/empty_state_view.dart';

enum _SearchCategory { aliment, cosmetique, additif }

/// Unified product search page (Figma redesign): one search field, category
/// chips, results below — Additifs, Cosmétiques, and Code-barre (which used
/// to be three separate bottom sheets/dialogs from the Scan page). Picking a
/// barcode result (or typing a valid one) pops this page with the code so
/// the Scan page can run it through the same pipeline as a camera scan.
class ProductSearchPage extends StatefulWidget {
  const ProductSearchPage({super.key});

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  _SearchCategory _category = _SearchCategory.cosmetique;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<ENumberItem> _eNumbers = [];
  List<CosmeticItem> _cosmeticResults = [];
  List<Map<String, dynamic>> _barcodeResults = [];
  String? _barcodeError;

  @override
  void initState() {
    super.initState();
    _loadENumbers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadENumbers() async {
    final jsonData =
        await rootBundle.loadString('lib/assets/scanner/e_numbers.json');
    final jsonItems = jsonDecode(jsonData)['items'] as List;
    if (!mounted) return;
    setState(() {
      _eNumbers = jsonItems
          .map((item) => ENumberItem.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _query = value;
      _barcodeError = null;
    });
    if (_category == _SearchCategory.cosmetique) {
      _searchCosmetics(value);
    } else if (_category == _SearchCategory.aliment) {
      _searchBarcodes(value);
    }
  }

  void _clear() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _selectCategory(_SearchCategory category) {
    if (category == _category) return;
    setState(() {
      _category = category;
      _barcodeError = null;
    });
    if (category == _SearchCategory.cosmetique && _query.isNotEmpty) {
      _searchCosmetics(_query);
    } else if (category == _SearchCategory.aliment && _query.isNotEmpty) {
      _searchBarcodes(_query);
    }
  }

  Future<void> _searchBarcodes(String query) async {
    final prefix = query.trim();
    if (prefix.length < 3) {
      setState(() => _barcodeResults = []);
      return;
    }
    final results = await DatabaseHelper.instance
        .queryProductsByCodePrefix(prefix, limit: 20);
    if (!mounted) return;
    setState(() => _barcodeResults = results);
  }

  /// Called on submit (Enter/Done) — lets the user proceed with a typed
  /// code even if it has no local suggestion (the real lookup happens back
  /// on the Scan page, same as a camera scan of an unknown product).
  void _submitBarcode(String raw) {
    if (_category != _SearchCategory.aliment) return;
    if (!BarcodeHelper.isValid(raw)) {
      setState(() => _barcodeError = 'Code-barres invalide (EAN-8 ou EAN-13)');
      return;
    }
    Navigator.of(context).pop(raw.trim());
  }

  void _selectBarcodeResult(String code) {
    Navigator.of(context).pop(code);
  }

  Future<void> _searchCosmetics(String query) async {
    if (query.isEmpty) {
      setState(() => _cosmeticResults = []);
      return;
    }
    final dbResult = await DatabaseHelper.instance.queryCosmeticByName(query);
    if (!mounted) return;
    setState(() {
      _cosmeticResults = dbResult
          .map((item) => CosmeticItem(
                name: item['brand'] as String,
                vegan: (item['vegan'] as String).toUpperCase() == 'Y',
                crueltyFree: (item['cf'] as String).toUpperCase() == 'Y',
              ))
          .toList();
    });
  }

  List<ENumberItem> get _filteredENumbers {
    if (_query.isEmpty) return [];
    final normalizedQuery = _query.toLowerCase();
    final isENumberSearch =
        RegExp(r'^(e?\d+[a-zA-Z]*)$', caseSensitive: false)
            .hasMatch(normalizedQuery);
    return isENumberSearch
        ? _filterByENumber(normalizedQuery)
        : _filterByName(normalizedQuery);
  }

  List<ENumberItem> _filterByENumber(String query) {
    final exactMatches =
        _eNumbers.where((e) => e.eNumber.toLowerCase() == query).toList();
    final partialMatches = _eNumbers
        .where((e) =>
            e.eNumber.toLowerCase().contains(query) &&
            e.eNumber.toLowerCase() != query)
        .toList();
    return [...exactMatches, ...partialMatches];
  }

  List<ENumberItem> _filterByName(String query) => _eNumbers
      .where((e) => e.name.toLowerCase().contains(query))
      .toList();

  String get _searchHint => switch (_category) {
        _SearchCategory.additif => "Rechercher un additif (ex. e200, carmin…)",
        _SearchCategory.cosmetique => "Rechercher une marque (ex. Avril, Nae…)",
        _SearchCategory.aliment => "Code-barre (ex. 3770016570121)",
      };

  String get _emptyPromptSubtitle => switch (_category) {
        _SearchCategory.aliment => 'Tapez un code-barres pour le rechercher.',
        _ => 'Tapez un nom pour lancer la recherche.',
      };

  @override
  Widget build(BuildContext context) {
    final List<Object> results = switch (_category) {
      _SearchCategory.additif => _filteredENumbers,
      _SearchCategory.cosmetique => _cosmeticResults,
      _SearchCategory.aliment => _barcodeResults,
    };
    final hasQuery = _query.isNotEmpty;
    final isAliment = _category == _SearchCategory.aliment;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Rechercher un produit',
            style: TextStyle(fontFamily: 'Baloo2', fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kTextPrimary,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 48.w),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onSubmitted: isAliment ? _submitBarcode : null,
                  keyboardType:
                      isAliment ? TextInputType.number : TextInputType.text,
                  inputFormatters: isAliment
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : null,
                  style: TextStyle(fontSize: 42.sp),
                  decoration: InputDecoration(
                    hintText: _searchHint,
                    hintStyle:
                        TextStyle(fontSize: 42.sp, color: Colors.grey[500]),
                    errorText: isAliment ? _barcodeError : null,
                    prefixIcon: Icon(
                      Icons.search,
                      size: 60.sp,
                      color: Colors.grey[600],
                    ),
                    suffixIcon: hasQuery
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 36.sp),
                            onPressed: _clear,
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w, vertical: 30.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(42.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30.h),
              SizedBox(
                height: 144.w,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 48.w),
                  children: [
                    _buildCategoryChip(
                      label: 'Code-barre',
                      icon: CupertinoIcons.barcode_viewfinder,
                      isSelected: _category == _SearchCategory.aliment,
                      enabled: true,
                      onTap: () => _selectCategory(_SearchCategory.aliment),
                    ),
                    SizedBox(width: 24.w),
                    _buildCategoryChip(
                      label: 'Cosmétique',
                      icon: Icons.soap_rounded,
                      isSelected: _category == _SearchCategory.cosmetique,
                      enabled: true,
                      onTap: () => _selectCategory(_SearchCategory.cosmetique),
                    ),
                    SizedBox(width: 24.w),
                    _buildCategoryChip(
                      label: 'Additif',
                      icon: Icons.science,
                      isSelected: _category == _SearchCategory.additif,
                      enabled: true,
                      onTap: () => _selectCategory(_SearchCategory.additif),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30.h),
              Expanded(
                child: !hasQuery
                    ? EmptyStateView(
                        title: 'Recherchez un produit',
                        subtitle: _emptyPromptSubtitle,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 48.w),
                            child: Text(
                              'Résultats (${results.length})',
                              style: AppTextStyles.resultsCount,
                            ),
                          ),
                          SizedBox(height: 20.h),
                          Expanded(
                            child: results.isEmpty
                                ? (isAliment && BarcodeHelper.isValid(_query))
                                    ? EmptyStateView(
                                        title: 'Code non trouvé localement',
                                        subtitle:
                                            'Vous pouvez tout de même valider ce code.',
                                        buttonLabel: 'Utiliser ce code',
                                        onButtonTap: () =>
                                            _submitBarcode(_query),
                                      )
                                    : const EmptyStateView(
                                        title: 'Aucun résultat',
                                        subtitle:
                                            'Essayez avec un autre nom ou une autre marque.',
                                      )
                                : ListView.separated(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 48.w, vertical: 8.h),
                                    itemCount: results.length,
                                    separatorBuilder: (_, __) =>
                                        SizedBox(height: 20.h),
                                    itemBuilder: (context, index) {
                                      final item = results[index];
                                      if (item is CosmeticItem) {
                                        return _buildCosmeticCard(item);
                                      }
                                      if (item is Map<String, dynamic>) {
                                        return _buildBarcodeCard(item);
                                      }
                                      return _buildAdditiveCard(
                                          item as ENumberItem);
                                    },
                                  ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          // Figma: fixed 47px height, 12px radius, 11/13 padding, 7px gap —
          // ×3 for ScreenUtil units. Same height as the search bar/action
          // buttons above so every row on this page reads consistently.
          height: 144.w,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 39.w),
          decoration: ShapeDecoration(
            color: isSelected ? kPrimaryTag : Colors.white,
            shape: squircleBorder(
              radius: 36.r,
              side: BorderSide(
                color: isSelected ? primaryColor : kBorderDefault,
                width: isSelected ? 1.5 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 60.sp, color: isSelected ? primaryColor : kTextPrimary),
              SizedBox(width: 21.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 38.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? primaryColor : kTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarcodeCard(Map<String, dynamic> product) {
    final code = product['code']?.toString() ?? '';
    final name = ((product['name'] as String?) ?? 'Produit inconnu')
        .replaceAll('&quot;', "'");
    final brand =
        ((product['brand'] as String?) ?? '').replaceAll('&quot;', "'");
    final statusColor = switch (product['status']) {
      'R' => Colors.red,
      'M' => Colors.orange,
      'N' => Colors.grey,
      _ => Theme.of(context).colorScheme.primary,
    };
    return GestureDetector(
      onTap: () => _selectBarcodeResult(code),
      child: AppCard(
        padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 28.h),
        child: Row(
          children: [
            Container(
              width: 20.w,
              height: 20.w,
              decoration:
                  BoxDecoration(color: statusColor, shape: BoxShape.circle),
            ),
            SizedBox(width: 20.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brand.isNotEmpty ? '$name - $brand' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 42.sp,
                      fontWeight: FontWeight.bold,
                      color: kTextPrimary,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    code,
                    style: TextStyle(
                      fontSize: 34.sp,
                      color: Colors.grey[600],
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 48.sp, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildCosmeticCard(CosmeticItem cosmetic) {
    return AppCard(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 28.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cosmetic.name,
            style: TextStyle(
              fontSize: 42.sp,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          SizedBox(height: 16.h),
          if (!cosmetic.vegan && cosmetic.crueltyFree) ...[
            _buildAlertBanner(
                "Cette marque n'est pas 100% végane. Vérifiez l'emballage !"),
            SizedBox(height: 12.h),
          ],
          if (cosmetic.crueltyFree) ...[
            _buildStatusRow(
              icon: cosmetic.vegan ? Icons.check_circle : Icons.info,
              color: cosmetic.vegan ? Colors.green : Colors.orange,
              text: cosmetic.vegan ? '100% Vegan' : 'Vérifiez le produit',
            ),
            SizedBox(height: 8.h),
          ],
          _buildStatusRow(
            icon: cosmetic.crueltyFree ? Icons.check_circle : Icons.close,
            color: cosmetic.crueltyFree ? Colors.green : Colors.red,
            text: cosmetic.crueltyFree ? 'Cruelty-Free 🐰' : 'Pas cruelty-free',
          ),
        ],
      ),
    );
  }

  Widget _buildAdditiveCard(ENumberItem item) {
    final color = _stateColor(item.state);
    return AppCard(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 28.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.name} (${item.eNumber})',
            style: TextStyle(
              fontSize: 42.sp,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          SizedBox(height: 16.h),
          _buildStatusRow(
            icon: _stateIcon(item.state),
            color: color,
            text: item.state.toCapitalized(),
          ),
          if (item.description.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Text(
              item.description,
              style: TextStyle(fontSize: 34.sp, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertBanner(String text) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: ShapeDecoration(
        color: Colors.orange[100],
        shape: squircleBorder(radius: 16.r),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 44.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.orange[800], fontSize: 34.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 44.sp),
        SizedBox(width: 12.w),
        Text(
          text,
          style: TextStyle(
              fontWeight: FontWeight.bold, color: color, fontSize: 36.sp),
        ),
      ],
    );
  }

  Color _stateColor(String state) => switch (state) {
        'vegan' => Colors.green,
        'carniste' => Colors.red,
        'Ça dépend' => Colors.orange,
        _ => Colors.grey,
      };

  IconData _stateIcon(String state) => switch (state) {
        'vegan' => Icons.check_circle,
        'carniste' => Icons.close,
        'Ça dépend' => Icons.help_outline,
        _ => Icons.info_outline,
      };
}

class CosmeticItem {
  final String name;
  final bool vegan;
  final bool crueltyFree;

  CosmeticItem({
    required this.name,
    required this.vegan,
    required this.crueltyFree,
  });
}
