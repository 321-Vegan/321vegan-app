import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vegan_app/helpers/database_helper.dart';
import 'package:vegan_app/helpers/haptic_helper.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/pages/app_pages/Scan/history_modal.dart';
import 'package:vegan_app/pages/app_pages/Scan/sent_products_modal.dart';
import 'package:vegan_app/pages/app_pages/Scan/settings_modal.dart';
import 'package:vegan_app/pages/app_pages/Scan/search_modal.dart';
import 'package:vegan_app/pages/app_pages/Scan/product_info_helper.dart';
import 'package:vegan_app/pages/app_pages/Search/additives.dart';
import 'package:vegan_app/pages/app_pages/Search/cosmetics.dart';
import 'package:vegan_app/models/product_of_interest.dart';
import 'package:vegan_app/models/scan_result.dart';
import 'package:vegan_app/services/auth_service.dart';
import 'package:vegan_app/services/offline_scan_service.dart';
import 'package:vegan_app/services/scan_count_sync_service.dart';
import 'package:vegan_app/services/products_of_interest_cache.dart';
import 'package:vegan_app/widgets/scaner/card_product.dart';
import 'package:vegan_app/widgets/scaner/pending_product_info_card.dart';
import 'package:vegan_app/widgets/scaner/info_dialog_button.dart';
import 'package:vegan_app/models/seasonal_theme.dart';
import 'package:vegan_app/widgets/scaner/vegan_product_info_card.dart';
import 'package:vegan_app/widgets/scaner/shop_confirmation_modal.dart';
import 'package:vegan_app/widgets/vegandex/vegandex_modal.dart';
import 'package:vegan_app/widgets/vegandex/product_found_modal.dart';
import 'package:vegan_app/widgets/auth/register_form.dart';
import 'package:vegan_app/widgets/auth/login_form.dart';
import 'package:vegan_app/services/subscription_service.dart';
import 'package:vegan_app/widgets/scaner/product_scores_section.dart';
import 'package:vegan_app/pages/app_pages/Scan/account_prompt_dialog.dart';

class ScanPage extends StatefulWidget {
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onLoginSuccess;

  const ScanPage({super.key, this.onNavigateToProfile, this.onLoginSuccess});

  @override
  ScanPageState createState() => ScanPageState();
}

class ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  final MobileScannerController controller = MobileScannerController(
    formats: [
      BarcodeFormat.ean13, // EAN-13 for international products
      BarcodeFormat.ean8, // EAN-8 for smaller packages
      BarcodeFormat.upcA, // UPC-A for US and Canadian products
      BarcodeFormat.upcE, // UPC-E for compressed barcodes
    ],
  );
  ScanResult? productInfo;
  List<Map<String, dynamic>> scanHistory = [];
  String? _lastScannedBarcode = '';
  late ConfettiController _confettiController;
  final nonVeganCardKey = GlobalKey<NonVeganProductInfoCardState>();
  bool _openOnScanPage = false;
  bool _showBoycott = true;
  bool _showScores = true;
  bool _hapticFeedback = true;
  List<String> _productsOfInterest = [];
  Map<String, ProductOfInterest> _productsOfInterestMap = {};
  Map<String, String> _alternativeEanToMainEan = {};
  bool _scannerPausedByModal = false;
  bool _isRetrying = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!controller.value.isInitialized) {
      return;
    }

    if (!mounted) {
      return;
    }

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        controller.stop();
        break;
      case AppLifecycleState.resumed:
        if (!_scannerPausedByModal) {
          controller.start();
        }
        // Retry pending scans when app resumes
        _retryPendingScans();
        break;
      case AppLifecycleState.inactive:
        controller.stop();
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    _loadScanHistory();
    _loadOpenOnScanPagePref();
    _loadShowBoycottPref();
    _loadShowScoresPref();
    _loadHapticFeedbackPref();
    // Load products from already-populated cache (populated at app startup)
    _loadProductsOfInterest();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationPermission();
      _startScanner();
      _retryPendingScans();
    });

    // Sync queued offline scans as soon as connectivity comes back, instead
    // of waiting for the next app resume.
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        _retryPendingScans();
      }
    });
  }

  /// Retry pending scans when app starts or resumes
  Future<void> _retryPendingScans() async {
    if (_isRetrying) return;
    _isRetrying = true;
    try {
      // Also flush the user scan-counter queue (it serializes itself and
      // no-ops when there is nothing to send).
      unawaited(ScanCountSyncService.sync());

      final pendingCount = await OfflineScanService.getPendingCount();
      if (pendingCount == 0) return;

      final (successCount, shopConfirmations) =
          await OfflineScanService.retryPendingScans();

      if (successCount > 0 && mounted) {
        if (AuthService.isLoggedIn) {
          AuthService.getCurrentUser();
        }

        for (final confirmation in shopConfirmations) {
          if (!mounted) break;

          final ean = confirmation['ean'] as String;
          final shopName = confirmation['shop_name'] as String;
          final scanEventId = confirmation['scan_event_id'] as int;
          final nearbyShops = (confirmation['nearby_shops'] as List<dynamic>?)
              ?.map((s) => Map<String, dynamic>.from(s as Map))
              .toList();
          final shopId = confirmation['shop_id'];
          final String? shopOsmId =
              (shopId == null && nearbyShops != null && nearbyShops.isNotEmpty)
                  ? nearbyShops.first['osm_id'] as String?
                  : null;

          final mainEan = _alternativeEanToMainEan[ean] ?? ean;
          final product = _productsOfInterestMap[mainEan];
          if (product != null) {
            // Await each dialog so multiple confirmations are shown one after
            // the other instead of stacking on top of each other.
            await _showShopConfirmationDialog(shopName, scanEventId, product,
                nearbyShops: nearbyShops, shopOsmId: shopOsmId);
          }
        }
      }
    } finally {
      _isRetrying = false;
    }
  }

  Future<bool> _checkCameraPermission({bool showDialogOnDenied = true}) async {
    var status = await Permission.camera.status;

    if (status.isDenied) {
      status = await Permission.camera.request();
    }

    if (status.isGranted) return true;

    if (showDialogOnDenied) {
      _showPermissionDialog();
    }

    return false;
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission requise'),
          content: const Text(
            'L\'accès à la caméra est nécessaire pour scanner les codes-barres. '
            'Veuillez autoriser l\'accès dans les paramètres de l\'application.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Paramètres'),
            ),
          ],
        );
      },
    );
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Géolocalisation requise'),
          content: const Text(
            'Vous avez scanné un produit du Vegandex ! Prochainement, une fonctionnalité permettra d\'afficher une carte pour les trouver. \nPour aider la communauté, '
            'nous avons besoin de votre localisation lorsque vous scannez ces produits. '
            'Voulez-vous activer la géolocalisation ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Plus tard'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                LocationPermission permission =
                    await Geolocator.requestPermission();
                if (permission == LocationPermission.deniedForever) {
                  openAppSettings();
                }
              },
              child: const Text('Activer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showShopConfirmationDialog(
      String shopName, int scanEventId, ProductOfInterest product,
      {List<Map<String, dynamic>>? nearbyShops, String? shopOsmId}) {
    // Stop scanner while showing modal
    controller.stop();

    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return ShopConfirmationModal(
          shopName: shopName,
          scanEventId: scanEventId,
          product: product,
          nearbyShops: nearbyShops ?? [],
          shopOsmId: shopOsmId,
        );
      },
    ).then((_) {
      // Restart scanner when modal closes
      controller.start();
    });
  }

  Future<bool> _checkLocationPermission() async {
    try {
      // Try to check current permission with timeout
      LocationPermission permission = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 3));

      // If denied, try to request permission
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission()
            .timeout(const Duration(seconds: 10));
      }

      final hasPermission = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      // Store the permission state if granted
      if (hasPermission) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('location_permission_granted', true);
      }

      return hasPermission;
    } catch (e) {
      // If check fails (timeout, service unavailable, etc.), use stored state
      final prefs = await SharedPreferences.getInstance();
      final storedPermission =
          prefs.getBool('location_permission_granted') ?? false;
      return storedPermission;
    }
  }

  Future<void> _startScanner() async {
    try {
      // Check camera permission first
      bool hasPermission = await _checkCameraPermission();
      if (!hasPermission) {
        return;
      }

      // Wait for the widget to be fully built before starting scanner
      await Future.delayed(const Duration(milliseconds: 100));

      // Check if the controller is properly initialized
      if (!mounted) {
        return;
      }

      await controller.start();
    } catch (e) {
      // Try to restart scanner after a longer delay in debug mode
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        await controller.start();
      }
    }
  }

  Future<void> _loadScanHistory() async {
    final history = await PreferencesHelper.getScanHistory();
    setState(() {
      scanHistory = history;
    });
  }

  Future<void> _loadOpenOnScanPagePref() async {
    final value = await PreferencesHelper.getOpenOnScanPagePref();
    setState(() {
      _openOnScanPage = value;
    });
  }

  Future<void> _loadShowBoycottPref() async {
    final value = await PreferencesHelper.getShowBoycottPref();
    setState(() {
      _showBoycott = value;
    });
  }

  Future<void> _loadShowScoresPref() async {
    final value = await PreferencesHelper.getShowScoresPref();
    setState(() {
      _showScores = value;
    });
  }

  Future<void> _setShowScoresPref(bool value) async {
    await PreferencesHelper.setShowScoresPref(value);
    setState(() {
      _showScores = value;
    });
  }

  Future<void> _loadHapticFeedbackPref() async {
    final value = await PreferencesHelper.getHapticFeedbackPref();
    setState(() {
      _hapticFeedback = value;
    });
  }

  Future<void> _loadProductsOfInterest() async {
    // Load from cache instantly, updates in background automatically
    final products = await ProductsOfInterestCache.loadProductsOfInterest();
    final altEanMap = <String, String>{};
    for (final p in products) {
      for (final altEan in p.alternativeEans) {
        altEanMap[altEan] = p.ean;
      }
    }
    setState(() {
      _productsOfInterest = products.map((p) => p.ean).toList();
      _productsOfInterestMap = {for (var p in products) p.ean: p};
      _alternativeEanToMainEan = altEanMap;
    });
  }

  Future<void> _sendScanEventIfInteresting(String ean) async {
    // Resolve alternative EAN to main EAN if applicable
    final mainEan = _alternativeEanToMainEan[ean] ?? ean;

    // Check if this product is in the products of interest
    if (!_productsOfInterest.contains(mainEan)) {
      return;
    }

    // Store whether this is a new discovery before updating
    final user = AuthService.currentUser;
    final hadProductBefore =
        user?.scannedProducts?.any((sp) => sp.ean == mainEan) ?? false;

    // Show modal if product found (don't wait for location)
    final product = _productsOfInterestMap[mainEan];
    if (product != null && mounted) {
      // Stop scanner while showing modal
      controller.stop();

      // Start fetching location in the background
      final locationFuture = _getLocationForScanEvent();

      await showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        builder: (context) => ProductFoundModal(
          product: product,
          isNewDiscovery: !hadProductBefore,
        ),
      );

      // Restart scanner after modal is closed
      controller.start();

      // Optimistically update scanned products locally
      AuthService.addScannedProductLocally(mainEan);

      // Wait for location to be fetched and send scan event
      final locationData = await locationFuture;
      final latitude = locationData.latitude;
      final longitude = locationData.longitude;

      // If the user hasn't granted location permission, we don't record the
      // scan server-side (a prompt was already shown to enable it). But if
      // permission IS granted and we simply couldn't get a fix (offline, GPS
      // timeout), we still queue the scan — without coordinates — so the
      // user's collection syncs once connectivity is back.
      if (!locationData.permissionGranted) {
        return;
      }

      // Get current user ID
      final userId = AuthService.currentUser?.id;

      // Use offline scan service with automatic retry
      final (success, response, shouldShowDialog) =
          await OfflineScanService.postScanEventWithOfflineSupport(
        ean: mainEan,
        latitude: latitude,
        longitude: longitude,
        userId: userId,
      );

      if (success && response != null && mounted) {
        // Refresh user data to get updated scanned products
        if (AuthService.isLoggedIn) {
          AuthService.getCurrentUser();
        }

        // Check if a shop was detected and we should show dialog
        if (shouldShowDialog) {
          final shopName = response['shop_name'] as String?;
          final scanEventId = response['id'] as int?;
          final nearbyShops = (response['nearby_shops'] as List<dynamic>?)
              ?.map((s) => Map<String, dynamic>.from(s as Map))
              .toList();

          // If no shop was linked yet (OSM-only), the primary shop is the
          // first entry in nearbyShops — pass its osm_id so the modal can
          // confirm it when the user taps "Yes".
          final String? shopOsmId = (response['shop_id'] == null &&
                  nearbyShops != null &&
                  nearbyShops.isNotEmpty)
              ? nearbyShops.first['osm_id'] as String?
              : null;

          if (shopName != null && scanEventId != null) {
            // Show confirmation dialog for shop location
            _showShopConfirmationDialog(shopName, scanEventId, product,
                nearbyShops: nearbyShops, shopOsmId: shopOsmId);
          }
        }
      }
    }
  }

  Future<({double? latitude, double? longitude, bool permissionGranted})>
      _getLocationForScanEvent() async {
    double? latitude;
    double? longitude;
    bool hasPermission = false;

    try {
      // Check if we have location permission
      hasPermission = await _checkLocationPermission();

      // Get position if permission granted
      if (hasPermission) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
        latitude = position.latitude;
        longitude = position.longitude;
      } else {
        // Permission genuinely not granted — prompt the user to enable it.
        if (mounted) {
          _showLocationPermissionDialog();
        }
      }
    } catch (e) {
      // Permission is granted but we couldn't obtain a fresh position (e.g.
      // offline or the GPS fix timed out within 5s). Don't show the "enable
      // location" dialog — it would wrongly tell the user location is
      // disabled. Fall back to the last known position if it's recent enough
      // that the user is plausibly still in the same place, so shop detection
      // keeps working; otherwise the scan is queued without coordinates.
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null &&
            DateTime.now().difference(lastKnown.timestamp) <
                const Duration(minutes: 10)) {
          latitude = lastKnown.latitude;
          longitude = lastKnown.longitude;
        }
      } catch (_) {}
    }

    return (
      latitude: latitude,
      longitude: longitude,
      permissionGranted: hasPermission,
    );
  }

  /// Stops the scanner, clears the current result, shows [modal] in a
  /// 90%-height bottom sheet and restarts the scanner when it closes.
  void _showModalSheet(Widget modal) {
    controller.stop();
    setState(() {
      productInfo = null;
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: modal,
      ),
    ).then((_) {
      controller.start();
    });
  }

  void _showSearchModal({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    _showModalSheet(SearchModal(
      title: title,
      subtitle: subtitle,
      icon: icon,
      child: child,
    ));
  }

  void _showSettingsModal() {
    // Stop the scanner when opening the modal
    controller.stop();
    setState(() {
      productInfo = null;
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: SettingsModal(
            initialOpenOnScanPage: _openOnScanPage,
            onOpenOnScanPageChanged: (value) {
              setState(() {
                _openOnScanPage = value;
              });
            },
            initialShowBoycott: _showBoycott,
            onShowBoycottChanged: (value) {
              setState(() {
                _showBoycott = value;
              });
            },
            initialShowScores: _showScores,
            onShowScoresChanged: _setShowScoresPref,
            initialHapticFeedback: _hapticFeedback,
            onHapticFeedbackChanged: (value) {
              setState(() {
                _hapticFeedback = value;
              });
            },
          ),
        );
      },
    ).then((_) {
      controller.start();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    controller.dispose();
    _confettiController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkVeganStatusOffline(String barcode) async {
    final product = await ProductInfoHelper.getProductInfo(barcode);
    setState(() {
      productInfo = product;
    });

    // Scan-confirmation haptic: double pulse warns that the product is not
    // vegan, single pulse for everything else.
    if (_hapticFeedback) {
      if (product.status == ScanStatus.notVegan) {
        HapticHelper.doubleImpact();
      } else {
        HapticHelper.impact();
      }
    }

    // Products missing from the database (unknown, or already submitted by
    // the user) don't belong in the scan history.
    if (product.status != ScanStatus.unknown &&
        product.status != ScanStatus.alreadyScanned) {
      await PreferencesHelper.addBarcodeToHistory(barcode);
      _loadScanHistory();
    }

    if ((product.status == ScanStatus.vegan ||
            product.status == ScanStatus.notVegan) &&
        AuthService.isLoggedIn &&
        !SubscriptionService.isSubscribed) {
      await PreferencesHelper.incrementMembershipHitScanCount();
    }
  }

  bool isValidEAN13(String barcode) {
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.parse(barcode[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    int checksum = (10 - (sum % 10)) % 10;
    return checksum == int.parse(barcode[12]);
  }

  bool isValidEAN8(String barcode) {
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      int digit = int.parse(barcode[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    int checksum = (10 - (sum % 10)) % 10;
    return checksum == int.parse(barcode[7]);
  }

  void _simulateScan(String rawValue) {
    var barcodeValue = rawValue.trim();
    if (barcodeValue.length == 12) {
      barcodeValue = '0$barcodeValue';
    }
    if (barcodeValue.isEmpty) return;
    if (_lastScannedBarcode == barcodeValue) {
      _lastScannedBarcode = ''; // allow re-scanning same barcode in debug
    }
    _handleBarcode(BarcodeCapture(
      barcodes: [Barcode(rawValue: barcodeValue)],
    ));
  }

  void _showManualEanDialog() {
    final textController = TextEditingController();

    bool isValid(String raw) {
      String normalized = raw;
      if (normalized.length == 12) normalized = '0$normalized';
      if (normalized.length == 13 && isValidEAN13(normalized)) return true;
      if (normalized.length == 8 && isValidEAN8(normalized)) return true;
      return false;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String? errorText;
        List<Map<String, dynamic>> suggestions = [];
        int suggestionQueryId = 0;
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            void updateSuggestions(String raw) {
              final prefix = raw.trim();
              if (prefix.length < 3) {
                suggestionQueryId++;
                if (suggestions.isNotEmpty) {
                  setStateDialog(() => suggestions = []);
                }
                return;
              }
              final queryId = ++suggestionQueryId;
              DatabaseHelper.instance
                  .queryProductsByCodePrefix(prefix)
                  .then((results) {
                if (queryId != suggestionQueryId || !ctx.mounted) return;
                setStateDialog(() => suggestions = results);
              });
            }

            void submit() {
              final raw = textController.text.trim();
              if (isValid(raw)) {
                Navigator.of(ctx).pop();
                _simulateScan(raw);
              } else {
                setStateDialog(
                    () => errorText = 'Code-barres invalide (EAN-8 ou EAN-13)');
              }
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(CupertinoIcons.barcode,
                              size: 32, color: Colors.grey.shade700),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Saisir un code-barres',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Si le scan par caméra est impossible,\nsaisissez le code manuellement.',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: textController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                      ),
                      decoration: InputDecoration(
                        hintText: '3017620422003',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade300,
                          fontWeight: FontWeight.normal,
                          letterSpacing: 2,
                        ),
                        errorText: errorText,
                        errorStyle: const TextStyle(fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF1A722E), width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.red, width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        if (errorText != null) {
                          setStateDialog(() => errorText = null);
                        }
                        updateSuggestions(value);
                      },
                      onSubmitted: (_) => submit(),
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...suggestions.map((product) {
                        final code = product['code']?.toString() ?? '';
                        final name =
                            ((product['name'] as String?) ?? 'Produit inconnu')
                                .replaceAll('&quot;', "'");
                        final brand = ((product['brand'] as String?) ?? '')
                            .replaceAll('&quot;', "'");
                        final statusColor = switch (product['status']) {
                          'R' => Colors.red,
                          'M' => Colors.orange,
                          'N' => Colors.grey,
                          _ => const Color(0xFF1A722E),
                        };
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _simulateScan(code);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          brand.isNotEmpty
                                              ? '$name - $brand'
                                              : name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          code,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right,
                                      size: 20, color: Colors.grey.shade400),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                              foregroundColor: Colors.grey.shade700,
                            ),
                            child: const Text('Annuler',
                                style: TextStyle(fontSize: 15)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A722E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text('Scanner',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleBarcode(BarcodeCapture event) {
    final barcode = event.barcodes.first;
    var barcodeValue = barcode.rawValue;
    // If there is 12 digits, add a 0 at the beginning
    // This is a workaround for EAN-13 barcodes that are sometimes scanned as 12 digits by the scan module
    // This happens when the barcode starts with 0
    if (barcodeValue != null && barcodeValue.length == 12) {
      barcodeValue = '0$barcodeValue';
    }

    if (barcodeValue != null && barcodeValue.length == 13) {
      if (!isValidEAN13(barcodeValue)) {
        return;
      }
    }

    if (barcodeValue != null && _lastScannedBarcode != barcodeValue) {
      _lastScannedBarcode = barcodeValue;

      // The haptic fires in _checkVeganStatusOffline once the product
      // status is known, so non-vegan products can get a distinct pattern.

      // Reset the button disabled state in NonVeganProductInfoCardState
      nonVeganCardKey.currentState?.resetButton();

      // Check if we should prompt the user to create an account
      _checkAccountPrompt();

      // Send scan event if it's a product of interest (don't wait for it)
      _sendScanEventIfInteresting(barcodeValue.toString());

      setState(() {
        productInfo = null; // Reset product info for the new scan
      });
      _checkVeganStatusOffline(barcodeValue.toString());
    }
  }

  Future<void> _checkAccountPrompt() async {
    final totalScans = await PreferencesHelper.incrementTotalScanCount();

    // Mirror the scan to the server-side user counter (queued and batched
    // when offline, sent on the next sync trigger).
    unawaited(ScanCountSyncService.onScanRecorded());

    if (totalScans % 5 != 0) return;

    if (AuthService.isLoggedIn) return;

    final dismissed = await PreferencesHelper.hasAccountPromptBeenDismissed();
    if (dismissed) return;

    if (!mounted) return;

    // Small delay so the scan result shows first
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    _showAccountPromptDialog();
  }

  void _showAccountPromptDialog() {
    controller.stop();

    showDialog(
      context: context,
      builder: (_) =>
          AccountPromptDialog(onCreateAccount: _showAuthBottomSheet),
    ).then((_) {
      controller.start();
    });
  }

  void _showAuthBottomSheet() {
    controller.stop();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.all(28.w),
              child: _AuthSheetContent(
                onSuccess: () {
                  Navigator.of(context).pop();
                  widget.onLoginSuccess?.call();
                },
              ),
            ),
          ),
        ),
      ),
    ).then((_) {
      controller.start();
    });
  }

  /// Gray tint shared by the scan page's glass buttons, so they stay
  /// readable over bright scenes (the Vegandex button keeps its gold tint).
  static const LiquidGlassAppearance _grayGlassAppearance =
      LiquidGlassAppearance(
    color: Color(0x80757575), // grey 600 at 50%
    blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
  );

  /// Small square liquid-glass icon button (settings, history, ...),
  /// styled consistently with [LiquidGlassButton].
  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
    double? iconSize,
  }) {
    return LiquidGlassLens(
      style: LiquidGlassButton.defaultStyle.copyWith(
        shape: LiquidGlassShape.roundedRectangle(
          cornerRadius: 20.r,
          borderWidth: 1.1,
          lightIntensity: 1.2,
          lightDirection: 80,
          borderType: const OpticalBorder(
            borderSaturation: 1.2,
            ambientIntensity: 1.0,
            borderSolidity: 0.35,
          ),
        ),
        appearance: _grayGlassAppearance,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(8.w),
            child: Icon(
              icon,
              color: Colors.white,
              size: iconSize ?? 80.sp,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanWarningBox(String text) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: Border.all(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning,
            color: Colors.orange[800],
            size: 80.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 36.sp,
                color: Colors.orange[900],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(0.0),
                child: SizedBox(
                  height: 0.55.sh,
                  child: MobileScanner(
                    controller: controller,
                    onDetect: (BarcodeCapture capture) {
                      _handleBarcode(capture);
                    },
                  ),
                ),
              ),
            ],
          ),
          // Camera-area overlays (warnings + score bar) flow bottom-up in a
          // single column ending just above the result card, so they never
          // overlap each other whatever the device height or text length.
          if (productInfo != null)
            Positioned(
              top: 0,
              left: 16,
              right: 16,
              height: 1090.h,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 24.h,
                children: [
                  if (productInfo!.isEan8 &&
                      productInfo!.status != ScanStatus.unknown)
                    _buildScanWarningBox(
                      'Code EAN-8 : Ce code-barres peut correspondre à plusieurs produits différents. Vérifiez bien le nom et la marque.',
                    ),
                  if (productInfo!.hasNonVeganOldRecipe == true)
                    _buildScanWarningBox(
                      'Ancienne recette non vegan : il se peut qu\'il y ait encore du stock avec l\'ancienne recette. Vérifiez les ingrédients.',
                    ),
                  if (productInfo!.status == ScanStatus.vegan)
                    ProductScoresSection(
                      barcode: productInfo!.code,
                      isSubscribed: SubscriptionService.isSubscribed,
                      enabled: _showScores,
                      onDisable: () => _setShowScoresPref(false),
                    ),
                ],
              ),
            ),
          // Add the floating button for Vegandex
          Positioned(
            top: 180.h,
            right: 20,
            child: Container(
              width: 0.25.sw,
              height: 0.05.sh,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40.r),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFD700), // Gold
                    Color(0xFFFFAF00), // Darker gold
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(40.r),
                  onTap: () => _showModalSheet(VegandexModal(
                    onNavigateToProfile: widget.onNavigateToProfile,
                  )),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.catching_pokemon,
                          color: Colors.white,
                          size: 40.sp,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Vegandex",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40.sp,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Result card with bottom margin
          if (productInfo != null)
            Positioned(
              top: 1100.h,
              left: 16,
              right: 16,
              child: switch (productInfo!.status) {
                ScanStatus.vegan => VeganProductInfoCard(
                    productInfo: productInfo!,
                    showBoycott: _showBoycott,
                    onBoycottToggleChanged: (value) {
                      setState(() {
                        _showBoycott = value;
                      });
                    },
                  ),
                ScanStatus.pending =>
                  PendingProductInfoCard(productInfo: productInfo!),
                ScanStatus.alreadyScanned =>
                  const AlreadyScannedProductInfoCard(),
                ScanStatus.notFound =>
                  NotFoundProductInfoCard(productInfo: productInfo!),
                ScanStatus.unknown => NonVeganProductInfoCard(
                    key: nonVeganCardKey,
                    productInfo: productInfo!,
                    confettiController: _confettiController,
                    onNavigateToProfile: widget.onNavigateToProfile,
                    onScannerStop: () {
                      _scannerPausedByModal = true;
                      controller.stop();
                    },
                    onScannerStart: () {
                      _scannerPausedByModal = false;
                      controller.start();
                    },
                  ),
                ScanStatus.notVegan =>
                  RejectedProductInfoCard(productInfo: productInfo!),
              },
            )
          else // Show prompt when not loading and no data
            Positioned(
              top: 1100.h,
              left: 16,
              right: 16,
              child: const NoResultCard(),
            ),
          if (productInfo != null && productInfo!.status != ScanStatus.unknown)
            Positioned(
              bottom: 240.h,
              left: 0,
              right: 0,
              child: Center(
                child: productInfo!.status == ScanStatus.notFound
                    ? SendInfoButton(
                        barcode: productInfo!.code,
                        onScannerStop: () {
                          _scannerPausedByModal = true;
                          controller.stop();
                        },
                        onScannerStart: () {
                          _scannerPausedByModal = false;
                          controller.start();
                        },
                      )
                    : ReportErrorButton(
                        barcode: productInfo!.code,
                        onScannerStop: () {
                          _scannerPausedByModal = true;
                          controller.stop();
                        },
                        onScannerStart: () {
                          _scannerPausedByModal = false;
                          controller.start();
                        },
                      ),
              ),
            ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 20,
                maxBlastForce: 100.r,
                minBlastForce: 20.r,
                gravity: 0.1,
                colors: Theme.of(context)
                        .extension<SeasonalTheme>()
                        ?.confettiColors ??
                    const [
                      Colors.red,
                      Colors.blue,
                      Colors.green,
                      Colors.yellow,
                    ],
              ),
            ),
          ),
          Positioned(
            bottom: 100.h,
            right: 20,
            child: _buildGlassIconButton(
              icon: Icons.keyboard_outlined,
              iconSize: 90.sp,
              onTap: _showManualEanDialog,
            ),
          ),
          // Floating action cluster (positioned last to be on top):
          // settings / history / sent products in a row, with the additives
          // and cosmetics searches below. Single anchor point; Row/Column
          // spacing handles the rest.
          Positioned(
            top: 200.h,
            left: 60.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 40.h,
              children: [
                Row(
                  spacing: 60.w,
                  children: [
                    _buildGlassIconButton(
                      icon: Icons.settings,
                      onTap: _showSettingsModal,
                    ),
                    _buildGlassIconButton(
                      icon: Icons.history,
                      onTap: () => _showModalSheet(
                        HistoryModal(scanHistory: scanHistory),
                      ),
                    ),
                    _buildGlassIconButton(
                      icon: Icons.switch_access_shortcut_add_outlined,
                      onTap: () => _showModalSheet(const SentProductsModal()),
                    ),
                  ],
                ),
                IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 24.h,
                    children: [
                      LiquidGlassButton(
                        label: 'Additifs 🔎',
                        icon: Icons.science,
                        height: 100.h,
                        fontSize: 40.sp,
                        iconSize: 80.sp,
                        style: LiquidGlassButton.defaultStyle.copyWith(
                          appearance: _grayGlassAppearance,
                        ),
                        onPressed: () => _showSearchModal(
                          title: 'Additifs',
                          subtitle: 'Rechercher un additif',
                          icon: Icons.science,
                          child: const AdditivesPage(),
                        ),
                      ),
                      LiquidGlassButton(
                        label: 'Cosmétiques 🔎',
                        icon: Icons.soap_rounded,
                        height: 100.h,
                        fontSize: 40.sp,
                        iconSize: 80.sp,
                        style: LiquidGlassButton.defaultStyle.copyWith(
                          appearance: _grayGlassAppearance,
                        ),
                        onPressed: () => _showSearchModal(
                          title: 'Cosmétiques',
                          subtitle: 'Rechercher une marque',
                          icon: Icons.soap_rounded,
                          child: const CosmeticsPage(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthSheetContent extends StatefulWidget {
  final VoidCallback onSuccess;

  const _AuthSheetContent({required this.onSuccess});

  @override
  State<_AuthSheetContent> createState() => _AuthSheetContentState();
}

class _AuthSheetContentState extends State<_AuthSheetContent> {
  bool _showRegister = true;

  @override
  Widget build(BuildContext context) {
    if (_showRegister) {
      return RegisterForm(
        onRegisterSuccess: widget.onSuccess,
        onSwitchToLogin: () => setState(() => _showRegister = false),
      );
    } else {
      return LoginForm(
        onLoginSuccess: widget.onSuccess,
        onSwitchToRegister: () => setState(() => _showRegister = true),
      );
    }
  }
}
