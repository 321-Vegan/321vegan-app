import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
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

  /// How long an unverified receipt keeps granting premium access.
  /// Past this, access waits for successful backend verification.
  static const Duration _pendingReceiptGrace = Duration(hours: 48);

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
    if (!_isAvailable) return;

    final response =
        await InAppPurchase.instance.queryProductDetails(_productIds);

    if (response.error != null) {
      debugPrint('Error querying products: ${response.error}');
      return;
    }

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not found: ${response.notFoundIDs.join(', ')}');
    }

    _products = response.productDetails;
  }

  /// Get a product by its ID
  static ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
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
    final decoded = <Map<String, dynamic>>[];
    for (final receipt in receipts) {
      try {
        decoded.add(jsonDecode(receipt) as Map<String, dynamic>);
      } catch (_) {
        // Skip corrupt entries rather than failing the whole list.
      }
    }
    return decoded;
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

    // Only receipts still within the grace period grant access while
    // verification is pending; older ones are just retried.
    _hasPendingReceipt = _hasReceiptWithinGrace(pending);

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
    _hasPendingReceipt = _hasReceiptWithinGrace(await _getPendingReceipts());
    _cachedStatus = prefs.getString(_statusKey);
    final expiresAtStr = prefs.getString(_expiresAtKey);
    _cachedExpiresAt =
        expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;
  }

  /// Whether any persisted receipt is still within the grace period.
  /// Receipts with a missing or unparsable timestamp don't grant access.
  static bool _hasReceiptWithinGrace(List<Map<String, dynamic>> receipts) {
    final now = DateTime.now();
    return receipts.any((receipt) {
      final timestamp = DateTime.tryParse(receipt['timestamp'] ?? '');
      return timestamp != null &&
          now.difference(timestamp) < _pendingReceiptGrace;
    });
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
