import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// The images of the Veganuary content. In its JSON, an image is one of:
/// - an asset of the app ("lib/assets/images/characters/cow-ok.webp"): the
///   app's own illustrations;
/// - a path in the storage bucket ("veganuary/cover-l-amorce.webp"): the
///   course's images, uploaded from the admin tool, not in the repository;
/// - a URL.

bool isVeganuaryAsset(String src) => src.startsWith('lib/');

/// Where to download [src] from; null for an asset of the app.
String? veganuaryImageUrl(String src) {
  if (isVeganuaryAsset(src)) return null;
  if (src.startsWith('http')) return src;
  return '${dotenv.env['S3_STORAGE_URL'] ?? ''}/$src';
}

/// Keeps the course's images on the device for good (not 30 days, nor
/// among the other images of the app): the course can be done offline once
/// downloaded.
final veganuaryImageCache = CacheManager(Config(
  'veganuaryImages',
  stalePeriod: const Duration(days: 365),
  maxNrOfCacheObjects: 1000,
));

ImageProvider veganuaryImageProvider(String src) {
  final url = veganuaryImageUrl(src);
  return url == null
      ? AssetImage(src)
      : CachedNetworkImageProvider(url, cacheManager: veganuaryImageCache);
}

/// The image's bytes (e.g. for a PDF), from the cache when downloaded.
Future<Uint8List> veganuaryImageBytes(String src) async {
  final url = veganuaryImageUrl(src);
  if (url == null) {
    return (await rootBundle.load(src)).buffer.asUint8List();
  }
  return (await veganuaryImageCache.getSingleFile(url)).readAsBytes();
}

/// Every downloadable image of [json] (a week's content).
Iterable<String> veganuaryImagesIn(Object? json) sync* {
  if (json is String) {
    if (!isVeganuaryAsset(json) &&
        RegExp(r'\.(webp|png|jpe?g|gif)$', caseSensitive: false)
            .hasMatch(json)) {
      yield json;
    }
  } else if (json is List) {
    for (final value in json) {
      yield* veganuaryImagesIn(value);
    }
  } else if (json is Map) {
    for (final value in json.values) {
      yield* veganuaryImagesIn(value);
    }
  }
}

/// Downloads the images of [weeks] not on the device yet, one at a time
/// (in the background, after the content): then they show offline too.
Future<void> prefetchVeganuaryImages(List<Object?> weeks) async {
  for (final src in {for (final week in weeks) ...veganuaryImagesIn(week)}) {
    final url = veganuaryImageUrl(src)!;
    try {
      if (await veganuaryImageCache.getFileFromCache(url) != null) continue;
      await veganuaryImageCache.downloadFile(url);
    } catch (_) {
      // Offline or gone: shown (or not) when needed
    }
  }
}
