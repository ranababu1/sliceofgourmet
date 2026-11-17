import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliceofgourmet/core/cache/local_store.dart';
import 'package:sliceofgourmet/features/recipes/data/wordpress_api.dart';
import 'package:sliceofgourmet/features/recipes/data/wordpress_repository.dart';
import 'package:sliceofgourmet/features/recipes/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Serves captured fixtures for the routes the app calls.
class FixtureServer {
  final requests = <Uri>[];
  bool offline = false;
  bool featuredEmpty = false;

  late final client = MockClient((req) async {
    requests.add(req.url);
    if (offline) throw const SocketException('offline');
    final p = req.url.path;
    final q = req.url.queryParameters;
    http.Response json(String name, [int code = 200]) =>
        http.Response.bytes(File('test/fixtures/$name').readAsBytesSync(), code,
            headers: {'content-type': 'application/json; charset=utf-8'});
    if (p == '/wp-json/sog/v1/recipes') {
      if (q['category'] == 'featured') {
        return featuredEmpty
            ? http.Response('[]', 200)
            : json('recipes_featured.json');
      }
      return json('recipes_list.json');
    }
    final m = RegExp(r'^/wp-json/sog/v1/recipes/(\d+)$').firstMatch(p);
    if (m != null) {
      final f = File('test/fixtures/recipe_${m[1]}.json');
      return f.existsSync()
          ? json('recipe_${m[1]}.json')
          : json('recipe_not_found.json', 404);
    }
    if (p == '/wp-json/wp/v2/categories') return json('categories.json');
    if (p == '/wp-json/wp/v2/posts' && q['slug'] == 'chapli-kabab') {
      return json('post_by_slug.json');
    }
    if (p == '/wp-json/wp/v2/posts') return http.Response('[]', 200);
    return http.Response('not found', 404);
  });
}

void main() {
  late FixtureServer server;
  late WordPressRecipeRepository repo;

  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('sog_repo').path);
    await LocalStore.init();
  });

  setUp(() async {
    await Hive.box('posts').clear();
    await Hive.box('lists').clear();
    server = FixtureServer();
    repo = WordPressRecipeRepository(
        SogApi('https://sliceofgourmet.com', client: server.client),
        LocalStore.instance);
  });

  test('latest uses sog/v1 and is served from cache offline', () async {
    final first = await repo.fetchLatest();
    expect(first.first.id, '3574');
    expect(server.requests.single.path, '/wp-json/sog/v1/recipes');
    expect(server.requests.single.queryParameters['per_page'], '20');

    server.offline = true;
    final cached = await repo.fetchLatest();
    expect(cached.map((r) => r.id), first.map((r) => r.id));
    expect(cached.first.imageUrl, first.first.imageUrl);
  });

  test('trending uses the featured category, falls back to latest', () async {
    final featured = await repo.fetchTrending(forceRefresh: true);
    expect(featured, isNotEmpty);
    expect(server.requests.first.queryParameters['category'], 'featured');

    server.featuredEmpty = true;
    final fallback = await repo.fetchTrending(forceRefresh: true);
    expect(fallback.first.id, '3574');
  });

  test('category and search pass the right params', () async {
    await repo.fetchByCategory(48, page: 2);
    await repo.search('kabab');
    expect(server.requests[0].queryParameters, containsPair('category', '48'));
    expect(server.requests[0].queryParameters, containsPair('page', '2'));
    expect(server.requests[1].queryParameters, containsPair('search', 'kabab'));
  });

  test('detail is cached and refresh falls back offline', () async {
    final r = await repo.fetchById('3574');
    expect(r.cookName, 'Sammy');
    server.offline = true;
    expect((await repo.fetchById('3574')).title, r.title);
    expect((await repo.fetchById('3574', forceRefresh: true)).title, r.title);
    expect(repo.fetchById('2640'), throwsA(isA<SocketException>()));
  });

  test('deleted recipe throws not found and clears the cache', () async {
    await expectLater(
        repo.fetchById('999999'), throwsA(isA<RecipeNotFoundException>()));
    expect(LocalStore.instance.readPost('999999'), isNull);
  });

  test('categories hide empty ones', () async {
    final cats = await repo.fetchCategories(forceRefresh: true);
    expect(cats.where((c) => c.slug == 'drinks'), isEmpty);
    expect(
        cats.firstWhere((c) => c.slug == 'main-course').count, greaterThan(0));
  });

  test('resolves shared links by slug', () async {
    expect(
        await repo.resolveLink(
            Uri.parse('https://sliceofgourmet.com/main-course/chapli-kabab/')),
        '666');
    expect(await repo.resolveLink(Uri.parse('https://sliceofgourmet.com/faq/')),
        isNull);
  });

  group('bookmarks', () {
    test('v1 ids carry over, junk is dropped, gone recipes are reported',
        () async {
      SharedPreferences.setMockInitialValues({
        'bookmarks': ['3574', '999999', 'wprm-12', '3574'],
      });
      final container = ProviderContainer(overrides: [
        recipeRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      container.read(bookmarkIdsNotifierProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(bookmarksProvider), {'3574', '999999'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('bookmarks_v'), 2);

      final result = await container.read(bookmarkedRecipesProvider.future);
      expect(result.items.map((r) => r.id), ['3574']);
      expect(result.goneIds, {'999999'});

      await container
          .read(bookmarkIdsNotifierProvider.notifier)
          .removeAll(result.goneIds);
      expect(prefs.getStringList('bookmarks'), ['3574']);
    });
  });
}
