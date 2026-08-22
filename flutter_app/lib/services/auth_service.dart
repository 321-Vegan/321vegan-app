import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/auth.dart';
import '../models/user.dart';
import '../models/scanned_product.dart';
import '../helpers/preference_helper.dart';
import '../themes/app_colors.dart';
import 'b12_sync_service.dart';
import 'dio_client.dart';
import 'scan_count_sync_service.dart';
import 'subscription_service.dart';

class AuthService {
  static Map<String, String> get _headersWithApiKey => {
        'Content-Type': 'application/json',
        'x-api-key': dotenv.env['API_KEY'] ?? '',
      };

  static String? _accessToken;
  static User? _currentUser;
  static DateTime? _tokenExpiresAt;

  /// Expose access token for Dio interceptor and ApiService
  static String? get accessToken => _accessToken;

  /// Called by DioClient interceptor after a successful token refresh
  static Future<void> updateTokenFromInterceptor(String newToken,
      {int expiresInSeconds = 1800}) async {
    await _storeToken(newToken, expiresInSeconds: expiresInSeconds);
  }

  /// Called by DioClient interceptor when refresh fails with 401
  static Future<void> clearTokenFromInterceptor() async {
    await _clearToken();
  }

  static Future<void> init() async {
    await _loadStoredToken();
    if (isLoggedIn) {
      // Run network calls in background — don't block app startup.
      unawaited(_checkAndRefreshToken());
      // Scan-count and B12 syncs run after the profile fetch: they need
      // currentUser.
      unawaited(_syncUserDataToPreferences().then((_) {
        unawaited(ScanCountSyncService.sync());
        unawaited(B12SyncService.sync());
      }));
    }
  }

