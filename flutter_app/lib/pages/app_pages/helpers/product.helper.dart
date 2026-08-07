import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'package:vegan_app/services/api_service.dart';
import 'package:vegan_app/services/auth_service.dart';
import 'package:vegan_app/services/badge_service.dart';
import '../../../models/vegan_status.dart';

class ProductHelper {
  static Future<bool> _checkConnectivityAndShowSnackbar(
      BuildContext context) async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (!context.mounted) return false;
      _showSnackbar(
        context,
        'Pas de connexion internet. Veuillez réessayer plus tard.',
        Colors.orange,
      );
      return false;
    }
    return true;
  }

  static void _showSnackbar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  static Future<bool> tryAddDocument(
    BuildContext context,
    String ean,
    VeganStatus? veganStatus, {
    String productName = '',
    String brand = '',
    File? photo,
  }) async {
    if (!await _checkConnectivityAndShowSnackbar(context)) return false;
    try {
      final productId = await ApiService.postProduct(
        ean: ean,
        status:
            veganStatus?.toApiString() ?? VeganStatus.maybeVegan.toApiString(),
        productName: productName,
        brand: brand,
      );

      if (productId != null) {
        // Upload photo if provided and we got a real product ID
        if (photo != null && productId > 0) {
          await ApiService.uploadProductImage(
            productId: productId,
            photo: photo,
          );
        }

        await PreferencesHelper.addCodeToPreferences(ean, true);
        await PreferencesHelper.saveSubmittedProductInfo(
          code: ean,
          name: productName,
          brand: brand,
        );

        if (!context.mounted) return false;
        _showSnackbar(
          context,
          'Le produit a bien été envoyé. Nous allons vérifier et l\'ajouter à la base de données.',
          Colors.green,
        );

        // Check for newly unlocked badges after sending a product
        if (AuthService.isLoggedIn && context.mounted) {
          final userResult = await AuthService.getCurrentUser();
          if (userResult.isSuccess &&
              userResult.data != null &&
              context.mounted) {
            await BadgeService.checkAndShowNewBadges(
              context,
              userResult.data!,
              mounted: context.mounted,
            );
          }
        }

        return true;
      } else {
        if (!context.mounted) return false;
        _showSnackbar(
          context,
          'Une erreur est survenue lors de l\'ajout du produit. Veuillez réessayer.',
          Colors.red,
        );
        return false;
      }
    } catch (e) {
      if (!context.mounted) return false;
      _showSnackbar(
        context,
        'Une erreur est survenue lors de l\'ajout du produit. Veuillez réessayer.',
        Colors.red,
      );
      return false;
    }
  }

  static Future<bool> tryAddError(
      BuildContext context, String code, String message,
      {String contact = ''}) async {
    if (!await _checkConnectivityAndShowSnackbar(context)) return false;
    try {
      final success = await ApiService.postErrorReport(
        ean: code,
        comment: message,
        contact: contact,
      );

      // Check for newly unlocked badges after reporting an error
      if (success && AuthService.isLoggedIn && context.mounted) {
        final userResult = await AuthService.getCurrentUser();
        if (userResult.isSuccess &&
            userResult.data != null &&
            context.mounted) {
          await BadgeService.checkAndShowNewBadges(
            context,
            userResult.data!,
            mounted: context.mounted,
          );
        }
      }

      return success;
    } catch (e) {
      return false;
    }
  }
}
