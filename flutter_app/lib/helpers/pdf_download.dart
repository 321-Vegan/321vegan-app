import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../themes/app_colors.dart';
import '../widgets/shared/icon_snack_bar.dart';
import 'image_capture.dart';

/// Native side: MainActivity.kt (Android), AppDelegate.swift (iOS).
const _channel = MethodChannel('app.321vegan/files');

/// Gives [file] (a PDF) to the person without the share sheet:
/// - Android 10+: saved in Téléchargements, with a button to open it;
/// - iOS: opened in a preview (its own button saves it to Fichiers).
/// Elsewhere (Android 9 and before: writing to Téléchargements needs a
/// permission), the share sheet, its iPad popover pointing at
/// [buttonContext]. Throws when it fails.
Future<void> downloadPdf(BuildContext buttonContext, File file) async {
  if (Platform.isIOS) {
    await _channel.invokeMethod<void>('previewFile', {'path': file.path});
    return;
  }
  if (Platform.isAndroid) {
    final uri = await _channel.invokeMethod<String>('saveToDownloads', {
      'path': file.path,
      'name': file.uri.pathSegments.last,
      'mimeType': 'application/pdf',
    });
    if (uri != null) {
      if (buttonContext.mounted) _showSaved(buttonContext, uri);
      return;
    }
  }
  if (!buttonContext.mounted) return;
  await shareFiles(buttonContext, [file], mimeType: 'application/pdf');
}

void _showSaved(BuildContext context, String uri) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(iconSnackBar(
      icon: Icons.download_done,
      message: 'PDF enregistré dans Téléchargements',
      color: kSemanticSuccess,
      actionLabel: 'Ouvrir',
      duration: const Duration(seconds: 6),
      onAction: () async {
        messenger.hideCurrentSnackBar();
        final opened = await _channel.invokeMethod<bool>(
                'openUri', {'uri': uri, 'mimeType': 'application/pdf'}) ??
            false;
        if (!opened) {
          messenger.showSnackBar(const SnackBar(
            content: Text('Aucune application pour ouvrir le PDF.'),
          ));
        }
      },
    ));
}
