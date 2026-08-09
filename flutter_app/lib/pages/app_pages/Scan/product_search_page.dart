import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/database_helper.dart';
import 'package:vegan_app/helpers/helper.dart';
import 'package:vegan_app/models/e_number.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/widgets/shared/app_background.dart';
import 'package:vegan_app/widgets/shared/app_card.dart';
import 'package:vegan_app/widgets/shared/empty_state_view.dart';

enum _SearchCategory { aliment, cosmetique, additif }

/// Unified product search page (Figma redesign): one search field, category
/// chips, results below. "Aliment" (name/barcode search) isn't built yet —
/// its chip is shown but disabled — so this currently covers Additifs and
/// Cosmétiques, which used to be two separate bottom sheets from the Scan
/// page.
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
    setState(() => _query = value);
    if (_category == _SearchCategory.cosmetique) {
      _searchCosmetics(value);
    }
  }

  void _clear() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _selectCategory(_SearchCategory category) {
    if (category == _category) return;
    setState(() => _category = category);
    if (category == _SearchCategory.cosmetique && _query.isNotEmpty) {
      _searchCosmetics(_query);
    }
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
        _SearchCategory.aliment => "Nom d'un produit ou code barre…",
      };

  @override
  Widget build(BuildContext context) {
    final List<Object> results = switch (_category) {
      _SearchCategory.additif => _filteredENumbers,
      _SearchCategory.cosmetique => _cosmeticResults,
      _SearchCategory.aliment => const <Object>[],
    };
    final hasQuery = _query.isNotEmpty;

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
                  style: TextStyle(fontSize: 42.sp),
                  decoration: InputDecoration(
                    hintText: _searchHint,
                    hintStyle:
                        TextStyle(fontSize: 42.sp, color: Colors.grey[500]),
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
                      icon: Icons.shopping_bag_outlined,
                      isSelected: _category == _SearchCategory.aliment,
                      enabled: false,
                      onTap: () {},
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
                    ? const EmptyStateView(
                        title: 'Recherchez un produit',
                        subtitle: 'Tapez un nom pour lancer la recherche.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 48.w),
                            child: Text(
                              'Résultats (${results.length})',
                              style: TextStyle(
                                fontSize: 44.sp,
                                fontWeight: FontWeight.bold,
                                color: kTextPrimary,
                              ),
                            ),
                          ),
                          SizedBox(height: 20.h),
                          Expanded(
                            child: results.isEmpty
                                ? const EmptyStateView(
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
                                      return item is CosmeticItem
                                          ? _buildCosmeticCard(item)
                                          : _buildAdditiveCard(
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
          decoration: BoxDecoration(
            color:
                isSelected ? primaryColor.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(36.r),
            border: Border.all(
              color: isSelected ? primaryColor : kBorderDefault,
              width: isSelected ? 1.5 : 1,
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
      decoration: BoxDecoration(
        color: Colors.orange[100],
        borderRadius: BorderRadius.circular(16.r),
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
