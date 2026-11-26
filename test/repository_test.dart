import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliceofgourmet/core/cache/local_store.dart';
import 'package:sliceofgourmet/core/data_sync/recipe_sync.dart';
import 'package:sliceofgourmet/core/data_sync/sync_controller.dart';
import 'package:sliceofgourmet/features/recipes/data/wordpress_api.dart';
import 'package:sliceofgourmet/features/recipes/data/wordpress_repository.dart';
import 'package:sliceofgourmet/features/recipes/providers.dart';

import 'fake_site.dart';

void main() {
  late FakeSite site;
  late SogApi api;
  late LocalStore store;
  late WordPressRecipeRepository repo;
  late RecipeSync sync;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('sog_repo').path);
    await LocalStore.init();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LocalStore.instance;
    await store.clear();
    site = FakeSite();
    api = SogApi('https://sliceofgourmet.com', client: site.client);
    repo = WordPressRecipeRepository(api, store);
    sync = RecipeSync(api, store, pageSize: 4);
  });

  group('first run', () {
    test('downloads the whole catalog in small pages', () async {
      final progress = <(int, int)>[];
      final r = await sync.sync(onProgress: (d, t) => progress.add((d, t)));
      expect(r.firstRun, isTrue);
      expect(r.added, 9);
      expect(store.catalogIds, hasLength(9));
      expect(progress.last, (9, 9));
      final pages = site.requests
          .where((u) =>
              u.path == '/wp-json/sog/v1/recipes' &&
              u.queryParameters['category'] == null)
          .toList();
      expect(pages, hasLength(3), reason: '9 recipes, 4 per page');
      expect(pages.every((u) => u.queryParameters['per_page'] == '4'), isTrue);
    });

    test('screens read the cache, no requests after sync', () async {
      await sync.sync();
      site.requests.clear();
      final latest = await repo.fetchLatest();
      expect(latest.first.id, '3574', reason: 'newest first');
      final trending = await repo.fetchTrending();
      expect(trending.map((r) => r.id), containsAll(['2368', '2215', '666']));
      final cats = await repo.fetchCategories();
      expect(cats.where((c) => c.slug == 'featured'), isEmpty);
      final side = cats.firstWhere((c) => c.slug == 'side-dish');
      // Side Dish (42) includes its children Soups and Appetizers
      final inSide = await repo.fetchByCategory(side.id);
      expect(inSide.length, side.count);
      expect(inSide.map((r) => r.id), containsAll(['3574', '3542', '2623']));
      expect((await repo.search('paya')).first.id, '3574');
      expect(await repo.search('zzzz'), isEmpty);
      expect(
          await repo.resolveLink(Uri.parse(
              'https://sliceofgourmet.com/main-course/chapli-kabab/')),
          '666');
      expect(site.requests, isEmpty);
    });
  });

  group('incremental', () {
    setUp(() async {
      await sync.sync();
      site.requests.clear();
    });

    test('nothing changed: one manifest request answered 304', () async {
      final r = await sync.sync();
      expect(r.changed, isFalse);
      expect(site.paths, ['/wp-json/sog/v1/manifest']);
    });

    test('fetches only changed, new and deleted recipes', () async {
      site.edit('3542', '2026-11-20T10:00:00', title: 'Edited');
      site.add('9001', '2026-11-21T09:00:00');
      site.cards.remove('1127');

      final r = await sync.sync();
      expect((r.added, r.updated, r.removed), (1, 1, 1));
      final list = site.requests
          .where((u) => u.path == '/wp-json/sog/v1/recipes' &&
              u.queryParameters['category'] == null)
          .single;
      expect(list.queryParameters['modified_after'], '2026-11-20T09:59:59');

      final latest = await repo.fetchLatest();
      expect(latest.first.id, '9001');
      expect(latest.any((x) => x.id == '1127'), isFalse);
      expect(latest.firstWhere((x) => x.id == '3542').title, 'Edited');
    });

    test('older plugin without manifest still syncs from the id list',
        () async {
      site.hasManifest = false;
      site.edit('666', '2026-11-25T00:00:00');
      final r = await sync.sync();
      expect(r.updated, 1);
      site.requests.clear();
      final again = await sync.sync();
      expect(again.changed, isFalse);
      expect(site.paths, contains('/wp-json/sog/v1/recipes/ids'));
    });

    test('a changed recipe drops its stale saved detail', () async {
      final before = await repo.fetchById('3574');
      expect(store.readPost('3574'), isNotNull);
      site.requests.clear();
      await repo.fetchById('3574');
      expect(site.requests, isEmpty, reason: 'served from cache');

      site.edit('3574', '2026-11-22T00:00:00');
      await sync.sync();
      expect(store.readPost('3574'), isNull);
      final after = await repo.fetchById('3574');
      expect(after.title, before.title);
    });
  });

  test('detail offline falls back to the saved copy', () async {
    await sync.sync();
    final r = await repo.fetchById('3574');
    expect(r.cookName, 'Sammy');
    site.offline = true;
    expect((await repo.fetchById('3574')).title, r.title);
    expect(repo.fetchById('2640'), throwsA(isA<SocketException>()));
  });

  test('deleted recipe throws not found and clears the cache', () async {
    await expectLater(
        repo.fetchById('999999'), throwsA(isA<RecipeNotFoundException>()));
    expect(store.readPost('999999'), isNull);
  });

  test('non-recipe links are ignored', () async {
    expect(await repo.resolveLink(Uri.parse('https://sliceofgourmet.com/faq/')),
        isNull);
    expect(await repo.resolveLink(Uri.parse('https://example.com/a/b/')),
        isNull);
  });

  group('controller', () {
    late DateTime now;
    late ProviderContainer c;

    setUp(() {
      now = DateTime(2026, 11, 26, 22);
      c = ProviderContainer(overrides: [
        sogApiProvider.overrideWithValue(api),
        localStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(() => now),
      ]);
      addTearDown(c.dispose);
    });

    test('first run, then refresh is limited to every 15 minutes', () async {
      final ctl = c.read(syncControllerProvider.notifier);
      await ctl.autoSync();
      expect(c.read(syncControllerProvider).hasCatalog, isTrue);

      final first = await ctl.refresh();
      expect(first, isA<RefreshDone>());
      site.requests.clear();

      now = now.add(const Duration(minutes: 5));
      final soon = await ctl.refresh();
      expect(soon, isA<RefreshTooSoon>());
      expect((soon as RefreshTooSoon).wait, const Duration(minutes: 10));
      expect(site.requests, isEmpty);

      now = now.add(const Duration(minutes: 11));
      expect(await ctl.refresh(), isA<RefreshDone>());
    });

    test('auto sync runs at most every 6 hours and backs off on errors',
        () async {
      final ctl = c.read(syncControllerProvider.notifier);
      await ctl.autoSync();
      site.requests.clear();

      now = now.add(const Duration(hours: 1));
      await ctl.autoSync();
      expect(site.requests, isEmpty);

      now = now.add(const Duration(hours: 6));
      site.offline = true;
      await ctl.autoSync();
      expect(store.autoSyncFailures, 1);
      final next = store.nextAutoSyncAt!;
      expect(next.isAfter(now), isTrue);

      site.offline = false;
      site.requests.clear();
      await ctl.autoSync();
      expect(site.requests, isEmpty, reason: 'still backing off');

      now = next.add(const Duration(seconds: 1));
      await ctl.autoSync();
      expect(site.requests, isNotEmpty);
      expect(store.autoSyncFailures, 0);
    });

    test('offline first run reports failure and can retry', () async {
      site.offline = true;
      final ctl = c.read(syncControllerProvider.notifier);
      await ctl.autoSync();
      expect(c.read(syncControllerProvider).phase, SyncPhase.failed);
      site.offline = false;
      await ctl.retryFirstRun();
      expect(c.read(syncControllerProvider).hasCatalog, isTrue);
    });
  });

  group('bookmarks', () {
    test('v1 ids carry over, junk is dropped, gone recipes are reported',
        () async {
      SharedPreferences.setMockInitialValues({
        'bookmarks': ['3574', '999999', 'wprm-12', '3574'],
      });
      await sync.sync();
      final container = ProviderContainer(overrides: [
        recipeRepositoryProvider.overrideWithValue(repo),
        localStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);
      container.read(bookmarkIdsNotifierProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(bookmarksProvider), {'3574', '999999'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('bookmarks_v'), 2);

      site.requests.clear();
      final result = await container.read(bookmarkedRecipesProvider.future);
      expect(result.items.map((r) => r.id), ['3574']);
      expect(result.goneIds, {'999999'});
      expect(site.paths, ['/wp-json/sog/v1/recipes/999999'],
          reason: 'saved cards come from the catalog');

      await container
          .read(bookmarkIdsNotifierProvider.notifier)
          .removeAll(result.goneIds);
      expect(prefs.getStringList('bookmarks'), ['3574']);
    });
  });
}
