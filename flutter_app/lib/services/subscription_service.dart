import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription.dart';
import 'api_service.dart';
import 'auth_service.dart';

class SubscriptionService {
  // Tier 0 - Petit soutien
  static const String monthlyId = 'supporter_monthly';
  static const String yearlyId = 'supporter_yearly';

  // Tier 1 - soutien
  static const String tier1MonthlyId = 'supporter_tier1_monthly';
  static const String tier1YearlyId = 'supporter_tier1_yearly';

  // Tier 2 - Grand soutien
  static const String tier2MonthlyId = 'supporter_tier2_monthly';
  static const String tier2YearlyId = 'supporter_tier2_yearly';

  static const Set<String> _productIds = {
    monthlyId,
    yearlyId,
    tier1MonthlyId,
    tier1YearlyId,
    tier2MonthlyId,
    tier2YearlyId,
  };

  static const String _statusKey = 'subscription_status';
  static const String _expiresAtKey = 'subscription_expires_at';
  static const String _productIdKey = 'subscription_product_id';
  static const String _bypassKey = 'subscription_bypass';
  static const String _pendingReceiptsKey = 'pending_receipts';

  static StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  static List<ProductDetails> _products = [];
  static bool _isAvailable = false;
  static Subscription? _currentSubscription;
  static bool _subscriptionBypass = false;
  static bool _hasPendingReceipt = false;
  static Timer? _retryTimer;
  static String? _cachedStatus;
  static DateTime? _cachedExpiresAt;

  /// Callback for UI to react to purchase state changes
  static VoidCallback? onSubscriptionChanged;

  /// Initialize the service and start listening to purchase updates
  static Future<void> init() async {
    _isAvailable = await InAppPurchase.instance.isAvailable();
    debugPrint('### SUBS init: store available=$_isAvailable');
    if (!_isAvailable) {
      debugPrint('In-app purchases not available');
      return;
    }

    // Listen to purchase updates
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (error) => debugPrint('Purchase stream error: $error'),
    );

    // Load cached subscription status
    await _loadCachedStatus();

    // Run network-dependent operations in background — don't block app startup
    unawaited(queryProducts());

