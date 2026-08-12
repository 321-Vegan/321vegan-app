import 'dart:async';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vegan_app/helpers/barcode_helper.dart';
import 'package:vegan_app/helpers/haptic_helper.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/pages/app_pages/Scan/scan_history_page.dart';
import 'package:vegan_app/pages/app_pages/Scan/product_info_helper.dart';
import 'package:vegan_app/pages/app_pages/Scan/product_search_page.dart';
import 'package:vegan_app/models/product_of_interest.dart';
import 'package:vegan_app/models/scan_result.dart';
import 'package:vegan_app/services/auth_service.dart';
import 'package:vegan_app/services/offline_scan_service.dart';
import 'package:vegan_app/services/open_food_facts_service.dart';
import 'package:vegan_app/services/scan_count_sync_service.dart';
import 'package:vegan_app/services/products_of_interest_cache.dart';
import 'package:vegan_app/widgets/scaner/card_product.dart';
import 'package:vegan_app/widgets/scaner/pending_product_info_card.dart';
import 'package:vegan_app/widgets/scaner/info_dialog_button.dart';
import 'package:vegan_app/models/seasonal_theme.dart';
import 'package:vegan_app/themes/app_colors.dart';
import 'package:vegan_app/themes/app_shapes.dart';
import 'package:vegan_app/widgets/scaner/vegan_product_info_card.dart';
import 'package:vegan_app/widgets/scaner/shop_confirmation_modal.dart';
import 'package:vegan_app/widgets/vegandex/vegandex_modal.dart';
import 'package:vegan_app/widgets/vegandex/product_found_modal.dart';
import 'package:vegan_app/widgets/auth/register_form.dart';
import 'package:vegan_app/widgets/auth/login_form.dart';
import 'package:vegan_app/services/subscription_service.dart';
import 'package:vegan_app/widgets/scaner/product_scores_section.dart';
import 'package:vegan_app/pages/app_pages/Scan/account_prompt_dialog.dart';
import 'package:vegan_app/pages/app_pages/Profile/subscription_page.dart';

class ScanPage extends StatefulWidget {
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onLoginSuccess;

  const ScanPage({super.key, this.onNavigateToProfile, this.onLoginSuccess});

  @override
  ScanPageState createState() => ScanPageState();
}

