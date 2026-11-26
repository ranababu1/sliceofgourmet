import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixture.dart';

/// In-memory sliceofgourmet.com built from captured fixtures. Speaks the
/// same sog/v1 routes, ETags and 304s as the live site, and lets tests
/// edit, add and delete recipes between syncs.
class FakeSite {
  FakeSite() {
    for (final f in [
      'recipes_list.json',
      'recipes_featured.json',
      'recipes_sparse.json'
    ]) {
      for (final r in fixtureList(f)) {
        cards['${r['id']}'] = r;
      }
    }
  }

  /// id -> list item json, the site's published recipes.
  final cards = <String, Map<String, dynamic>>{};
  final requests = <Uri>[];
  bool offline = false;
  bool hasManifest = true;

  int get networkCalls => requests.length;
  List<String> get paths => requests.map((u) => u.path).toList();

  void edit(String id, String modifiedGmt, {String? title}) {
    final c = Map<String, dynamic>.from(cards[id]!);
    c['modified_gmt'] = modifiedGmt;
    if (title != null) c['title'] = title;
    cards[id] = c;
  }

  void add(String id, String dateGmt) {
    final c = Map<String, dynamic>.from(cards.values.first);
    c['id'] = int.parse(id);
    c['slug'] = 'new-$id';
    c['title'] = 'New $id';
    c['date_gmt'] = dateGmt;
    c['modified_gmt'] = dateGmt;
    cards[id] = c;
  }

  List<Map<String, dynamic>> get _sorted => cards.values.toList()
    ..sort((a, b) => '${b['date_gmt']}'.compareTo('${a['date_gmt']}'));

  List<Map<String, dynamic>> get _ids => [
        for (final c in _sorted)
          {'id': c['id'], 'modified_gmt': c['modified_gmt']}
      ];

  String _etag(Object body) =>
      '"${crypto.md5.convert(utf8.encode(jsonEncode(body)))}"';

  http.Response _json(Object body, http.Request req,
      {Map<String, String> headers = const {}}) {
    final etag = _etag(body);
    if (req.headers['If-None-Match'] == etag) {
      return http.Response('', 304, headers: {'etag': etag});
    }
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {
      'content-type': 'application/json; charset=utf-8',
      'etag': etag,
      ...headers,
    });
  }

  late final client = MockClient((req) async {
    requests.add(req.url);
    if (offline) throw const SocketException('offline');
    final p = req.url.path;
    final q = req.url.queryParameters;

    if (p == '/wp-json/sog/v1/manifest') {
      if (!hasManifest) return http.Response('{"code":"rest_no_route"}', 404);
      return _json({
        'version': 1,
        'count': cards.length,
        'ids_etag': _etag(_ids).replaceAll('"', ''),
        'categories_etag': 'cats1',
        'min_sync_minutes': 360,
      }, req);
    }
    if (p == '/wp-json/sog/v1/recipes/ids') return _json(_ids, req);
    if (p == '/wp-json/sog/v1/recipes') {
      var list = _sorted;
      if (q['category'] == 'featured') {
        list = list
            .where((c) =>
                (c['categories'] as List).any((t) => t['slug'] == 'featured'))
            .toList();
      }
      if (q['modified_after'] case final after?) {
        list = list
            .where((c) => '${c['modified_gmt']}'.compareTo(after) > 0)
            .toList()
          ..sort((a, b) =>
              '${a['modified_gmt']}'.compareTo('${b['modified_gmt']}'));
      }
      final per = int.parse(q['per_page'] ?? '20');
      final page = int.parse(q['page'] ?? '1');
      final pages = (list.length / per).ceil();
      final slice = list.skip((page - 1) * per).take(per).toList();
      return _json(slice, req, headers: {
        'x-wp-total': '${list.length}',
        'x-wp-totalpages': '$pages',
      });
    }
    final m = RegExp(r'^/wp-json/sog/v1/recipes/(\d+)$').firstMatch(p);
    if (m != null) {
      final f = File('test/fixtures/recipe_${m[1]}.json');
      if (!cards.containsKey(m[1]) && !f.existsSync()) {
        return http.Response(fixtureText('recipe_not_found.json'), 404);
      }
      final body = f.existsSync()
          ? fixtureMap('recipe_${m[1]}.json')
          : {
              ...cards[m[1]]!,
              'recipe': {'name': cards[m[1]]!['title']}
            };
      if (cards[m[1]] case final c?) body['modified_gmt'] = c['modified_gmt'];
      return _json(body, req);
    }
    if (p == '/wp-json/wp/v2/categories') {
      return _json(fixture('categories.json')!, req);
    }
    if (p == '/wp-json/wp/v2/posts') {
      final hit = cards.values.where((c) => c['slug'] == q['slug']);
      return _json([
        for (final c in hit) {'id': c['id']}
      ], req);
    }
    return http.Response('not found', 404);
  });
}
