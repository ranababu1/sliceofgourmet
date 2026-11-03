import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants.dart';
import 'category.dart';

/// One page of posts plus the total page count reported by WordPress.
class WpPage {
  const WpPage(this.items, this.totalPages);
  final List<Map<String, dynamic>> items;

  /// From the X-WP-TotalPages header, null if absent.
  final int? totalPages;
}

class WordPressApi {
  WordPressApi(this.baseUrl, {http.Client? client, this.timeout = kHttpTimeout})
      : client = client ?? http.Client();
  final String baseUrl;
  final http.Client client;
  final Duration timeout;

  Uri _u(String path, [Map<String, dynamic>? q]) {
    return Uri.parse(baseUrl).replace(
        path: path, queryParameters: q?.map((k, v) => MapEntry(k, '$v')));
  }

  Future<http.Response> _get(Uri uri) => client.get(uri).timeout(timeout);

  static bool _isPastLastPage(http.Response res) {
    if (res.statusCode != 400) return false;
    try {
      final j = jsonDecode(res.body);
      return j is Map && j['code'] == 'rest_post_invalid_page_number';
    } catch (_) {
      return false;
    }
  }

  Future<WpPage> _fetchPostList(Map<String, dynamic> qp, String label) async {
    final res = await _get(_u('/wp-json/wp/v2/posts', qp));
    if (_isPastLastPage(res)) return const WpPage([], 0);
    if (res.statusCode != 200) {
      throw Exception('WP $label error ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List;
    return WpPage(
      list.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      int.tryParse(res.headers['x-wp-totalpages'] ?? ''),
    );
  }

  Future<WpPage> fetchPostsPage(
      {int page = 1,
      int perPage = 20,
      bool sticky = false,
      int? categoryId}) {
    return _fetchPostList({
      'page': page,
      'per_page': perPage,
      '_embed': '1',
      'orderby': 'date',
      'order': 'desc',
      if (sticky) 'sticky': 'true',
      if (categoryId != null) 'categories': categoryId,
    }, 'posts');
  }

  Future<List<Map<String, dynamic>>> fetchPosts(
          {int page = 1,
          int perPage = 20,
          bool sticky = false,
          int? categoryId}) async =>
      (await fetchPostsPage(
              page: page,
              perPage: perPage,
              sticky: sticky,
              categoryId: categoryId))
          .items;

  Future<Map<String, dynamic>> fetchPostById(String id) async {
    final res = await _get(_u('/wp-json/wp/v2/posts/$id', {'_embed': '1'}));
    if (res.statusCode != 200) {
      throw Exception('WP post error ${res.statusCode}');
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  Future<List<RecipeCategory>> fetchCategoriesDetailed() async {
    final res = await _get(_u('/wp-json/wp/v2/categories',
        {'per_page': 100, 'orderby': 'count', 'order': 'desc'}));
    if (res.statusCode != 200) {
      throw Exception('WP categories error ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List;
    return list
        .map(
            (e) => RecipeCategory.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<WpPage> searchPostsPage(String query,
      {int page = 1, int perPage = 20}) {
    return _fetchPostList({
      'search': query,
      'page': page,
      'per_page': perPage,
      '_embed': '1',
    }, 'search');
  }

  Future<List<Map<String, dynamic>>> searchPosts(String query,
          {int page = 1, int perPage = 20}) async =>
      (await searchPostsPage(query, page: page, perPage: perPage)).items;
}
