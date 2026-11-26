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

/// Result of a conditional GET. [data] is null when the server answered
/// 304 Not Modified for the ETag we sent.
class Fetched<T> {
  const Fetched(this.data, this.etag);
  final T? data;
  final String? etag;
  bool get notModified => data == null;
}

/// One row of `GET sog/v1/recipes/ids`.
class RemoteId {
  const RemoteId(this.id, this.modifiedGmt);
  final String id;
  final String modifiedGmt;
}

/// Tiny `GET sog/v1/manifest` summary.
class Manifest {
  const Manifest(
      {required this.count,
      required this.idsEtag,
      required this.categoriesEtag,
      this.minSyncMinutes = 0});
  final int count;
  final String idsEtag;
  final String categoriesEtag;
  final int minSyncMinutes;

  factory Manifest.fromJson(Map<String, dynamic> j) => Manifest(
        count: (j['count'] as num?)?.toInt() ?? 0,
        idsEtag: '${j['ids_etag'] ?? ''}',
        categoriesEtag: '${j['categories_etag'] ?? ''}',
        minSyncMinutes: (j['min_sync_minutes'] as num?)?.toInt() ?? 0,
      );
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

  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': 'SliceOfGourmetApp/1.1',
  };

  Uri _u(String path, [Map<String, Object?>? q]) {
    final query = <String, String>{};
    q?.forEach((k, v) {
      if (v != null && '$v'.isNotEmpty) query[k] = '$v';
    });
    return Uri.parse(baseUrl)
        .replace(path: path, queryParameters: query.isEmpty ? null : query);
  }

  Future<http.Response> _get(Uri uri, {String? etag}) => client
      .get(uri,
          headers: etag == null || etag.isEmpty
              ? _headers
              : {..._headers, 'If-None-Match': etag})
      .timeout(timeout);

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
    String? modifiedAfter,
  }) async {
    final res = await _get(_u('/wp-json/sog/v1/recipes', {
      'modified_after': modifiedAfter,
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

  /// `GET sog/v1/recipes/ids`: every published recipe id with its modified
  /// time, newest first. Conditional on [etag].
  Future<Fetched<List<RemoteId>>> fetchIds({String? etag}) async {
    final res = await _get(_u('/wp-json/sog/v1/recipes/ids'), etag: etag);
    if (res.statusCode == 304) return Fetched(null, etag);
    if (res.statusCode != 200) throw ApiException('ids', res.statusCode);
    final ids = _list(res.body)
        .map((e) => RemoteId('${e['id']}', '${e['modified_gmt'] ?? ''}'))
        .where((e) => int.tryParse(e.id) != null)
        .toList();
    return Fetched(ids, res.headers['etag']);
  }

  /// `GET sog/v1/manifest`, conditional on [etag]. Null when the site has
  /// no manifest route (older plugin); callers fall back to the id list.
  Future<Fetched<Manifest>?> fetchManifest({String? etag}) async {
    final res = await _get(_u('/wp-json/sog/v1/manifest'), etag: etag);
    if (res.statusCode == 304) return Fetched(null, etag);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw ApiException('manifest', res.statusCode);
    final j = jsonDecode(res.body);
    if (j is! Map) throw ApiException('manifest', res.statusCode);
    return Fetched(
        Manifest.fromJson(Map<String, dynamic>.from(j)), res.headers['etag']);
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