  static Future<void> _loadStoredToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      final expiresAtString = prefs.getString('token_expires_at');
      if (expiresAtString != null) {
        _tokenExpiresAt = DateTime.parse(expiresAtString);
      }
    } catch (e) {
      debugPrint('Error loading stored token: $e');
    }
  }

  static Future<void> _storeToken(String token,
      {int expiresInSeconds = 1800}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      _accessToken = token;

      _tokenExpiresAt = DateTime.now().add(Duration(seconds: expiresInSeconds));
      await prefs.setString(
          'token_expires_at', _tokenExpiresAt!.toIso8601String());
    } catch (e) {
      debugPrint('Error storing token: $e');
    }
  }

  static Future<void> _clearToken() async {
    try {
      _tokenExpiresAt = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('token_expires_at');
      await PreferencesHelper.clearPendingEmailChange();
      _accessToken = null;
      _currentUser = null;
    } catch (e) {
      debugPrint('Error clearing token: $e');
    }
  }

  static Future<void> _checkAndRefreshToken() async {
    if (_tokenExpiresAt == null) return;

    final now = DateTime.now();
    final minutesUntilExpiry = _tokenExpiresAt!.difference(now).inMinutes;

    if (minutesUntilExpiry < 5) {
      final result = await refreshToken();
      if (result.isSuccess) {
        debugPrint('✅ Token refreshed on app launch');
      } else {
        debugPrint('❌ Failed to refresh token on app launch');
      }
    } else {
      debugPrint('Token still valid ($minutesUntilExpiry minutes remaining)');
    }
  }

  static Future<void> _syncUserDataToPreferences() async {
    try {
      final userResult = await getCurrentUser();
      if (userResult.isSuccess) {
        if (userResult.data?.veganSince != null) {
          // Use internal method to avoid calling backend again
          await PreferencesHelper.saveSelectedDateToPrefsOnly(
            userResult.data!.veganSince,
          );
        } else {
          // Backend has null, so clear local storage
          await PreferencesHelper.saveSelectedDateToPrefsOnly(null);
        }
      } else {}
    } catch (e) {
      // Don't throw - this is not critical for login
    }
  }

  static bool get isLoggedIn => _accessToken != null;

  static User? get currentUser => _currentUser;

  // Optimistically add/update a scanned product locally (before backend confirms)
  static void addScannedProductLocally(String ean) {
    final user = _currentUser;
    if (user == null) return;
    final list = user.scannedProducts;
    if (list == null) return;
    final index = list.indexWhere((sp) => sp.ean == ean);
    if (index >= 0) {
      list[index] = ScannedProduct(ean: ean, scanCount: list[index].scanCount + 1);
    } else {
      list.add(ScannedProduct(ean: ean, scanCount: 1));
    }
  }

  static Future<AuthResult<AuthToken>> login(LoginRequest request) async {
    try {
      final dio = await DioClient.getDio();

      final response = await dio.post(
        '/auth/login',
        data: FormData.fromMap({
          'username': request.email,
          'password': request.password,
        }),
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200) {
        final token = AuthToken.fromJson(response.data);
        await _storeToken(token.accessToken);

        await _syncUserDataToPreferences();
        await SubscriptionService.checkSubscriptionStatus();

        // Seed/flush the server-side scan counter now that the user is known
        // (first login seeds it from the local scan total).
        unawaited(ScanCountSyncService.sync());
        // Same for B12 intakes (first sync seeds the local intake history).
        unawaited(B12SyncService.sync());

        return AuthResult.success(token);
      } else {
        return AuthResult.error('Mot de passe ou email incorrect');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        return AuthResult.error('Mot de passe ou email incorrect');
      }
      return AuthResult.error('Erreur réseau lors de la connexion');
    } catch (e) {
      return AuthResult.error('Erreur réseau lors de la connexion');
    }
  }

  static Future<AuthResult<String>> register(RegisterRequest request) async {
    try {
      final dio = await DioClient.getDio();

      final response = await dio.post(
        '/users/',
        data: request.toJson(),
        options: Options(
          headers: _headersWithApiKey,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      return _handleRegistrationResponse(response);
    } on DioException catch (e) {
      if (e.response != null) {
        return _handleRegistrationResponse(e.response!);
      }
      return AuthResult.error('Network error during registration');
    } catch (e) {
      return AuthResult.error('Network error during registration');
    }
  }

  static AuthResult<String> _handleRegistrationResponse(Response response) {
    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      return AuthResult.success('Votre compte a bien été créé !');
    } else if (response.statusCode == 403) {
      return AuthResult.error(
          'L\'inscription n\'est actuellement pas disponible. Veuillez contacter un administrateur.');
    } else if (response.statusCode == 409) {
      return AuthResult.error(
          'Un utilisateur avec cet email existe déjà.');
    } else {
      try {
        final error = response.data;
        if (error is Map && error['detail'] != null) {
          return AuthResult.error(error['detail']);
        }
        return AuthResult.error('Registration failed (${response.statusCode})');
      } catch (jsonError) {
        debugPrint('Error parsing registration error: $jsonError');
        return AuthResult.error('Registration failed (${response.statusCode})');
      }
    }
  }

  // Kept for manual refresh if needed; automatic refresh is now handled by
  // the Dio interceptor.
  static Future<AuthResult<AuthToken>> refreshToken() async {
    try {
      final dio = await DioClient.getDio();

      // The refresh_token cookie is automatically sent by dio_cookie_manager
      final response = await dio.post('/auth/refresh');

      if (response.statusCode == 200) {
        final token = AuthToken.fromJson(response.data);
        await _storeToken(token.accessToken);
        return AuthResult.success(token);
      } else if (response.statusCode == 401) {
        // Only clear tokens on authentication errors
        await _clearToken();
        await DioClient.clearCookies();
        return AuthResult.error('AUTH_EXPIRED');
      } else {
        // Other errors (5xx, etc.) shouldn't log user out
        return AuthResult.error('Token refresh failed');
      }
    } on DioException catch (e) {
      // Only clear tokens on 401 authentication errors
      if (e.response?.statusCode == 401) {
        await _clearToken();
        await DioClient.clearCookies();
        return AuthResult.error('AUTH_EXPIRED');
      }

      // Network errors (server down, timeout, no internet) should not log user out
      return AuthResult.error('NETWORK_ERROR');
    } catch (e) {
      // Unexpected errors should not log user out
      return AuthResult.error('NETWORK_ERROR');
    }
  }

  static Future<AuthResult<String>> logout() async {
    // Last chance to push queued scan-count/B12 data for this account;
    // whatever couldn't be sent is dropped below so it can't be attributed
    // to another account logging in later on this device.
    await Future.wait([
      ScanCountSyncService.sync(),
      B12SyncService.sync(),
    ]);
    await Future.wait([
      ScanCountSyncService.clearUnsynced(),
      B12SyncService.clearPending(),
    ]);

    try {
      final dio = await DioClient.getDio();

      await dio.get(
        '/auth/logout',
        options: Options(
          headers: {'Authorization': 'Bearer $_accessToken'},
        ),
      );

      await _clearToken();
      await DioClient.clearCookies();

      return AuthResult.success('Logged out successfully');
    } catch (e) {
      debugPrint('❌ Logout error: $e');
      await _clearToken();
      await DioClient.clearCookies();
      return AuthResult.success('Logged out locally');
    }
  }

  static Future<AuthResult<String>> deleteAccount(
      BuildContext context, currentUser) async {
    final confirmed = await _showDeleteConfirmationDialog(context);
    if (!confirmed) {
      return AuthResult.error('Annulation de la suppression du compte');
    }
    // Same as logout: queued data must not outlive the account, or it would
    // be attributed to the next account logging in on this device.
    await Future.wait([
      ScanCountSyncService.clearUnsynced(),
      B12SyncService.clearPending(),
    ]);
    try {
      final dio = await DioClient.getDio();

      await dio.delete(
        '/users/${currentUser.id}',
        options: Options(
          headers: {'Authorization': 'Bearer $_accessToken'},
          validateStatus: (status) => status! < 500,
        ),
      );

      await _clearToken();
      await DioClient.clearCookies();
      return AuthResult.success('Compte supprimé avec succès.');
    } on DioException catch (e) {
      debugPrint('❌ Account deletion error: ${e.message}');
      await _clearToken();
      await DioClient.clearCookies();
      return AuthResult.error('Erreur lors de la suppression du compte');
    } catch (e) {
      debugPrint('❌ Unexpected deletion error: $e');
      await _clearToken();
      await DioClient.clearCookies();
      return AuthResult.error('Erreur réseau lors de la suppression du compte');
    }
  }

  static Future<bool> _showDeleteConfirmationDialog(
      BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Confirmer la suppression'),
              content: const Text(
                  'Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Annuler'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: kSemanticError),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Supprimer'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  static Future<AuthResult<String>> requestPasswordReset(
      PasswordResetRequest request) async {
    try {
      final dio = await DioClient.getDio();

      final response = await dio.post(
        '/auth/password-reset/request',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return AuthResult.success(data['detail'] ?? 'Reset email sent');
      } else {
        final error = response.data;
        return AuthResult.error(error['detail'] ?? 'Reset request failed');
      }
    } on DioException catch (e) {
      debugPrint('❌ Password reset request error: ${e.message}');
      if (e.response?.data != null && e.response!.data['detail'] != null) {
        return AuthResult.error(e.response!.data['detail']);
      }
      return AuthResult.error('Network error during password reset request');
    } catch (e) {
      debugPrint('❌ Unexpected password reset error: $e');
      return AuthResult.error('Network error during password reset request');
    }
  }

  static Future<AuthResult<String>> confirmPasswordReset(
      PasswordResetConfirm request) async {
    try {
      final dio = await DioClient.getDio();

      final response = await dio.post(
        '/auth/password-reset/confirm',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return AuthResult.success(
            data['detail'] ?? 'Password reset successful');
      } else {
        final error = response.data;
        return AuthResult.error(error['detail'] ?? 'Password reset failed');
      }
    } on DioException catch (e) {
      debugPrint('❌ Password reset confirmation error: ${e.message}');
      if (e.response?.data != null && e.response!.data['detail'] != null) {
        return AuthResult.error(e.response!.data['detail']);
      }
      return AuthResult.error('Network error during password reset');
    } catch (e) {
      debugPrint('❌ Unexpected password reset error: $e');
      return AuthResult.error('Network error during password reset');
    }
  }

  static Future<AuthResult<String>> verifyResetToken(
      PasswordResetTokenVerify request) async {
    try {
      final dio = await DioClient.getDio();

      final response = await dio.post(
        '/auth/password-reset/verify-token',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return AuthResult.success(data['email'] ?? 'Token is valid');
      } else {
        final error = response.data;
        return AuthResult.error(error['detail'] ?? 'Invalid token');
      }
    } on DioException catch (e) {
      debugPrint('❌ Token verification error: ${e.message}');
      if (e.response?.data != null && e.response!.data['detail'] != null) {
        return AuthResult.error(e.response!.data['detail']);
      }
      return AuthResult.error('Network error during token verification');
    } catch (e) {
      debugPrint('❌ Unexpected token verification error: $e');
      return AuthResult.error('Network error during token verification');
    }
  }

  static Future<AuthResult<User>> getCurrentUser() async {
    try {
      final dio = await DioClient.getDio();

      final response = await dio.get(
        '/auth/me',
        options: Options(
          headers: {'Authorization': 'Bearer $_accessToken'},
        ),
      );

      if (response.statusCode == 200) {
        _currentUser = User.fromJson(response.data);
        await SubscriptionService.updateBypass(_currentUser!.subscriptionBypass);
        return AuthResult.success(_currentUser!);
      } else {
        return AuthResult.error('Failed to get user info');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Interceptor already clears tokens on a failed refresh; only clear
        // here if it hasn't (i.e. _accessToken is still set).
        if (_accessToken != null) {
          debugPrint('❌ Authentication expired');
          await _clearToken();
          await DioClient.clearCookies();
        }
        return AuthResult.error('AUTH_EXPIRED');
      }

      // Network errors (server down, no internet, timeout) should not log user out
      debugPrint('⚠️ Temporary network error getting user info: ${e.message}');
      return AuthResult.error('NETWORK_ERROR');
    } catch (e) {
      debugPrint('❌ Unexpected get user error: $e');
      return AuthResult.error('NETWORK_ERROR');
    }
  }

  // Update the current user's profile (PUT /me/, authenticated with the
  // user's JWT; email changes go through requestEmailChange instead).
  static Future<AuthResult<User>> updateUser({
    DateTime? veganSince,
    bool clearVeganSince = false,
    String? nickname,
    String? avatar,
  }) async {
    try {
      final dio = await DioClient.getDio();
      final Map<String, dynamic> updates = {};

      if (veganSince != null) {
        updates['vegan_since'] = veganSince.toIso8601String();
      } else if (clearVeganSince) {
        updates['vegan_since'] = null;
      }
      if (nickname != null) {
        updates['nickname'] = nickname;
      }
      if (avatar != null) {
        updates['avatar'] = avatar;
      }

      final response = await dio.put(
        '/me/',
        data: updates,
        options: Options(
          headers: {'Authorization': 'Bearer $_accessToken'},
        ),
      );

      if (response.statusCode == 200) {
        _currentUser = User.fromJson(response.data);
        return AuthResult.success(_currentUser!);
      } else {
        return AuthResult.error('Impossible de mettre à jour le profil');
      }
    } on DioException catch (e) {
      debugPrint('❌ Update user error: ${e.message}');
      return AuthResult.error('Impossible de mettre à jour le profil');
    } catch (e) {
      debugPrint('❌ Unexpected update user error: $e');
      return AuthResult.error('Impossible de contacter le serveur');
    }
  }

  // Request an email change. The backend stores the new email as pending and
  // sends a confirmation link to the new address; the email only changes once
  // the user confirms via that link (handled on the web app).
  static Future<AuthResult<String>> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    try {
      final dio = await DioClient.getDio();

      // Accept 4xx without throwing so a wrong-password 401 here doesn't
      // hit the global interceptor and get treated as token expiry.
      final response = await dio.patch(
        '/me/email',
        data: {
          'new_email': newEmail,
          'current_password': currentPassword,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $_accessToken'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      switch (response.statusCode) {
        case 200:
          return AuthResult.success(
              'Un email de confirmation a été envoyé à votre nouvelle adresse. '
              'Cliquez sur le lien qu\'il contient pour finaliser le changement.');
        case 401:
          return AuthResult.error('Mot de passe incorrect');
        case 409:
          return AuthResult.error('Cette adresse email est déjà utilisée');
        default:
          return AuthResult.error(
              'Une erreur est survenue. Veuillez réessayer.');
      }
    } on DioException catch (e) {
      debugPrint('❌ Email change request error: ${e.message}');
      return AuthResult.error('Une erreur est survenue. Veuillez réessayer.');
    } catch (e) {
      debugPrint('❌ Unexpected email change error: $e');
      return AuthResult.error('Une erreur est survenue. Veuillez réessayer.');
    }
  }

  // Change the current user's password while logged in — verified against
  // the current password server-side (unlike updateUser's PUT /me/, which
  // accepts a bare new password with no such check).
  static Future<AuthResult<String>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final dio = await DioClient.getDio();

      final response = await dio.patch(
        '/me/password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $_accessToken'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      switch (response.statusCode) {
        case 200:
          return AuthResult.success('Mot de passe mis à jour avec succès.');
        case 401:
          return AuthResult.error('Mot de passe actuel incorrect');
        case 400:
          return AuthResult.error(
              'Le nouveau mot de passe ne respecte pas les critères de sécurité.');
        default:
          return AuthResult.error(
              'Une erreur est survenue. Veuillez réessayer.');
      }
    } on DioException catch (e) {
      debugPrint('❌ Password change error: ${e.message}');
      return AuthResult.error('Une erreur est survenue. Veuillez réessayer.');
    } catch (e) {
      debugPrint('❌ Unexpected password change error: $e');
      return AuthResult.error('Une erreur est survenue. Veuillez réessayer.');
    }
  }
}

// Generic result class for auth operations
class AuthResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  AuthResult._({this.data, this.error, required this.isSuccess});

  factory AuthResult.success(T data) {
    return AuthResult._(data: data, isSuccess: true);
  }

  factory AuthResult.error(String error) {
    return AuthResult._(error: error, isSuccess: false);
  }
}
