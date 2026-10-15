import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sliceofgourmet/core/cache/local_store.dart';
import 'package:sliceofgourmet/core/data_sync/hydrator.dart';
import 'package:sliceofgourmet/features/recipes/data/wordpress_api.dart';
import 'package:sliceofgourmet/features/recipes/presentation/paged_recipes.dart';

import 'fakes.dart';

void main() {
  group('WordPressApi', () {
    test('400 past last page maps to empty page', () async {
      final api = WordPressApi('https://wp.test',
          client: MockClient((_) async => http.Response(
              '{"code":"rest_post_invalid_page_number"}', 400)));
      final page = await api.fetchPostsPage(page: 99);
      expect(page.items, isEmpty);
    });

    test('reads X-WP-TotalPages', () async {
      final api = WordPressApi('https://wp.test',
          client: MockClient((_) async => http.Response('[]', 200,
              headers: {'x-wp-totalpages': '7'})));
      expect((await api.fetchPostsPage()).totalPages, 7);
    });

    test('other errors throw', () async {
      final api = WordPressApi('https://wp.test',
          client: MockClient((_) async => http.Response('', 500)));
      expect(api.fetchPostsPage(), throwsException);
    });

    test('requests time out', () async {
      final api = WordPressApi('https://wp.test',
          timeout: const Duration(milliseconds: 50),
          client: MockClient((_) async {
            await Future<void>.delayed(const Duration(seconds: 1));
            return http.Response('[]', 200);
          }));
      expect(api.fetchPostsPage(), throwsA(isA<TimeoutException>()));
    });
  });

  group('PagedRecipes', () {
    test('stops on short page and recovers from errors', () async {
      var fail = true;
      final paged = PagedRecipes((page, size) async {
        if (fail) throw Exception('offline');
        return page == 1 ? List.generate(size, fakeRecipe) : [fakeRecipe(99)];
      }, pageSize: 5);

      await paged.loadMore();
      expect(paged.error, isNotNull);
      expect(paged.loading, isFalse);

      fail = false;
      await paged.refresh();
      expect(paged.items, hasLength(5));
      expect(paged.endReached, isFalse);
      await paged.loadMore();
      expect(paged.items, hasLength(6));
      expect(paged.endReached, isTrue);
    });
  });

  group('Hydrator', () {
    setUpAll(() async {
      Hive.init(Directory.systemTemp.createTempSync('sog_hydrator').path);
      await LocalStore.init();
    });

    test('hydrate forces network refresh and reports it', () async {
      final repo = FakeRecipeRepository();
      DateTime? refreshedAt;
      final h = Hydrator(
          store: LocalStore.instance,
          repo: repo,
          onRefreshed: (at) => refreshedAt = at);
      expect(await h.hydrate(), isTrue);
      expect(repo.forceFlags,
          {'trending': true, 'latest': true, 'categories': true});
      expect(refreshedAt, isNotNull);
      expect(LocalStore.instance.lastHydratedAt, isNotNull);
    });
  });
}
