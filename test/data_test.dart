import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sliceofgourmet/core/data_sync/recipe_sync.dart';
import 'package:sliceofgourmet/core/data_sync/sync_controller.dart';
import 'package:sliceofgourmet/features/recipes/data/recipe.dart';
import 'package:sliceofgourmet/features/recipes/data/wordpress_api.dart';

import 'fixture.dart';

void main() {
  group('SogApi (transport)', () {
    test('400 past last page maps to empty page', () async {
      final api = SogApi('https://wp.test',
          client: MockClient((_) async =>
              http.Response('{"code":"rest_post_invalid_page_number"}', 400)));
      final page = await api.fetchRecipes(page: 99);
      expect(page.items, isEmpty);
    });

    test('reads X-WP-TotalPages', () async {
      final api = SogApi('https://wp.test',
          client: MockClient((_) async =>
              http.Response('[]', 200, headers: {'x-wp-totalpages': '7'})));
      expect((await api.fetchRecipes()).totalPages, 7);
    });

    test('other errors throw', () async {
      final api = SogApi('https://wp.test',
          client: MockClient((_) async => http.Response('', 500)));
      expect(api.fetchRecipes(), throwsException);
    });

    test('requests time out', () async {
      final api =
          SogApi('https://wp.test', timeout: const Duration(milliseconds: 50),
              client: MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return http.Response('[]', 200);
      }));
      expect(api.fetchRecipes(), throwsA(isA<TimeoutException>()));
    });

    test('sends If-None-Match and maps 304 to not modified', () async {
      String? sent;
      final api = SogApi('https://wp.test', client: MockClient((req) async {
        sent = req.headers['If-None-Match'];
        return http.Response('', 304);
      }));
      final r = await api.fetchIds(etag: '"abc"');
      expect(sent, '"abc"');
      expect(r.notModified, isTrue);
    });

    test('live id list and manifest parse', () async {
      final api = SogApi('https://wp.test', client: MockClient((req) async {
        final name = req.url.path.endsWith('manifest')
            ? 'manifest.json'
            : 'recipe_ids.json';
        return http.Response(fixtureText(name), 200, headers: {'etag': '"e"'});
      }));
      final ids = (await api.fetchIds()).data!;
      expect(ids.length, 235);
      expect(ids.first.id, '3574');
      expect(normGmt(ids.first.modifiedGmt), '2026-11-16T23:03:36');
      final m = (await api.fetchManifest())!.data!;
      expect(m.count, 235);
      expect(m.idsEtag, isNotEmpty);
    });
  });

  group('images', () {
    test('Photon URLs are resized to width buckets', () {
      const url =
          'https://i0.wp.com/sliceofgourmet.com/wp-content/uploads/2022/07/mutton-paya-scaled.jpg?fit=720%2C866&ssl=1';
      final img = RecipeImage(id: 1, url: url);
      final u = Uri.parse(img.urlFor(700));
      expect(u.queryParameters['w'], '720');
      expect(u.queryParameters.containsKey('fit'), isFalse);
      expect(u.queryParameters['ssl'], '1');
      expect(Uri.parse(img.urlFor(1000)).queryParameters['w'], '1080');
      expect(photonResize('https://example.com/a.jpg', 480),
          'https://example.com/a.jpg');
    });
  });

  group('refresh limits', () {
    test('backoff grows, is capped and jittered', () {
      final r = Random(1);
      final first = backoffFor(1, random: r);
      expect(first.inSeconds, inInclusiveRange(60, 180));
      final big = backoffFor(30, random: r);
      expect(big, lessThanOrEqualTo(kAutoSyncInterval * 1.5));
      expect(big, greaterThanOrEqualTo(kAutoSyncInterval * 0.5));
    });

    test('messages', () {
      expect(
          refreshMessage(
              const RefreshTooSoon(Duration(minutes: 11, seconds: 5))),
          'You are up to date. You can refresh again in 12 minutes.');
      expect(refreshMessage(const RefreshDone(SyncReport())),
          'You have the latest recipes.');
      expect(
          refreshMessage(const RefreshDone(SyncReport(added: 2, removed: 1))),
          'Recipes refreshed: 2 new, 1 removed.');
      expect(refreshMessage(const RefreshTooSoon(Duration(seconds: 20))),
          contains('1 minute.'));
    });
  });
}
