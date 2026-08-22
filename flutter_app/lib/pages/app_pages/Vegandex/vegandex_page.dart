import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/product_of_interest.dart';
import '../../../models/scanned_product.dart';
import '../../../models/product_category.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/products_of_interest_cache.dart';
import '../../../themes/app_colors.dart';
import '../../../themes/app_text_styles.dart';
import '../../../widgets/shared/app_background.dart';
import '../../../widgets/shared/empty_state_view.dart';
import '../../../widgets/vegandex/category_list_view.dart';
import '../../../widgets/vegandex/category_products_view.dart';
import '../../../widgets/vegandex/vegandex_stats_illustration.dart';
import '../../../widgets/vegandex/vegandex_welcome_modal.dart';
import '../settings/settings_page.dart';

/// Full-screen Vegandex page: collection progress illustration up top,
/// category rows below. Pushed from the Dashboard's Vegandex card and the
/// Scan page's Vegandex button — used to be a bottom sheet.
class VegandexPage extends StatefulWidget {
  const VegandexPage({super.key});

  @override
  State<VegandexPage> createState() => _VegandexPageState();
}

class _VegandexPageState extends State<VegandexPage> {
  List<ProductOfInterest> _products = [];
  List<ProductCategory> _categories = [];
  Map<String, ScannedProduct> _scannedProducts = {};
  bool _isLoading = true;
  bool _hasLocationPermission = false;
  ProductCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _loadData();
    _checkAndShowWelcomePopup();
  }

  Future<void> _checkAndShowWelcomePopup() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldShowPopup =
        prefs.getBool('vegandex_show_welcome_popup') ?? true;

    if (shouldShowPopup && mounted) {
      // Wait a bit for the page to be fully displayed
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        _showWelcomeDialog();
      }
    }
  }

  Future<void> _showWelcomeDialog() async {
    final dismissedForGood = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VegandexWelcomeModal(),
    );

    if (dismissedForGood == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('vegandex_show_welcome_popup', false);
    }
  }

  Future<void> _checkLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 3));

      final hasPermission = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      if (hasPermission) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('location_permission_granted', true);
      }

      if (mounted) {
        setState(() {
          _hasLocationPermission = hasPermission;
        });
      }
    } catch (e) {
      // Timeout or service unavailable: fall back to the stored state.
      final prefs = await SharedPreferences.getInstance();
      final storedPermission =
          prefs.getBool('location_permission_granted') ?? false;

      if (mounted) {
        setState(() {
          _hasLocationPermission = storedPermission;
        });
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      final permission = await Geolocator.requestPermission()
          .timeout(const Duration(seconds: 10));

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (permission == LocationPermission.deniedForever) {
          await openAppSettings();
        }
      } else if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('location_permission_granted', true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible de vérifier les permissions. Veuillez vérifier votre connexion et réessayer.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }

    await _checkLocationPermission();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Products load instantly from cache, which auto-updates in background.
    final results = await Future.wait([
      ProductsOfInterestCache.loadProductsOfInterest(),
      ApiService.getProductCategories(),
    ]);

    final products = results[0] as List<ProductOfInterest>;
    final categories = results[1] as List<ProductCategory>;

    final user = AuthService.currentUser;
    final scannedProductsList = user?.scannedProducts ?? [];
    final scannedProductsMap = {
      for (var sp in scannedProductsList) sp.ean: sp,
    };

    if (mounted) {
      setState(() {
        _products = products;
        _categories = categories;
        _scannedProducts = scannedProductsMap;
        _isLoading = false;
      });
    }
  }

  bool _isProductScanned(String ean) {
    return _scannedProducts.containsKey(ean);
  }

  int _getScannedCount() {
    return _products.where((product) => _isProductScanned(product.ean)).length;
  }

  void _onCategorySelected(ProductCategory category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  void _onBackToCategories() {
    setState(() {
      _selectedCategory = null;
    });
  }

  // Same gate as Dashboard's _openErrorReports: push SettingsPage (which
  // shows the login form when logged out) instead of just switching tabs.
  // Refresh on return since the product list is scoped to scanned EANs.
  Future<void> _navigateToProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    if (mounted) {
      setState(() {});
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = AuthService.isLoggedIn;
    final bool showContent = isLoggedIn && _hasLocationPermission;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // No AppBar once a category is selected — CategoryProductsView has
        // its own back arrow + name header, so a "Vegandex" bar on top of
        // it would just be a redundant second header.
        appBar: _selectedCategory == null
            ? AppBar(
                title: Text('Vegandex', style: AppTextStyles.baloo22),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                foregroundColor: kTextPrimary,
              )
            : null,
        body: SafeArea(
          top: _selectedCategory != null,
          child: PopScope(
            canPop: _selectedCategory == null,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && _selectedCategory != null) {
                _onBackToCategories();
              }
            },
            child: Column(
              children: [
                if (_selectedCategory == null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(48.w, 0, 48.w, 12.h),
                    child: VegandexStatsIllustration(
                      scannedCount: _getScannedCount(),
                      totalCount: _products.length,
                    ),
                  ),
                Expanded(child: _buildBody(isLoggedIn, showContent)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isLoggedIn, bool showContent) {
    if (!isLoggedIn) {
      return EmptyStateView(
        title: 'Connexion requise',
        subtitle:
            'Pour participer au Vegandex et collectionner des produits, vous devez vous connecter ou créer un compte.',
        buttonLabel: 'Se connecter / S\'inscrire',
        onButtonTap: _navigateToProfile,
      );
    }

    if (!_hasLocationPermission) {
      return EmptyStateView(
        title: 'Géolocalisation requise',
        subtitle:
            'La fonctionnalité Vegandex nécessite l\'accès à votre position pour ajouter des produits à votre collection. Ces données géographiques nous permettront d\'aider les utilisateur·ices à trouver ces produits !',
        buttonLabel: 'Activer la géolocalisation',
        onButtonTap: _requestLocationPermission,
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_products.isEmpty) {
      return const EmptyStateView(
        title: 'Aucun produit disponible',
        subtitle: 'Revenez plus tard, de nouveaux produits arrivent !',
      );
    }

    return _selectedCategory == null
        ? CategoryListView(
            categories: _categories,
            products: _products,
            scannedProducts: _scannedProducts,
            onCategoryTap: _onCategorySelected,
          )
        : Padding(
            padding: EdgeInsets.symmetric(horizontal: 48.w),
            child: CategoryProductsView(
              category: _selectedCategory!,
              allProducts: _products,
              scannedProducts: _scannedProducts,
              onBack: _onBackToCategories,
            ),
          );
  }
}
