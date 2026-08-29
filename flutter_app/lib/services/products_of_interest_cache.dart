import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_of_interest.dart';
import 'api_service.dart';

/// Manages caching of products of interest to ensure they're available even offline
class ProductsOfInterestCache {
  static const String _cacheKey = 'products_of_interest_cache';
  static const String _lastUpdateKey = 'products_of_interest_last_update';
  static const Duration _cacheExpiry = Duration(hours: 12);

  /// In-flight background refresh, shared by every caller. Without this,
  /// app startup (initializeAtStartup) and the first screen to load
  /// (scan/vegandex/map, each calling loadProductsOfInterest) race to fire
  /// their own API call before any of them has written back _lastUpdateKey,
  /// so on a weak in-shop connection they'd otherwise compete as several
  /// redundant simultaneous requests instead of one.
  static Future<void>? _pendingRefresh;

  /// Initialize cache at app startup as the user is most likely to have correct internet connexion
  /// Returns immediately (non-blocking) but triggers background update if needed
  static void initializeAtStartup() {
    // Don't await - let it run in background without blocking app startup
    Future(() async {
      final shouldRefresh = await shouldUpdate();
      if (shouldRefresh) {
        await _refreshInBackground();
      }
    });
  }

  /// Load products of interest from cache immediately, then update in background
  /// This ensures instant loading even with poor/no internet
  static Future<List<ProductOfInterest>> loadProductsOfInterest() async {
    try {
      // First, load from cache (instant)
      final cachedProducts = await _loadFromCache();

      // Then, check if we should update (only if cache is old or empty)
      final shouldRefresh = await shouldUpdate();
      if (shouldRefresh) {
        // Update from API in background with timeout
        // This won't block the UI
        unawaited(_refreshInBackground());
      }

      return cachedProducts;
    } catch (e) {
      debugPrint('Failed to load products of interest: $e');
      return [];
    }
  }

  /// Load products from local cache
  static Future<List<ProductOfInterest>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString(_cacheKey);

      if (cachedData == null) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(cachedData);
      return jsonList.map((json) => ProductOfInterest.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Failed to load from cache: $e');
      return [];
    }
  }

  /// Fetches from the API and saves to cache, deduped via [_pendingRefresh]
  /// so concurrent callers share one in-flight request.
  static Future<void> _refreshInBackground() {
    return _pendingRefresh ??= _doRefresh().whenComplete(() {
      _pendingRefresh = null;
    });
  }

  static Future<void> _doRefresh() async {
    try {
      // Add timeout to prevent slow network from blocking
      final products = await ApiService.getInterestingProducts()
          .timeout(const Duration(seconds: 10));

      if (products.isNotEmpty) {
        await _saveToCache(products);
      }
    } catch (e) {
      // Silently fail - we already have cached data
      debugPrint('Background update failed (expected if offline): $e');
    }
  }

  /// Force update from API (useful for manual refresh)
  static Future<List<ProductOfInterest>> forceUpdate() async {
    try {
      final products = await ApiService.getInterestingProducts()
          .timeout(const Duration(seconds: 10));

      if (products.isNotEmpty) {
        await _saveToCache(products);
      }

      return products;
    } catch (e) {
      debugPrint('Force update failed: $e');
      // Return cached data as fallback
      return await _loadFromCache();
    }
  }

  /// Save products to cache
  static Future<void> _saveToCache(List<ProductOfInterest> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert to JSON and save
      final jsonList = products.map((p) => p.toJson()).toList();
      final String jsonString = json.encode(jsonList);

      await prefs.setString(_cacheKey, jsonString);
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Failed to save to cache: $e');
    }
  }

  /// Check if cache needs update (older than 12 hours)
  static Future<bool> shouldUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? lastUpdate = prefs.getInt(_lastUpdateKey);

      if (lastUpdate == null) {
        return true;
      }

      final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
      final now = DateTime.now();

      return now.difference(lastUpdateTime) > _cacheExpiry;
    } catch (e) {
      return true;
    }
  }

  /// Clear cache (useful for testing or logout)
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_lastUpdateKey);
    } catch (e) {
      debugPrint('Failed to clear cache: $e');
    }
  }
}
