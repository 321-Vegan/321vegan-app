import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/pages/app_pages/Scan/history_modal.dart';
import 'package:vegan_app/pages/app_pages/Scan/sent_products_modal.dart';
import 'package:vegan_app/pages/app_pages/Scan/settings_modal.dart';
import 'package:vegan_app/pages/app_pages/Scan/product_info_helper.dart';
import 'package:vegan_app/models/product_of_interest.dart';
import 'package:vegan_app/models/scan_result.dart';
import 'package:vegan_app/services/auth_service.dart';
import 'package:vegan_app/services/offline_scan_service.dart';
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
          final String? shopOsmId = (shopId == null &&
                  nearbyShops != null &&
                  nearbyShops.isNotEmpty)
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
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            void submit() {
              final raw = textController.text.trim();
              if (isValid(raw)) {
                Navigator.of(ctx).pop();
                _simulateScan(raw);
              } else {
                setStateDialog(() => errorText = 'Code-barres invalide (EAN-8 ou EAN-13)');
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
                        child: Icon(Icons.qr_code_2, size: 32, color: Colors.grey.shade700),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Saisir un code-barres',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Si le scan par caméra est impossible,\nsaisissez le code manuellement.',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                        borderSide: const BorderSide(color: Color(0xFF1A722E), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    onChanged: (_) {
                      if (errorText != null) setStateDialog(() => errorText = null);
                    },
                    onSubmitted: (_) => submit(),
                  ),
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
                          child: const Text('Annuler', style: TextStyle(fontSize: 15)),
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
                          child: const Text('Scanner', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
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

      // Reset the button disabled state in NonVeganProductInfoCardState
      nonVeganCardKey.currentState?.resetButton();

      PreferencesHelper.addBarcodeToHistory(barcodeValue.toString()).then((_) {
        // Reload the history after adding the barcode
        _loadScanHistory();
        // Check if we should prompt the user to create an account
        _checkAccountPrompt();
      });

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
      builder: (_) => AccountPromptDialog(onCreateAccount: _showAuthBottomSheet),
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
          // EAN-8 Warning Box at top
          if (productInfo != null &&
              productInfo!.isEan8 &&
              productInfo!.status != ScanStatus.unknown)
            Positioned(
              top: 300.h,
              left: 16,
              right: 16,
              child: Container(
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
                        'Code EAN-8 : Ce code-barres peut correspondre à plusieurs produits différents. Vérifiez bien le nom et la marque.',
                        style: TextStyle(
                          fontSize: 36.sp,
                          color: Colors.orange[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Old receipe non vegan warning box at top
          if (productInfo?.hasNonVeganOldRecipe == true)
            Positioned(
              top: productInfo?.isEan8 == true ? 450.h : 300.h,
              left: 16,
              right: 16,
              child: Container(
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
                        'Ancienne recette non vegan : il se peut qu\'il y ait encore du stock avec l\'ancienne recette. Vérifiez les ingrédients.',
                        style: TextStyle(
                          fontSize: 36.sp,
                          color: Colors.orange[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
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
                  onTap: () {
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
                        child: VegandexModal(
                          onNavigateToProfile: widget.onNavigateToProfile,
                        ),
                      ),
                    ).then((_) {
                      controller.start();
                    });
                  },
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
          // Floating score bar — visible in camera area for vegan products only
          if (productInfo?.status == ScanStatus.vegan)
            Positioned(
              // Non-subscribers get a reserved strip above the badges (free
              // reveal chip); raise the anchor so the badges stay in place.
              top: SubscriptionService.isSubscribed
                  ? 0.35.sh
                  : 0.35.sh - ProductScoresSection.extraHeaderHeight,
              left: 16,
              right: 16,
              child: ProductScoresSection(
                barcode: productInfo!.code,
                isSubscribed: SubscriptionService.isSubscribed,
                enabled: _showScores,
                onDisable: () => _setShowScoresPref(false),
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
          // Add the floating button for scan history
          Positioned(
            top: 200.h,
            left: 170.w,
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: () {
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
                      child: HistoryModal(
                        scanHistory: scanHistory,
                      ),
                    ),
                  ).then((_) {
                    controller.start();
                  });
                },
                child: Icon(
                  Icons.history,
                  color: Colors.black54,
                  size: 80.sp,
                ),
              ),
            ),
          ),
          // Add the floating button for sent products
          Positioned(
            top: 200.h,
            left: 280.w,
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: () {
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
                      child: const SentProductsModal(),
                    ),
                  ).then((_) {
                    controller.start();
                  });
                },
                child: Icon(
                  Icons.switch_access_shortcut_add_outlined,
                  color: Colors.black54,
                  size: 80.sp,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100.h,
            right: 20,
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: _showManualEanDialog,
                child: Icon(
                  Icons.keyboard_outlined,
                  color: Colors.black54,
                  size: 90.sp,
                ),
              ),
            ),
          ),
          // Settings button (positioned last to be on top)
          Positioned(
            top: 200.h,
            left: 60.w,
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: () {
                  _showSettingsModal();
                },
                child: Icon(
                  Icons.settings,
                  color: Colors.black54,
                  size: 80.sp,
                ),
              ),
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
