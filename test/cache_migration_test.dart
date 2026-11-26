import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sliceofgourmet/core/cache/local_store.dart';

void main() {
  test('older caches are dropped on upgrade, v3 data is kept', () async {
    Hive.init(Directory.systemTemp.createTempSync('sog_migrate').path);
    // what v1.1.0 (schema 2) left behind
    final posts = await Hive.openBox('posts');
    await posts.put('post_3574', '{"id":3574,"title":"Paya"}');
    final lists = await Hive.openBox('lists');
    await lists.put('latest_page_1', ['3574']);
    final meta = await Hive.openBox('meta');
    await meta.put('schema', 2);
    await meta.put('lastHydratedAt', DateTime.now().toIso8601String());
    await posts.close();
    await lists.close();
    await meta.close();

    await LocalStore.init();
    final store = LocalStore.instance;
    expect(store.readPost('3574'), isNull);
    expect(store.readIdList('latest_page_1'), isNull);
    expect(store.hasCatalog, isFalse, reason: 'forces a first-run sync');
    expect(store.lastSyncedAt, isNull);
    expect(Hive.box('meta').get('schema'), LocalStore.schemaVersion);

    // second start keeps v3 data
    await store.writePost('1', {'id': 1});
    await store.setCatalogIds(['1']);
    await LocalStore.init();
    expect(store.readPost('1'), isNotNull);
    expect(store.hasCatalog, isTrue);
  });
}
