import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliceofgourmet/app.dart';
import 'package:sliceofgourmet/core/auth/auth_providers.dart';
import 'package:sliceofgourmet/core/cache/local_store.dart';
import 'package:sliceofgourmet/features/recipes/providers.dart';

import 'fakes.dart';

void main() {
  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('sog_widget').path);
    await LocalStore.init();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('app builds and shows home content', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        recipeRepositoryProvider.overrideWithValue(FakeRecipeRepository()),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
      child: const SliceOfGourmetApp(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('What do you want to cook today?'), findsOneWidget);
    expect(find.text('Fake Recipe 0'), findsWidgets);
  });
}
