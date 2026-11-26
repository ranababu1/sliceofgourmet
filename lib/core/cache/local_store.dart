import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';

/// Local cache built on Hive. The app keeps the whole recipe catalog on the
/// device and only syncs what changed, so screens never wait on the network.
///
/// Boxes:
/// - posts: `card_<id>` list item json, `post_<id>` full recipe json, both in
///   the sog/v1 server shape
/// - lists: ordered id lists (`catalog_ids`, `trending_ids`)
/// - meta: schema, sync times, ETags, categories json
class LocalStore {
  static late Box _posts;
  static late Box _lists;
  static late Box _meta;

  /// Bump when the cached json shape changes. v1 held parsed WPRM/HTML
  /// recipes, v2 per-page sog/v1 lists, v3 the full local catalog.
  static const int schemaVersion = 3;

  /// [inMemory] keeps everything in RAM (widget tests).
  static Future<void> init({bool inMemory = false}) async {
    Future<Box> open(String name) => inMemory
        ? Hive.openBox(name, bytes: Uint8List(0))
        : Hive.openBox(name);
    _posts = await open('posts');
    _lists = await open('lists');
    _meta = await open('meta');
    await _migrate();
  }

  /// Drops caches written by older app versions. They are only a cache and
  /// are refilled from the network by the next sync.
  static Future<void> _migrate() async {
    if (_meta.get('schema') == schemaVersion) return;
    await _posts.clear();
    await _lists.clear();
    await _meta.clear();
    await _meta.put('schema', schemaVersion);
  }

  static LocalStore get instance => LocalStore();

  /// Wipes everything (tests and "clear cache").
  Future<void> clear() async {
    await _posts.clear();
    await _lists.clear();
    await _meta.clear();
    await _meta.put('schema', schemaVersion);
  }

  Map<String, dynamic>? _read(String key) {
    try {
      final raw = _posts.get(key);
      if (raw is String) {
        return Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (_) {
      // corrupt entry, treat as a miss
    }
    return null;
  }

  // full recipes
  Map<String, dynamic>? readPost(String id) => _read('post_$id');

  Future<void> writePost(String id, Map<String, dynamic> json) =>
      _posts.put('post_$id', jsonEncode(json));

  Future<void> deletePost(String id) => _posts.delete('post_$id');

  // list cards
  Map<String, dynamic>? readCard(String id) => _read('card_$id');

  Future<void> writeCard(String id, Map<String, dynamic> json) =>
      _posts.put('card_$id', jsonEncode(json));

  Future<void> writeCards(Map<String, Map<String, dynamic>> cards) =>
      _posts.putAll(cards.map((id, j) => MapEntry('card_$id', jsonEncode(j))));

  Future<void> deleteRecipe(String id) async {
    await _posts.delete('post_$id');
    await _posts.delete('card_$id');
    final ids = catalogIds;
    if (ids != null && ids.contains(id)) {
      await setCatalogIds(ids.where((e) => e != id).toList());
    }
  }

  // id lists
  List<String>? readIdList(String key) {
    final raw = _lists.get(key);
    if (raw is List) return raw.map((e) => '$e').toList();
    return null;
  }

  Future<void> writeIdList(String key, List<String> ids) =>
      _lists.put(key, ids);

  /// Every recipe id on the device, newest first. Null before the first sync.
  List<String>? get catalogIds => readIdList('catalog_ids');
  Future<void> setCatalogIds(List<String> ids) =>
      writeIdList('catalog_ids', ids);

  bool get hasCatalog => catalogIds != null;

  List<String>? get trendingIds => readIdList('trending_ids');
  Future<void> setTrendingIds(List<String> ids) =>
      writeIdList('trending_ids', ids);

  // meta
  DateTime? _date(String key) {
    final s = _meta.get(key);
    return s is String ? DateTime.tryParse(s) : null;
  }

  Future<void> _setDate(String key, DateTime? dt) => dt == null
      ? _meta.delete(key)
      : _meta.put(key, dt.toUtc().toIso8601String());

  /// Last successful sync with the site.
  DateTime? get lastSyncedAt => _date('lastSyncedAt');
  Future<void> setLastSyncedAt(DateTime dt) => _setDate('lastSyncedAt', dt);

  /// Last refresh the user asked for (rate limit).
  DateTime? get lastManualRefreshAt => _date('lastManualRefreshAt');
  Future<void> setLastManualRefreshAt(DateTime dt) =>
      _setDate('lastManualRefreshAt', dt);

  /// Earliest time an automatic sync may run (error backoff).
  DateTime? get nextAutoSyncAt => _date('nextAutoSyncAt');
  Future<void> setNextAutoSyncAt(DateTime? dt) => _setDate('nextAutoSyncAt', dt);

  int get autoSyncFailures => (_meta.get('autoSyncFailures') as int?) ?? 0;
  Future<void> setAutoSyncFailures(int n) => _meta.put('autoSyncFailures', n);

  /// ETags of the last seen manifest, id list and categories.
  String? etag(String name) => _meta.get('etag_$name') as String?;
  Future<void> setEtag(String name, String? value) => value == null
      ? _meta.delete('etag_$name')
      : _meta.put('etag_$name', value);

  // categories list cache as JSON
  List<Map<String, dynamic>>? readCategories() {
    final raw = _meta.get('categories_json');
    if (raw is String) {
      try {
        final list = jsonDecode(raw) as List;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> writeCategories(List<Map<String, dynamic>> categories) =>
      _meta.put('categories_json', jsonEncode(categories));
}
