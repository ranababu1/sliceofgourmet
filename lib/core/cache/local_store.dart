import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Simple local cache built on Hive.
/// Boxes:
/// - posts: each entry is a Recipe json, key `post_<id>`
/// - lists: stores lists of ids, example `latest_page_1` => [1,2,3]
/// - meta: lastHydratedAt (ISO), trending_ids, categories_data
class LocalStore {
  static late Box _posts;
  static late Box _lists;
  static late Box _meta;

  static Future<void> init() async {
    _posts = await Hive.openBox('posts');
    _lists = await Hive.openBox('lists');
    _meta = await Hive.openBox('meta');
  }

  static LocalStore get instance => LocalStore();

  // posts
  Map<String, dynamic>? readPost(String id) {
    final raw = _posts.get('post_$id');
    if (raw is String) return jsonDecode(raw) as Map<String, dynamic>;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  Future<void> writePost(String id, Map<String, dynamic> json) async {
    await _posts.put('post_$id', jsonEncode(json));
  }

  // lists
  List<String>? readIdList(String key) {
    final raw = _lists.get(key);
    if (raw is List) return raw.map((e) => '$e').toList();
    return null;
  }

  Future<void> writeIdList(String key, List<String> ids) async {
    await _lists.put(key, ids);
  }

  // meta basics
  DateTime? get lastHydratedAt {
    final s = _meta.get('lastHydratedAt');
    if (s is String) return DateTime.tryParse(s);
    return null;
  }

  Future<void> setLastHydratedAt(DateTime dt) async {
    await _meta.put('lastHydratedAt', dt.toIso8601String());
  }

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
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return null;
  }

  Future<void> writeCategories(List<Map<String, dynamic>> categories) async {
    await _meta.put('categories_json', jsonEncode(categories));
  }
}
