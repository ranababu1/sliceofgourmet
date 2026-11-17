import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Simple local cache built on Hive.
/// Boxes:
/// - posts: `card_<id>` list item json, `post_<id>` full recipe json, both in
///   the sog/v1 server shape
/// - lists: lists of ids, example `latest_page_1` => [1,2,3]
/// - meta: schema, lastHydratedAt (ISO), categories_json
class LocalStore {
  static late Box _posts;
  static late Box _lists;
  static late Box _meta;

  /// Bump when the cached json shape changes. v1 held parsed WPRM/HTML
  /// recipes from wp/v2/posts; v2 holds sog/v1 responses.
  static const int schemaVersion = 2;

  static Future<void> init() async {
    _posts = await Hive.openBox('posts');
    _lists = await Hive.openBox('lists');
    _meta = await Hive.openBox('meta');
    await _migrate();
  }

  /// Drops caches written by older app versions. They are only a cache and
  /// are refilled from the network on the next load.
  static Future<void> _migrate() async {
    if (_meta.get('schema') == schemaVersion) return;
    await _posts.clear();
    await _lists.clear();
    await _meta.clear();
    await _meta.put('schema', schemaVersion);
  }

  static LocalStore get instance => LocalStore();

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

  // list cards
  Map<String, dynamic>? readCard(String id) => _read('card_$id');

  Future<void> writeCard(String id, Map<String, dynamic> json) =>
      _posts.put('card_$id', jsonEncode(json));

  Future<void> deleteRecipe(String id) async {
    await _posts.delete('post_$id');
    await _posts.delete('card_$id');
  }

  // lists
  List<String>? readIdList(String key) {
    final raw = _lists.get(key);
    if (raw is List) return raw.map((e) => '$e').toList();
    return null;
  }

  Future<void> writeIdList(String key, List<String> ids) =>
      _lists.put(key, ids);

  // meta basics
  DateTime? get lastHydratedAt {
    final s = _meta.get('lastHydratedAt');
    if (s is String) return DateTime.tryParse(s);
    return null;
  }

  Future<void> setLastHydratedAt(DateTime dt) =>
      _meta.put('lastHydratedAt', dt.toIso8601String());

  // trending and latest ids
  List<String>? get trendingIds => readIdList('trending_ids');
  Future<void> setTrendingIds(List<String> ids) =>
      writeIdList('trending_ids', ids);

  List<String>? get latestPage1Ids => readIdList('latest_page_1');
  Future<void> setLatestPage1Ids(List<String> ids) =>
      writeIdList('latest_page_1', ids);

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
