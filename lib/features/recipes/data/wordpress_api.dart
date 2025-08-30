import 'dart:convert';
import 'package:http/http.dart' as http;

class WordPressApi {
  WordPressApi(this.baseUrl, {http.Client? client})
    : client = client ?? http.Client();
  final String baseUrl;
  final http.Client client;

  Uri _u(String path, [Map<String, dynamic>? q]) {
    final uri = Uri.parse(
      baseUrl,
    ).replace(path: path, queryParameters: q?.map((k, v) => MapEntry(k, '$v')));
    return uri;
  }

  Future<List<Map<String, dynamic>>> fetchPosts({
    int page = 1,
    int perPage = 20,
    bool sticky = false,
  }) async {
    final uri = _u('/wp-json/wp/v2/posts', {
      'page': page,
      'per_page': perPage,
      '_embed': '1',
      if (sticky) 'sticky': 'true',
      'orderby': sticky ? 'date' : 'date',
      'order': 'desc',
      // you can add categories, search etc later
    });
    final res = await client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('WP posts error ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> fetchPostById(String id) async {
    final uri = _u('/wp-json/wp/v2/posts/$id', {'_embed': '1'});
    final res = await client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('WP post error ${res.statusCode}');
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  Future<List<String>> fetchCategories() async {
    final uri = _u('/wp-json/wp/v2/categories', {'per_page': 100});
    final res = await client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('WP categories error ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => (e['name'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchPosts(
    String query, {
    int page = 1,
    int perPage = 20,
  }) async {
    final uri = _u('/wp-json/wp/v2/posts', {
      'search': query,
      'page': page,
      'per_page': perPage,
      '_embed': '1',
    });
    final res = await client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('WP search error ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
