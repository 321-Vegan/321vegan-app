import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Widgets turned into images to share (a recipe, a Veganuary story...).

/// [key]'s [RepaintBoundary] as a PNG file in the temp dir, named [name].
Future<File?> captureImageFile(GlobalKey key, String name,
    {double pixelRatio = 3}) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;

  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (byteData == null) return null;

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name.png');
  await file.writeAsBytes(byteData.buffer.asUint8List());
  return file;
}

/// Each of [images] (file name → widget) drawn out of the screen, in an
/// overlay, [width] wide, and captured as a PNG file. [precache]: the
/// pictures they show, loaded beforehand so they're in the very first frame
/// drawn; [settle]: a wait before capturing, e.g. for a network photo
/// fading in.
Future<List<File>> captureOffscreen(
  BuildContext context, {
  required Map<String, Widget> images,
  required double width,
  List<ImageProvider> precache = const [],
  Duration settle = Duration.zero,
  double pixelRatio = 3,
}) async {
  await Future.wait([
    for (final provider in precache)
      precacheImage(provider, context, onError: (_, __) {}),
  ]);
  if (!context.mounted) return const [];

  final keys = {for (final name in images.keys) name: GlobalKey()};
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -width * 2,
      top: 0,
      width: width,
      child: IgnorePointer(
        // Right in the overlay, there's no Material above: without one, the
        // texts would come out with a yellow underline (Flutter's warning)
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final MapEntry(:key, :value) in images.entries)
                RepaintBoundary(key: keys[key], child: value),
            ],
          ),
        ),
      ),
    ),
  );
  Overlay.of(context).insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    if (settle > Duration.zero) await Future.delayed(settle);

    final files = <File>[];
    for (final MapEntry(:key, :value) in keys.entries) {
      final file = await captureImageFile(value, key, pixelRatio: pixelRatio);
      if (file != null) files.add(file);
    }
    return files;
  } finally {
    entry.remove();
  }
}

/// The share sheet with images (it can save them to the photos, or post
/// them as an Instagram story), its iPad popover pointing at
/// [buttonContext]. Without [text], only the images are shared (saving a
/// recipe: a text would be saved to the notes alongside).
Future<void> shareImageFiles(
  BuildContext buttonContext,
  List<File> files, {
  String? text,
}) =>
    shareFiles(buttonContext, files, mimeType: 'image/png', text: text);

/// The share sheet with [files] of [mimeType] (e.g. a PDF: saved to Files,
/// sent by email...), its iPad popover pointing at [buttonContext].
Future<void> shareFiles(
  BuildContext buttonContext,
  List<File> files, {
  required String mimeType,
  String? text,
}) async {
  final box = buttonContext.findRenderObject() as RenderBox?;
  await Share.shareXFiles(
    [for (final file in files) XFile(file.path, mimeType: mimeType)],
    text: text,
    sharePositionOrigin:
        box != null ? box.localToGlobal(Offset.zero) & box.size : null,
  );
}