class ScanPageState extends State<ScanPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
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
  bool _showBoycott = true;
  bool _showScores = true;
  bool _hapticFeedback = true;
  List<String> _productsOfInterest = [];
  Map<String, ProductOfInterest> _productsOfInterestMap = {};
  Map<String, String> _alternativeEanToMainEan = {};
  bool _scannerPausedByModal = false;
  bool _isRetrying = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // The Vegandex button used to show its label for a few seconds on page
  // entry, then collapse to an icon-only square to match the history
  // button. Disabled — the shrink animation didn't read well — but kept
  // here in case we want it back. Toggling this on also requires
  // uncommenting the timer in initState/dispose and the AnimatedCrossFade
  // in _buildVegandexButton below.
  // bool _vegandexExpanded = true;
  // Timer? _vegandexCollapseTimer;

  /// Drives a quick decaying shake + pop on the Vegandex button, played the
  /// instant [ProductFoundModal]'s fly-in animation lands on it.
  late final AnimationController _vegandexShakeController;

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
    _vegandexShakeController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );

    _loadScanHistory();
    _loadShowBoycottPref();
    _loadShowScoresPref();
    _loadHapticFeedbackPref();
    // Load products from already-populated cache (populated at app startup)
    _loadProductsOfInterest();

    // _vegandexCollapseTimer = Timer(const Duration(milliseconds: 900), () {
    //   if (mounted) setState(() => _vegandexExpanded = false);
    // });

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
          onArrival: _shakeVegandexButton,
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

  /// Stops the scanner, pushes the scan history page, and restarts the
  /// scanner when it's popped — it's a full page now, not a bottom sheet.
  void _openScanHistory() {
    controller.stop();
    setState(() {
      productInfo = null;
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanHistoryPage(scanHistory: scanHistory),
      ),
    ).then((_) {
      controller.start();
    });
  }

  /// Stops the scanner, pushes the unified product search page (Additifs /
  /// Cosmétiques / Code-barre), and restarts the scanner when it's popped.
  /// The "Code-barre" tab pops with the chosen barcode instead of showing
  /// its own result — feeding it into [_simulateScan] here runs it through
  /// the exact same pipeline as a camera scan (history, haptics, Vegandex
  /// detection, ...) instead of duplicating that logic in the search page.
  void _openProductSearch() {
    controller.stop();
    setState(() {
      productInfo = null;
    });
    Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ProductSearchPage()),
    ).then((barcode) {
      controller.start();
      if (barcode != null && barcode.isNotEmpty) {
        _simulateScan(barcode);
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    // _vegandexCollapseTimer?.cancel();
    controller.dispose();
    _confettiController.dispose();
    _vegandexShakeController.dispose();
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
      // Fetched once now and cached on the history entry, so the history
      // page never has to hit OpenFoodFacts again to show past scans.
      unawaited(_cacheProductScores(barcode));
    }

    if ((product.status == ScanStatus.vegan ||
            product.status == ScanStatus.notVegan) &&
        AuthService.isLoggedIn &&
        !SubscriptionService.isSubscribed) {
      final shouldPrompt =
          await PreferencesHelper.incrementMembershipHitScanCount();
      if (shouldPrompt) {
        _showMembershipPromptAfterDelay();
      }
    }
  }

  Future<void> _showMembershipPromptAfterDelay() async {
    // Small delay so the scan result shows first
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    await PreferencesHelper.snoozeMembershipPrompt();
    if (!mounted) return;

    controller.stop();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SubscriptionPage(
          title: 'Vous scannez souvent,\npassez Premium !',
        ),
      ),
    );
    if (mounted) controller.start();
  }

  Future<void> _cacheProductScores(String barcode) async {
    // Skip the network round-trip if we already fetched this product's
    // scores on an earlier scan.
    final cached = await PreferencesHelper.getCachedScores(barcode);
    final scores = cached ?? await OpenFoodFactsService.fetchScores(barcode);
    await PreferencesHelper.cacheScanScores(barcode, scores);
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
      if (!BarcodeHelper.isValidEAN13(barcodeValue)) {
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
        builder: (context, scrollController) => ClipSmoothRect(
          radius: squircleRadius(28.r),
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

  /// Square top-row button (history, Vegandex). Figma spec: 48×48, radius
  /// 14, white or primary fill, soft shadow — ×3 for ScreenUtil units. Same
  /// height as [_buildTopSearchBar] so the row reads as one line.
  Widget _buildSquareActionButton({
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    Color? background,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 144.w,
        height: 144.w,
        decoration: ShapeDecoration(
          color: background ?? Colors.white,
          shape: squircleBorder(radius: 42.r),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(child: Icon(icon, color: iconColor, size: 72.sp)),
      ),
    );
  }

  /// Vegandex button: icon-only square, same shape as
  /// [_buildSquareActionButton] (144.w, matching the history button next
  /// to it).
  ///
  /// It used to show a "Vegandex" text label next to the icon, expanded on
  /// page entry and collapsing down to this same icon-only square a couple
  /// seconds later via an [AnimatedCrossFade] — disabled (both the label
  /// and its shrink animation) because it didn't read well as UI. See the
  /// commented block below to bring it back (also requires uncommenting
  /// _vegandexExpanded/_vegandexCollapseTimer above).
  Widget _buildVegandexButton() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final icon = Icon(Icons.catching_pokemon, color: Colors.white, size: 72.sp);
    final button = GestureDetector(
      onTap: () => _showModalSheet(VegandexModal(
        onNavigateToProfile: widget.onNavigateToProfile,
      )),
      child: Container(
        width: 144.w,
        height: 144.w,
        decoration: ShapeDecoration(
          color: primaryColor,
          shape: squircleBorder(radius: 12),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(child: icon),
        // child: AnimatedCrossFade(
        //   duration: const Duration(milliseconds: 900),
        //   sizeCurve: Curves.easeInOutCubicEmphasized,
        //   firstCurve: Curves.easeOut,
        //   secondCurve: Curves.easeIn,
        //   crossFadeState: _vegandexExpanded
        //       ? CrossFadeState.showFirst
        //       : CrossFadeState.showSecond,
        //   firstChild: Padding(
        //     padding: EdgeInsets.symmetric(horizontal: 32.w),
        //     child: SizedBox(
        //       height: 144.w,
        //       child: Row(
        //         mainAxisSize: MainAxisSize.min,
        //         mainAxisAlignment: MainAxisAlignment.center,
        //         children: [
        //           Flexible(
        //             child: Text(
        //               'Vegandex',
        //               overflow: TextOverflow.ellipsis,
        //               maxLines: 1,
        //               softWrap: false,
        //               style: TextStyle(
        //                 color: Colors.white,
        //                 fontWeight: FontWeight.bold,
        //                 fontSize: 34.sp,
        //                 fontFamily: 'Balloo2'
        //               ),
        //             ),
        //           ),
        //           SizedBox(width: 16.w),
        //           icon,
        //         ],
        //       ),
        //     ),
        //   ),
        //   secondChild: SizedBox(
        //     width: 144.w,
        //     height: 144.w,
        //     child: Center(child: icon),
        //   ),
        // ),
      ),
    );

    // Quick decaying wiggle + pop, played on impact when
    // ProductFoundModal's fly-in animation lands here (see
    // _shakeVegandexButton).
    return AnimatedBuilder(
      animation: _vegandexShakeController,
      builder: (context, child) {
        final t = _vegandexShakeController.value;
        final dx = sin(t * pi * 6) * (1 - t) * 14.w;
        final scale = 1 + sin(t.clamp(0.0, 1.0) * pi) * 0.16;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: button,
    );
  }

  /// Haptic buzz + [_vegandexShakeController] wiggle, fired the instant a
  /// discovered product's modal finishes flying into the button.
  void _shakeVegandexButton() {
    HapticHelper.impact();
    _vegandexShakeController.forward(from: 0);
  }

  /// Top search bar — tapping it opens [ProductSearchPage] (Additifs /
  /// Cosmétiques for now, Aliment by name/barcode later). Not an editable
  /// field here: [AbsorbPointer] keeps the whole bar a single tap target
  /// instead of focusing the [TextField] in place. Same height/radius as
  /// [_buildSquareActionButton] so the top row reads as one line.
  Widget _buildTopSearchBar() {
    return GestureDetector(
      onTap: _openProductSearch,
      child: AbsorbPointer(
        child: Container(
          height: 144.w,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: squircleBorder(radius: 12),
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(width: 24.w),
              Icon(Icons.search, color: Colors.grey[600], size: 60.sp),
              SizedBox(width: 12.w),
              Expanded(
                child: TextField(
                  textInputAction: TextInputAction.search,
                  style: TextStyle(fontSize: 42.sp),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: "Additif, cosmétique, code-barre...",
                    hintStyle:
                        TextStyle(fontSize: 42.sp, color: Colors.grey[500]),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              SizedBox(width: 24.w),
            ],
          ),
        ),
      ),
    );
  }

  /// Viewfinder reticle shown over the live camera while idle (nothing
  /// scanned yet) — four rounded corner brackets, no text, no card.
  /// [IgnorePointer] keeps it from blocking taps on the camera beneath it.
  Widget _buildScanTargetOverlay() {
    final width = 0.7.sw;
    final height = 0.5.sh;
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, 0.1),
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _ScanTargetPainter(
              color: Colors.white,
              strokeWidth: 6.w,
              cornerLength: 70.w,
              cornerRadius: 48.w,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanWarningBox(String text) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(15.w),
      decoration: ShapeDecoration(
        color: kTextPrimary,
        shape: squircleBorder(
          radius: 12,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        shadows: [
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
            Icons.error_outline,
            color: Colors.white,
            size: 80.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 36.sp,
                color: Colors.white,
                fontWeight: FontWeight.w500,
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
          Positioned.fill(
            child: MobileScanner(
              controller: controller,
              onDetect: (BarcodeCapture capture) {
                _handleBarcode(capture);
              },
            ),
          ),
          // Idle state (nothing scanned yet): just the camera behind a
          // viewfinder reticle — no card, no instructions.
          _buildScanTargetOverlay(),
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
          // Top row: product-name search (visual only for now), history and
          // Vegandex. Figma spec, ×3 for ScreenUtil units — see
          // _buildTopSearchBar/_buildSquareActionButton.
          Positioned(
            top: MediaQuery.of(context).padding.top + 24,
            left: 48.w,
            right: 48.w,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildTopSearchBar()),
                SizedBox(width: 30.w),
                _buildSquareActionButton(
                  icon: Icons.history,
                  iconColor: kTextPrimary,
                  onTap: _openScanHistory,
                ),
                SizedBox(width: 30.w),
                _buildVegandexButton(),
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

/// Paints the four rounded corner brackets of the scan viewfinder reticle.
class _ScanTargetPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;
  final double cornerRadius;

  _ScanTargetPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
    required this.cornerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draws one L-shaped bracket at [origin], with the two arms extending
    // toward the shape's interior along (dx, dy) and rounded off by a
    // quarter-circle corner.
    void drawCorner(Offset origin, double dx, double dy) {
      final path = Path()
        ..moveTo(origin.dx + dx * cornerLength, origin.dy)
        ..lineTo(origin.dx + dx * cornerRadius, origin.dy)
        ..quadraticBezierTo(
          origin.dx,
          origin.dy,
          origin.dx,
          origin.dy + dy * cornerRadius,
        )
        ..lineTo(origin.dx, origin.dy + dy * cornerLength);
      canvas.drawPath(path, paint);
    }

    drawCorner(Offset.zero, 1, 1);
    drawCorner(Offset(size.width, 0), -1, 1);
    drawCorner(Offset(0, size.height), 1, -1);
    drawCorner(Offset(size.width, size.height), -1, -1);
  }

  @override
  bool shouldRepaint(covariant _ScanTargetPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      cornerLength != oldDelegate.cornerLength ||
      cornerRadius != oldDelegate.cornerRadius;
}
