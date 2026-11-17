import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants.dart';
import 'category.dart';

/// One page of results plus the totals reported in X-WP-* headers.
class ApiPage {
  const ApiPage(this.items, {this.total, this.totalPages});
  final List<Map<String, dynamic>> items;

  /// From X-WP-Total, null if absent.
  final int? total;

  /// From X-WP-TotalPages, null if absent.
  final int? totalPages;
}

/// The recipe is gone or is no longer a published recipe (HTTP 404).
class RecipeNotFoundException implements Exception {
  RecipeNotFoundException(this.id);
  final String id;
  @override
  String toString() => 'Recipe $id not found';
}

class ApiException implements Exception {
  ApiException(this.label, this.statusCode);
  final String label;
  final int statusCode;
  @override
  String toString() => 'API $label error $statusCode';
}

/// Client for the sog/v1 recipe API plus the few core WP routes the app
/// still needs (categories, slug lookup for deep links). Read only.
class SogApi {
  SogApi(this.baseUrl, {http.Client? client, this.timeout = kHttpTimeout})
      : client = client ?? http.Client();
  final String baseUrl;
  final http.Client client;
  final Duration timeout;

  static const _headers = {'Accept': 'application/json'};

  Uri _u(String path, [Map<String, Object?>? q]) {
    final query = <String, String>{};
    q?.forEach((k, v) {
      if (v != null && '$v'.isNotEmpty) query[k] = '$v';
    });
    return Uri.parse(baseUrl)
        .replace(path: path, queryParameters: query.isEmpty ? null : query);
  }

  Future<http.Response> _get(Uri uri) =>
      client.get(uri, headers: _headers).timeout(timeout);

  static bool _isPastLastPage(http.Response res) {
    if (res.statusCode != 400) return false;
    try {
      final j = jsonDecode(res.body);
      return j is Map &&
          (j['code'] == 'rest_post_invalid_page_number' ||
              j['code'] == 'rest_invalid_param');
    } catch (_) {
      return false;
    }
  }

  static List<Map<String, dynamic>> _list(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// `GET sog/v1/recipes`. [category] is a category id or slug.
  Future<ApiPage> fetchRecipes({
    int page = 1,
    int perPage = 20,
    String? search,
    String? category,
    String orderby = 'date',
    String order = 'desc',
  }) async {
    final res = await _get(_u('/wp-json/sog/v1/recipes', {
      'page': page,
      'per_page': perPage.clamp(1, 100),
      'search': search,
      'category': category,
      'orderby': orderby,
      'order': order,
    }));
    if (_isPastLastPage(res)) return const ApiPage([], totalPages: 0);
    if (res.statusCode != 200) throw ApiException('recipes', res.statusCode);
    return ApiPage(
      _list(res.body),
      total: int.tryParse(res.headers['x-wp-total'] ?? ''),
      totalPages: int.tryParse(res.headers['x-wp-totalpages'] ?? ''),
    );
  }

  /// `GET sog/v1/recipes/{id}`: full recipe.
  Future<Map<String, dynamic>> fetchRecipe(String id) async {
    if (int.tryParse(id) == null) throw RecipeNotFoundException(id);
    final res = await _get(_u('/wp-json/sog/v1/recipes/$id'));
    if (res.statusCode == 404) throw RecipeNotFoundException(id);
    if (res.statusCode != 200) throw ApiException('recipe', res.statusCode);
    final j = jsonDecode(res.body);
    if (j is! Map) throw ApiException('recipe', res.statusCode);
    return Map<String, dynamic>.from(j);
  }

  /// `GET sog/v1/recipes/ids`: every published recipe id.
  Future<Set<String>> fetchRecipeIds() async {
    final res = await _get(_u('/wp-json/sog/v1/recipes/ids'));
    if (res.statusCode != 200) throw ApiException('ids', res.statusCode);
    return _list(res.body).map((e) => '${e['id']}').toSet();
  }

  /// Non-empty post categories.
  Future<List<RecipeCategory>> fetchCategories() async {
    final res = await _get(_u('/wp-json/wp/v2/categories', {
      'per_page': 100,
      'hide_empty': 'true',
      'orderby': 'count',
      'order': 'desc',
      '_fields': 'id,name,slug,count,parent',
    }));
    if (res.statusCode != 200) {
      throw ApiException('categories', res.statusCode);
    }
    return _list(res.body)
        .map(RecipeCategory.fromJson)
        .where((c) => c.count > 0)
        .toList();
  }

  /// Post id for a permalink slug, used to open shared links. Null if none.
  Future<String?> resolveSlug(String slug) async {
    final res = await _get(_u('/wp-json/wp/v2/posts', {
      'slug': slug,
      '_fields': 'id',
    }));
    if (res.statusCode != 200) throw ApiException('slug', res.statusCode);
    final list = _list(res.body);
    return list.isEmpty ? null : '${list.first['id']}';
  }
}
