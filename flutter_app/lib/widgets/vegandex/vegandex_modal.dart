import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import '../../../models/product_of_interest.dart';
import '../../../models/scanned_product.dart';
import '../../../models/product_category.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/products_of_interest_cache.dart';
import 'category_list_view.dart';
import 'category_products_view.dart';

class VegandexModal extends StatefulWidget {
  final VoidCallback? onNavigateToProfile;

  const VegandexModal({super.key, this.onNavigateToProfile});

  @override
  State<VegandexModal> createState() => _VegandexModalState();
}

class _VegandexModalState extends State<VegandexModal> {
  List<ProductOfInterest> _products = [];
  List<ProductCategory> _categories = [];
  Map<String, ScannedProduct> _scannedProducts = {};
  bool _isLoading = true;
  bool _hasLocationPermission = false;
  ProductCategory? _selectedCategory;
  final baseUrl = dotenv.env['API_BASE_URL'];

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
      // Wait a bit for the modal to be fully displayed
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        _showWelcomeDialog();
      }
    }
  }

  void _showWelcomeDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: squircleBorder(radius: 24.r),
          child: Container(
            constraints: BoxConstraints(maxHeight: 2000.h),
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                ],
              ),
              shape: squircleBorder(radius: 24.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Column(
                    children: [
                      Icon(
                        Icons.catching_pokemon,
                        size: 120.sp,
                        color: Colors.white,
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Vegandex',
                            style: TextStyle(
                              fontSize: 72.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12.w, vertical: 4.h),
                            decoration: ShapeDecoration(
                              color: Colors.orangeAccent,
                              shape: squircleBorder(radius: 8.r),
                            ),
                            child: Text(
                              'BETA',
                              style: TextStyle(
                                fontSize: 36.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        '🚀 Nouvelle fonctionnalité !',
                        style: TextStyle(
                          fontSize: 48.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // How it works
                        Container(
                          padding: EdgeInsets.all(20.w),
                          decoration: ShapeDecoration(
                            color: Colors.white,
                            shape: squircleBorder(radius: 16.r),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.help_outline,
                                    size: 60.sp,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  SizedBox(width: 12.w),
                                  Text(
                                    'Comment ça marche ?',
                                    style: TextStyle(
                                      fontSize: 52.sp,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              _buildInfoRow(
                                Icons.qr_code_scanner,
                                'Scannez des produits du vegandex',
                              ),
                              SizedBox(height: 12.h),
                              _buildInfoRow(
                                Icons.collections,
                                'Collectionnez-les tous !',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),
                        // Map info
                        Container(
                          padding: EdgeInsets.all(20.w),
                          decoration: ShapeDecoration(
                            color: Colors.white,
                            shape: squircleBorder(radius: 16.r),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.map_outlined,
                                    size: 60.sp,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Text(
                                      'Recherche sur la carte',
                                      style: TextStyle(
                                        fontSize: 52.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                'Les scans de ces produits en magasin nous permettent de récolter des données géographiques. Ces données sont utilisées pour vous aider à trouver ces produits à l\'aide de la carte interactive !',
                                style: TextStyle(
                                  fontSize: 42.sp,
                                  color: Colors.grey[700],
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),
                        // Contact info
                        Container(
                          padding: EdgeInsets.all(20.w),
                          decoration: ShapeDecoration(
                            color: Colors.white,
                            shape: squircleBorder(radius: 16.r),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.feedback_outlined,
                                    size: 60.sp,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Text(
                                      'Votre avis compte !',
                                      style: TextStyle(
                                        fontSize: 52.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                'Un bug ? Une suggestion ? Contactez-nous :',
                                style: TextStyle(
                                  fontSize: 42.sp,
                                  color: Colors.grey[700],
                                  height: 1.3,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Row(
                                children: [
                                  Icon(
                                    Icons.mail_outline,
                                    size: 44.sp,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    'contact@321vegan.fr',
                                    style: TextStyle(
                                      fontSize: 40.sp,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  Icon(
                                    Icons.camera_alt,
                                    size: 44.sp,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    '@321vegan.app',
                                    style: TextStyle(
                                      fontSize: 40.sp,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24.h),
                      ],
                    ),
                  ),
                ),
                // Buttons
                Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor:
                                Theme.of(context).colorScheme.primary,
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            shape: squircleBorder(radius: 15.r),
                            elevation: 0,
                          ),
                          child: Text(
                            'OK',
                            style: TextStyle(
                              fontSize: 48.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      TextButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool(
                              'vegandex_show_welcome_popup', false);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          'Ne plus jamais montrer',
                          style: TextStyle(
                            fontSize: 40.sp,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 48.sp,
          color: Theme.of(context).colorScheme.primary,
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 42.sp,
              color: Colors.grey[700],
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _checkLocationPermission() async {
    try {
      // Try to check current permission with timeout
      final permission = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 3));

      final hasPermission = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      // Store the permission state if granted
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
      // If check fails (timeout, service unavailable, etc.), use stored state
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
        // If denied forever, open app settings
        if (permission == LocationPermission.deniedForever) {
          await openAppSettings();
        }
      } else if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Store permission state if granted
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('location_permission_granted', true);
      }
    } catch (e) {
      // Permission request timed out or failed
      // Show message to user
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

    // Re-check permission after request
    await _checkLocationPermission();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Fetch products from cache (instant) and categories in parallel
    // Cache will auto-update in background
    final results = await Future.wait([
      ProductsOfInterestCache.loadProductsOfInterest(),
      ApiService.getProductCategories(),
    ]);

    final products = results[0] as List<ProductOfInterest>;
    final categories = results[1] as List<ProductCategory>;

    // Get scanned products from current user and build a map
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

  void _navigateToProfile() {
    // Close the modal first
    Navigator.pop(context);

    // Use the callback if provided, otherwise show a snackbar message
    if (widget.onNavigateToProfile != null) {
      widget.onNavigateToProfile!();
    } else {
      // Fallback: show a snackbar message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Veuillez aller dans l\'onglet Profil pour vous connecter.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = AuthService.isLoggedIn;
    final bool showContent = isLoggedIn && _hasLocationPermission;

    return PopScope(
      canPop: _selectedCategory == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedCategory != null) {
          _onBackToCategories();
        }
      },
      child: Container(
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: squircleBorderOnly(topLeft: 28.r, topRight: 28.r),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: ShapeDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: squircleBorderOnly(topLeft: 28.r, topRight: 28.r),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 100.w,
                    height: 10.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    children: [
                      Icon(
                        Icons.catching_pokemon,
                        size: 80.sp,
                        color: Colors.white,
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Vegandex',
                                  style: TextStyle(
                                    fontSize: 64.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12.w, vertical: 4.h),
                                  decoration: ShapeDecoration(
                                    color: Colors.orangeAccent,
                                    shape: squircleBorder(radius: 8.r),
                                  ),
                                  child: Text(
                                    'BETA',
                                    style: TextStyle(
                                      fontSize: 36.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Scannez les produits pour les ajouter à votre collection. Trouvez-les tous !',
                              style: TextStyle(
                                fontSize: 40.sp,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          size: 80.sp,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  // Progress
                  if (showContent)
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 24.w, vertical: 16.h),
                      decoration: ShapeDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: squircleBorder(radius: 20.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified,
                            size: 60.sp,
                            color: Colors.white,
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            '${_getScannedCount()} / ${_products.length}',
                            style: TextStyle(
                              fontSize: 52.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'produits trouvés',
                            style: TextStyle(
                              fontSize: 40.sp,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Products grid
            Expanded(
              child: !isLoggedIn
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(48.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 200.sp,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 32.h),
                            Text(
                              'Connexion requise',
                              style: TextStyle(
                                fontSize: 64.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'Pour participer au Vegandex et collectionner des produits, vous devez vous connecter ou créer un compte.',
                              style: TextStyle(
                                fontSize: 48.sp,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 48.h),
                            SizedBox(
                              width: double.infinity,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24.w),
                                child: ElevatedButton(
                                  onPressed: _navigateToProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A722E),
                                    padding:
                                        EdgeInsets.symmetric(vertical: 16.h),
                                    shape: squircleBorder(radius: 15),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.login,
                                          color: Colors.white, size: 24),
                                      SizedBox(width: 12.w),
                                      Text(
                                        'Se connecter / S\'inscrire',
                                        style: TextStyle(
                                          fontSize: 40.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 24.h),
                            Icon(
                              Icons.catching_pokemon,
                              size: 160.sp,
                              color: const Color(0xFF1A722E)
                                  .withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ),
                    )
                  : !_hasLocationPermission
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(48.w),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_off,
                                  size: 200.sp,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: 32.h),
                                Text(
                                  'Géolocalisation requise',
                                  style: TextStyle(
                                    fontSize: 64.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  'La fonctionnalité Vegandex nécessite l\'accès à votre position pour ajouter des produits à votre collection. Ces données géographiques nous permettront d\'aider les utilisateur·ices à trouver ces produits ! Veuillez activer la géolocalisation.',
                                  style: TextStyle(
                                    fontSize: 48.sp,
                                    color: Colors.grey[600],
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 48.h),
                                SizedBox(
                                  width: double.infinity,
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 24.w),
                                    child: ElevatedButton(
                                      onPressed: _requestLocationPermission,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        padding: EdgeInsets.symmetric(
                                            vertical: 16.h),
                                        shape: squircleBorder(radius: 15),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.location_on,
                                              color: Colors.white, size: 24),
                                          SizedBox(width: 12.w),
                                          Text(
                                            'Activer la géolocalisation',
                                            style: TextStyle(
                                              fontSize: 40.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 24.h),
                                Icon(
                                  Icons.catching_pokemon,
                                  size: 160.sp,
                                  color: const Color(0xFF1A722E)
                                      .withValues(alpha: 0.3),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _products.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.inbox_outlined,
                                        size: 120.sp,
                                        color: Colors.grey[400],
                                      ),
                                      SizedBox(height: 16.h),
                                      Text(
                                        'Aucun produit disponible',
                                        style: TextStyle(
                                          fontSize: 48.sp,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _selectedCategory == null
                                  ? CategoryListView(
                                      categories: _categories,
                                      products: _products,
                                      scannedProducts: _scannedProducts,
                                      onCategoryTap: _onCategorySelected,
                                    )
                                  : CategoryProductsView(
                                      category: _selectedCategory!,
                                      allProducts: _products,
                                      scannedProducts: _scannedProducts,
                                      onBack: _onBackToCategories,
                                    ),
            ),
          ],
        ),
      ),
    );
  }
}
