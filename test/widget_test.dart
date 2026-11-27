import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliceofgourmet/app.dart';
import 'package:sliceofgourmet/core/cache/local_store.dart';
import 'package:sliceofgourmet/core/data_sync/recipe_sync.dart';
import 'package:sliceofgourmet/core/data_sync/sync_controller.dart';
import 'package:sliceofgourmet/core/profile/name_controller.dart';
import 'package:sliceofgourmet/features/recipes/data/wordpress_api.dart';
import 'package:sliceofgourmet/features/recipes/providers.dart';

import 'fakes.dart';

/// Sync that never touches the network.
class FakeSync extends RecipeSync {
  FakeSync(LocalStore store) : super(SogApi('https://wp.test'), store);
  Completer<void>? gate;
  bool fail = false;
  int calls = 0;

  @override
  Future<SyncReport> sync({void Function(int, int)? onProgress}) async {
    calls++;
    onProgress?.call(50, 235);
    if (gate != null) await gate!.future;
    if (fail) throw Exception('offline');
    await store.setCatalogIds(['0', '1', '2']);
    return const SyncReport();
  }
}

Widget _app(FakeSync sync) => ProviderScope(
      overrides: [
        recipeRepositoryProvider.overrideWithValue(FakeRecipeRepository()),
        recipeSyncProvider.overrideWithValue(sync),
      ],
      child: const SliceOfGourmetApp(),
    );

Future<void> _pumpHome(WidgetTester tester, {FakeSync? sync}) async {
  await tester.pumpWidget(_app(sync ?? FakeSync(LocalStore.instance)));
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('sog_widget').path);
    await LocalStore.init(inMemory: true);
  });

  setUp(() async {
    // Skip the one-time welcome prompt unless a test wants it.
    SharedPreferences.setMockInitialValues({kNamePromptShownKey: true});
    await LocalStore.instance.clear();
  });

  testWidgets('home shows cached recipes and a refresh button', (tester) async {
    await LocalStore.instance.setCatalogIds(['0', '1', '2']);
    await LocalStore.instance.setLastSyncedAt(DateTime.now());
    final sync = FakeSync(LocalStore.instance);
    await _pumpHome(tester, sync: sync);

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('What are we\ncooking today?'), findsOneWidget);
    expect(find.text('Hi there'), findsOneWidget);
    expect(find.text('Fake Recipe 0'), findsWidgets);
    expect(find.byTooltip('Refresh recipes'), findsOneWidget);
    expect(sync.calls, 0, reason: 'synced recently, nothing to do');

    await tester.tap(find.byTooltip('Refresh recipes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(sync.calls, 1);
    expect(find.text('You have the latest recipes.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.byTooltip('Refresh recipes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(sync.calls, 1, reason: 'rate limited');
    expect(find.textContaining('You can refresh again in'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('first run shows progress, then offline state with retry',
      (tester) async {
    final sync = FakeSync(LocalStore.instance)
      ..gate = Completer<void>()
      ..fail = true;
    await tester.pumpWidget(_app(sync));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Setting the table'), findsOneWidget);
    expect(find.text('Getting recipes ready: 50 of 235'), findsOneWidget);

    sync.gate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('You are offline'), findsOneWidget);

    sync
      ..gate = null
      ..fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Fake Recipe 0'), findsWidgets);
  });

  testWidgets('tabs open without an account', (tester) async {
    await LocalStore.instance.setCatalogIds(['0']);
    await LocalStore.instance.setLastSyncedAt(DateTime.now());
    await _pumpHome(tester);
    await tester.tap(find.bySemanticsLabel('Saved'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Saved'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Refresh recipes'), findsOneWidget);
    expect(find.text('Add your name'), findsOneWidget);
  });

  testWidgets('welcome prompt can save a name used in the greeting',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.instance.setCatalogIds(['0']);
    await LocalStore.instance.setLastSyncedAt(DateTime.now());
    await _pumpHome(tester);
    expect(find.text('What should we call you?'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('nameField')), 'imran khan');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Hi, Imran'), findsOneWidget);
    expect(find.text('What should we call you?'), findsNothing);
  });

  testWidgets('welcome prompt is skippable and falls back to Hi there',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.instance.setCatalogIds(['0']);
    await LocalStore.instance.setLastSyncedAt(DateTime.now());
    await _pumpHome(tester);
    expect(find.text('What should we call you?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('skipNameButton')));
    await tester.pumpAndSettle();
    expect(find.text('Hi there'), findsOneWidget);
    expect(find.text('What should we call you?'), findsNothing);
  });

  testWidgets('saving a recipe without a name asks gently, then still saves',
      (tester) async {
    await LocalStore.instance.setCatalogIds(['0', '1', '2']);
    await LocalStore.instance.setLastSyncedAt(DateTime.now());
    await _pumpHome(tester);
    expect(find.text('Want to add your name?'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Save recipe').first);
    await tester.pumpAndSettle();
    expect(find.text('Want to add your name?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('skipNameButton')));
    await tester.pumpAndSettle();
    expect(find.text('Want to add your name?'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Saved'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Fake Recipe 0'), findsWidgets);
  });

  testWidgets('profile can edit and clear the name', (tester) async {
    SharedPreferences.setMockInitialValues({
      kNamePromptShownKey: true,
      kDisplayNameKey: 'Sammy',
    });
    await LocalStore.instance.setCatalogIds(['0']);
    await LocalStore.instance.setLastSyncedAt(DateTime.now());
    await _pumpHome(tester);
    expect(find.text('Hi, Sammy'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Edit name'), findsOneWidget);

    await tester.tap(find.byKey(const Key('editNameTile')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nameField')), 'imran');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Hi, Imran'), findsWidgets);

    await tester.tap(find.byKey(const Key('clearNameTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear name').last);
    await tester.pumpAndSettle();
    expect(find.text('Add your name'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Hi there'), findsOneWidget);
  });
}
