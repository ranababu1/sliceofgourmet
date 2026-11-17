import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sliceofgourmet/core/cache/local_store.dart';

void main() {
  test('v1 caches (WPRM/HTML recipes) are dropped on upgrade', () async {
    Hive.init(Directory.systemTemp.createTempSync('sog_migrate').path);
    // what v1.0.0 left behind
    final posts = await Hive.openBox('posts');
    await posts.put('post_3574',
        '{"id":"3574","title":"Paya","content":"<div class=\\"wprm-recipe\\">","cookTimeMinutes":20}');
    final lists = await Hive.openBox('lists');
    await lists.put('latest_page_1', ['3574']);
    final meta = await Hive.openBox('meta');
    await meta.put('lastHydratedAt', DateTime.now().toIso8601String());
    await posts.close();
    await lists.close();
    await meta.close();

    await LocalStore.init();
    final store = LocalStore.instance;
    expect(store.readPost('3574'), isNull);
    expect(store.latestPage1Ids, isNull);
    expect(store.lastHydratedAt, isNull, reason: 'forces a fresh hydrate');
    expect(Hive.box('meta').get('schema'), LocalStore.schemaVersion);

    // second start keeps v2 data
    await store.writePost('1', {'id': 1});
    await LocalStore.init();
    expect(store.readPost('1'), isNotNull);
  });
}