    // If logged in, check subscription status from backend
    if (AuthService.isLoggedIn) {
      unawaited(checkSubscriptionStatus());
      unawaited(_retryPendingReceipts());
    }
  }

  /// Whether the store is available
  static bool get isAvailable => _isAvailable;

  /// Available products from the store
  static List<ProductDetails> get products => _products;

  /// Current subscription from backend
  static Subscription? get currentSubscription => _currentSubscription;

  /// Whether the user has an active subscription
  static bool get isSubscribed {
    // Check subscription bypass first
    if (_subscriptionBypass) return true;
    // Then check backend subscription
    if (_currentSubscription != null && _currentSubscription!.isActive) {
      return true;
    }
    // Grant temporary access if we have a pending receipt
    if (_hasPendingReceipt) return true;
    // Fallback to cached status
    return _getCachedIsSubscribed();
  }

  /// Query available products from the store
  static Future<void> queryProducts() async {
    debugPrint('### SUBS queryProducts() called, available=$_isAvailable');
    if (!_isAvailable) return;

    final response =
        await InAppPurchase.instance.queryProductDetails(_productIds);

    if (response.error != null) {
      debugPrint('### SUBS error querying products: ${response.error}');
      return;
    }

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('### SUBS products NOT FOUND: ${response.notFoundIDs.join(', ')}');
    }

    _products = response.productDetails;
    _debugDumpProducts();
  }

  /// TEMPORARY: log every product/offer the store returns, so we can see
  /// whether a free-trial offer is coming back (and under which product id).
  /// Remove once trials are confirmed working.
  static void _debugDumpProducts() {
    debugPrint('=== SUBSCRIPTION PRODUCTS (${_products.length}) ===');
    for (final p in _products) {
      debugPrint('• id=${p.id}  price=${p.price}  rawPrice=${p.rawPrice}');
      if (p is GooglePlayProductDetails) {
        final offers = p.productDetails.subscriptionOfferDetails;
        final idx = p.subscriptionIndex;
        debugPrint('    android offerIndex=$idx  token=${p.offerToken}');
        if (offers != null && idx != null && idx < offers.length) {
          final offer = offers[idx];
          debugPrint(
              '    basePlanId=${offer.basePlanId}  offerId=${offer.offerId}');
          for (final ph in offer.pricingPhases) {
            debugPrint('      phase: period=${ph.billingPeriod} '
                'price=${ph.formattedPrice} micros=${ph.priceAmountMicros} '
                'cycles=${ph.billingCycleCount}');
          }
        }
      } else if (p is AppStoreProductDetails) {
        final intro = p.skProduct.introductoryPrice;
        debugPrint('    ios introductoryPrice=${intro?.paymentMode} '
            'period=${intro?.subscriptionPeriod.numberOfUnits}'
            '${intro?.subscriptionPeriod.unit}');
      }
    }
    debugPrint('=== END PRODUCTS ===');
  }

  /// Get a product by its ID for display — the entry exposing the recurring
  /// price. On Android a product with a free-trial offer is returned as several
  /// [ProductDetails] (one per offer); the trial offer's first pricing phase is
  /// free, so we prefer an entry whose [rawPrice] is the real recurring price.
  static ProductDetails? getProduct(String productId) {
    final matches = _products.where((p) => p.id == productId);
    if (matches.isEmpty) return null;
    for (final p in matches) {
      if (p.rawPrice > 0) return p;
    }
    return matches.first;
  }

  /// The [ProductDetails] to actually purchase for [productId].
  ///
  /// On Android this prefers the offer that includes a free trial — Play only
  /// returns offers the current user is eligible for, so its presence means the
  /// user qualifies, and passing that entry uses the right offer token at
  /// checkout. On iOS StoreKit applies the introductory offer automatically, so
  /// the single product is returned.
  static ProductDetails? getPurchasableProduct(String productId) {
    return _androidTrialProduct(productId) ?? getProduct(productId);
  }

  /// Whether a free trial is available to the current user for [productId].
  static bool hasTrial(String productId) => _trialInfo(productId) != null;

  /// A short French label for the free trial on [productId], e.g.
  /// "7 jours d'essai gratuit", or null if no trial is available.
  static String? getTrialLabel(String productId) {
    final info = _trialInfo(productId);
    if (info == null) return null;
    final (count, unit) = info;
    final word = switch (unit) {
      _TrialUnit.day => count == 1 ? 'jour' : 'jours',
      _TrialUnit.week => count == 1 ? 'semaine' : 'semaines',
      _TrialUnit.month => 'mois',
      _TrialUnit.year => count == 1 ? 'an' : 'ans',
    };
    return "$count $word d'essai gratuit";
  }

  /// Resolve the trial duration for [productId] as (count, unit), or null.
  static (int, _TrialUnit)? _trialInfo(String productId) {
    if (Platform.isIOS) {
      final product = getProduct(productId);
      if (product is AppStoreProductDetails) {
        final intro = product.skProduct.introductoryPrice;
        // Note: the plugin enum is misspelled `freeTrail`.
        if (intro != null &&
            intro.paymentMode == SKProductDiscountPaymentMode.freeTrail) {
          final unit = _skUnit(intro.subscriptionPeriod.unit);
          final count =
              intro.subscriptionPeriod.numberOfUnits * intro.numberOfPeriods;
          if (count > 0) return (count, unit);
        }
      }
      return null;
    }
    if (Platform.isAndroid) {
      final entry = _androidTrialProduct(productId);
      final phase = entry != null ? _googleTrialPhase(entry) : null;
      if (phase != null) {
        final parsed = _parseIso8601Period(phase.billingPeriod);
        if (parsed != null) {
          final (count, unit) = parsed;
          final cycles =
              phase.billingCycleCount > 0 ? phase.billingCycleCount : 1;
          return (count * cycles, unit);
        }
      }
    }
    return null;
  }

  /// The Android [GooglePlayProductDetails] offer carrying a free trial for
  /// [productId], or null (also null on iOS).
  static GooglePlayProductDetails? _androidTrialProduct(String productId) {
    if (!Platform.isAndroid) return null;
    for (final p in _products.where((p) => p.id == productId)) {
      if (p is GooglePlayProductDetails && _googleTrialPhase(p) != null) {
        return p;
      }
    }
    return null;
  }

  /// The free (price == 0) pricing phase of an Android offer, or null.
  static PricingPhaseWrapper? _googleTrialPhase(GooglePlayProductDetails p) {
    final offers = p.productDetails.subscriptionOfferDetails;
    final index = p.subscriptionIndex;
    if (offers == null || index == null || index >= offers.length) return null;
    for (final phase in offers[index].pricingPhases) {
      if (phase.priceAmountMicros == 0) return phase;
    }
    return null;
  }

  static _TrialUnit _skUnit(SKSubscriptionPeriodUnit unit) {
    switch (unit) {
      case SKSubscriptionPeriodUnit.day:
        return _TrialUnit.day;
      case SKSubscriptionPeriodUnit.week:
        return _TrialUnit.week;
      case SKSubscriptionPeriodUnit.month:
        return _TrialUnit.month;
      case SKSubscriptionPeriodUnit.year:
        return _TrialUnit.year;
    }
  }

  /// Parse a single-unit ISO-8601 duration (e.g. "P1W", "P7D", "P1M") into a
  /// (count, unit). Returns the largest non-zero unit. Null if unparseable.
  static (int, _TrialUnit)? _parseIso8601Period(String period) {
    final match = RegExp(r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$')
        .firstMatch(period);
    if (match == null) return null;
    final years = int.tryParse(match.group(1) ?? '') ?? 0;
    final months = int.tryParse(match.group(2) ?? '') ?? 0;
    final weeks = int.tryParse(match.group(3) ?? '') ?? 0;
    final days = int.tryParse(match.group(4) ?? '') ?? 0;
    if (years > 0) return (years, _TrialUnit.year);
    if (months > 0) return (months, _TrialUnit.month);
    if (weeks > 0) return (weeks, _TrialUnit.week);
    if (days > 0) return (days, _TrialUnit.day);
    return null;
  }

  /// Get the display name for a product ID
  static String getProductDisplayName(String productId) {
    if (productId.contains('tier2')) return 'Grand soutien';
    if (productId.contains('tier1')) return 'Soutien';
    // Legacy
    if (productId.contains('yearly')) return 'Annuel';
    if (productId.contains('monthly')) return 'Mensuel';
    return 'Petit soutien';
  }

  /// Initiate a purchase
  static Future<bool> buyProduct(ProductDetails product) async {
    if (!_isAvailable) return false;

    final purchaseParam = PurchaseParam(productDetails: product);
    return InAppPurchase.instance
        .buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Restore previous purchases
  static Future<void> restorePurchases() async {
    if (!_isAvailable) return;
    await InAppPurchase.instance.restorePurchases();
  }

  /// Check subscription status from backend
  static Future<Subscription?> checkSubscriptionStatus() async {
    if (!AuthService.isLoggedIn) return null;

    try {
      final subscription = await ApiService.getSubscriptionStatus();
      if (subscription != null) {
        _currentSubscription = subscription;
        await _cacheStatus(_currentSubscription!);
        onSubscriptionChanged?.call();
        return _currentSubscription;
      } else {
        // No subscription found
        _currentSubscription = null;
        await _clearCachedStatus();
      }
    } catch (e) {
      debugPrint('Error checking subscription: $e');
    }
    return null;
  }

  /// Handle purchase updates from the store
  static Future<void> _handlePurchaseUpdates(
      List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final verified = await _verifyAndDeliverPurchase(purchase);
          // Only complete the purchase after successful backend verification
          if (verified && purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.error:
          debugPrint('Purchase error: ${purchase.error}');
          if (purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.pending:
          debugPrint('Purchase pending...');
          break;
        case PurchaseStatus.canceled:
          debugPrint('Purchase canceled');
          if (purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
          }
          break;
      }
    }
  }

  /// Verify purchase with backend and deliver content.
  /// Returns true if backend verification succeeded.
  static Future<bool> _verifyAndDeliverPurchase(
      PurchaseDetails purchase) async {
    final String platform = Platform.isIOS ? 'apple' : 'google';
    final String? transactionId =
        Platform.isIOS ? purchase.purchaseID : null;
    final String? purchaseToken = Platform.isIOS
        ? null
        : purchase.verificationData.serverVerificationData;

    // Persist receipt locally before sending to backend
    await _savePendingReceipt(
      platform: platform,
      productId: purchase.productID,
      transactionId: transactionId,
      purchaseToken: purchaseToken,
    );
    _hasPendingReceipt = true;
    onSubscriptionChanged?.call();

    if (!AuthService.isLoggedIn) {
      debugPrint('User not logged in, receipt saved for later verification');
      _startRetryTimer();
      return false;
    }

    try {
      final subscription = await ApiService.verifySubscription(
        platform: platform,
        productId: purchase.productID,
        transactionId: transactionId,
        purchaseToken: purchaseToken,
      );

      if (subscription != null) {
        _currentSubscription = subscription;
        await _cacheStatus(_currentSubscription!);
        await _clearPendingReceipts();
        _hasPendingReceipt = false;
        _retryTimer?.cancel();
        onSubscriptionChanged?.call();
        debugPrint('Purchase verified successfully');
        return true;
      }
    } catch (e) {
      debugPrint('Error verifying purchase, will retry later: $e');
    }

    // Backend unavailable — start retry timer
    _startRetryTimer();
    return false;
  }

  // -- Pending receipt persistence --

  static Future<void> _savePendingReceipt({
    required String platform,
    required String productId,
    String? transactionId,
    String? purchaseToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final receipt = {
      'platform': platform,
      'product_id': productId,
      if (transactionId != null) 'transaction_id': transactionId,
      if (purchaseToken != null) 'purchase_token': purchaseToken,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final existing = prefs.getStringList(_pendingReceiptsKey) ?? [];
    existing.add(jsonEncode(receipt));
    await prefs.setStringList(_pendingReceiptsKey, existing);
  }

  static Future<List<Map<String, dynamic>>> _getPendingReceipts() async {
    final prefs = await SharedPreferences.getInstance();
    final receipts = prefs.getStringList(_pendingReceiptsKey) ?? [];
    return receipts
        .map((r) => jsonDecode(r) as Map<String, dynamic>)
        .toList();
  }

  static Future<void> _clearPendingReceipts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingReceiptsKey);
  }

  /// Retry verifying any pending receipts with the backend
  static Future<void> _retryPendingReceipts() async {
    if (!AuthService.isLoggedIn) return;

    final pending = await _getPendingReceipts();
    if (pending.isEmpty) {
      _hasPendingReceipt = false;
      return;
    }

    _hasPendingReceipt = true;

    for (final receipt in pending) {
      try {
        final subscription = await ApiService.verifySubscription(
          platform: receipt['platform'],
          productId: receipt['product_id'],
          transactionId: receipt['transaction_id'],
          purchaseToken: receipt['purchase_token'],
        );

        if (subscription != null) {
          _currentSubscription = subscription;
          await _cacheStatus(_currentSubscription!);
          await _clearPendingReceipts();
          _hasPendingReceipt = false;
          _retryTimer?.cancel();
          onSubscriptionChanged?.call();
          debugPrint('Pending receipt verified successfully');
          return;
        }
      } catch (e) {
        debugPrint('Retry verification failed: $e');
        _startRetryTimer();
        return;
      }
    }
  }

  /// Start a periodic timer to retry pending receipt verification
  static void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _retryPendingReceipts();
    });
  }

  /// Cache subscription status locally
  static Future<void> _cacheStatus(Subscription subscription) async {
    _cachedStatus = subscription.status.name;
    _cachedExpiresAt = subscription.expiresAt;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statusKey, subscription.status.name);
    await prefs.setString(_productIdKey, subscription.productId);
    if (subscription.expiresAt != null) {
      await prefs.setString(
          _expiresAtKey, subscription.expiresAt!.toIso8601String());
    }
  }

  /// Load cached subscription status
  static Future<void> _loadCachedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _subscriptionBypass = prefs.getBool(_bypassKey) ?? false;
    _hasPendingReceipt =
        (prefs.getStringList(_pendingReceiptsKey) ?? []).isNotEmpty;
    _cachedStatus = prefs.getString(_statusKey);
    final expiresAtStr = prefs.getString(_expiresAtKey);
    _cachedExpiresAt =
        expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;
  }

  /// Check cached subscription status
  static bool _getCachedIsSubscribed() {
    if ((_cachedStatus == 'active' || _cachedStatus == 'graceperiod') &&
        _cachedExpiresAt != null) {
      return _cachedExpiresAt!.isAfter(DateTime.now());
    }
    return false;
  }

  /// Update subscription bypass from user data
  static Future<void> updateBypass(bool bypass) async {
    _subscriptionBypass = bypass;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bypassKey, bypass);
    onSubscriptionChanged?.call();
  }

  /// Clear cached status (preserves bypass since it comes from user data, not subscription)
  static Future<void> _clearCachedStatus() async {
    _cachedStatus = null;
    _cachedExpiresAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statusKey);
    await prefs.remove(_expiresAtKey);
    await prefs.remove(_productIdKey);
  }

  /// Dispose the service
  static void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}

/// Duration unit of a free trial period.
enum _TrialUnit { day, week, month, year }
