import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A restaurant creation left unfinished, kept on the device only. [fields]
/// is the form's state as the form writes it (see CreateRestaurantPage);
/// photos are copied into the app's documents, as picked photos live in a
/// temporary folder the system may empty. Photo paths are full paths in
/// memory, but stored as file names: on iOS the documents folder moves with
/// each app update.
class RestaurantDraft {
  final String id;
  final DateTime updatedAt;
  final Map<String, dynamic> fields;
  final List<String> menuPhotos;
  final List<String> placePhotos;
  final String? mainPhoto;

  const RestaurantDraft({
    required this.id,
    required this.updatedAt,
    required this.fields,
    this.menuPhotos = const [],
    this.placePhotos = const [],
    this.mainPhoto,
  });

  /// The name typed so far, if any.
  String? get name {
    final value = (fields['name'] as String?)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get city {
    final value = (fields['city'] as String?)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String _name(String path) => path.split('/').last;

  Map<String, dynamic> toJson() => {
        'id': id,
        'updated_at': updatedAt.toIso8601String(),
        'fields': fields,
        'menu_photos': menuPhotos.map(_name).toList(),
        'place_photos': placePhotos.map(_name).toList(),
        'main_photo': mainPhoto == null ? null : _name(mainPhoto!),
      };

  /// [photosDir]: the folder of this draft's photos, to rebuild their paths.
  factory RestaurantDraft.fromJson(
      Map<String, dynamic> json, String Function(String id) photosDir) {
    final id = json['id'] as String;
    String path(String name) => '${photosDir(id)}/$name';
    final main = json['main_photo'] as String?;
    return RestaurantDraft(
      id: id,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      fields: (json['fields'] as Map?)?.cast<String, dynamic>() ?? {},
      menuPhotos: [
        for (final name in (json['menu_photos'] as List?) ?? []) path(name),
      ],
      placePhotos: [
        for (final name in (json['place_photos'] as List?) ?? []) path(name),
      ],
      mainPhoto: main == null ? null : path(main),
    );
  }
}

/// The drafts saved on this device, newest first.
class RestaurantDrafts {
  RestaurantDrafts._();

  static const _key = 'restaurant_drafts';

  static Future<List<RestaurantDraft>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final root = await _rootDir();
    try {
      final drafts = [
        for (final item in jsonDecode(raw) as List)
          RestaurantDraft.fromJson(
              (item as Map).cast<String, dynamic>(), (id) => '$root/$id'),
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return drafts;
    } catch (_) {
      return [];
    }
  }

  /// Saves the form under [id] (a new draft when null), copying its photos
  /// next to it. Returns the saved draft.
  static Future<RestaurantDraft> save({
    String? id,
    required Map<String, dynamic> fields,
    required List<File> menuPhotos,
    required List<File> placePhotos,
    File? mainPhoto,
  }) async {
    final draftId = id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final dir = await _photosDir(draftId);
    await dir.create(recursive: true);

    Future<String> keep(File photo) async {
      if (photo.path.startsWith(dir.path)) return photo.path;
      final name =
          '${DateTime.now().microsecondsSinceEpoch}_${photo.uri.pathSegments.last}';
      return (await photo.copy('${dir.path}/$name')).path;
    }

    final menu = [for (final photo in menuPhotos) await keep(photo)];
    final place = <String>[];
    String? main;
    for (final photo in placePhotos) {
      final path = await keep(photo);
      place.add(path);
      if (photo.path == mainPhoto?.path) main = path;
    }
    // Photos removed from the form since the last save
    for (final file in dir.listSync().whereType<File>()) {
      if (!menu.contains(file.path) && !place.contains(file.path)) {
        await file.delete();
      }
    }

    final draft = RestaurantDraft(
      id: draftId,
      updatedAt: DateTime.now(),
      fields: fields,
      menuPhotos: menu,
      placePhotos: place,
      mainPhoto: main,
    );
    final drafts = (await all()).where((d) => d.id != draftId).toList()
      ..insert(0, draft);
    await _write(drafts);
    return draft;
  }

  /// Removes the draft and its photos.
  static Future<void> delete(String id) async {
    final drafts = (await all()).where((d) => d.id != id).toList();
    await _write(drafts);
    final dir = await _photosDir(id);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  static Future<void> _write(List<RestaurantDraft> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode([for (final d in drafts) d.toJson()]));
  }

  static Future<String> _rootDir() async =>
      '${(await getApplicationDocumentsDirectory()).path}/restaurant_drafts';

  static Future<Directory> _photosDir(String id) async =>
      Directory('${await _rootDir()}/$id');
}
