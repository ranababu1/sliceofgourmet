import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliceofgourmet/core/cache/local_store.dart';
import 'package:sliceofgourmet/features/recipes/data/recipe.dart';
import 'package:sliceofgourmet/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:sliceofgourmet/features/recipes/providers.dart';

import 'fakes.dart';
import 'fixture.dart';

class _FixtureRepo extends FakeRecipeRepository {
  @override
  Future<RecipeDetail> fetchById(String id,
          {bool forceRefresh = false}) async =>
      RecipeDetail.fromJson(fixtureMap('recipe_$id.json'));
}

Future<void> _pump(WidgetTester tester, String id) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [recipeRepositoryProvider.overrideWithValue(_FixtureRepo())],
    child: MaterialApp(home: RecipeDetailScreen(recipeId: id)),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('sog_detail').path);
    await LocalStore.init();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sparse recipe hides 0 min, 0 kcal and the missing photo',
      (tester) async {
    await _pump(tester, '1931'); // no photo, no summary
    expect(find.text('By Sammy'), findsOneWidget);
    expect(find.textContaining('kcal'), findsNothing);
    expect(find.textContaining(RegExp(r'^0 ')), findsNothing);
    expect(find.byIcon(Icons.restaurant_menu_rounded), findsNothing);
    expect(find.text('Ingredients'), findsOneWidget);
  });

  testWidgets('cook time 0 is not shown', (tester) async {
    await _pump(tester, '2623');
    expect(find.text('Cook'), findsNothing);
    expect(find.text('Prep'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^0 ')), findsNothing);
  });

  testWidgets('complete recipe shows groups, times and share', (tester) async {
    await _pump(tester, '2640');
    await tester.scrollUntilVisible(find.text('For the paratha'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('For the paratha'), findsOneWidget);
    expect(find.byTooltip('Share'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
  });
}
