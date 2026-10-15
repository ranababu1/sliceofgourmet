import 'package:sliceofgourmet/core/auth/app_user.dart';
import 'package:sliceofgourmet/core/auth/auth_repository.dart';
import 'package:sliceofgourmet/features/recipes/data/category.dart';
import 'package:sliceofgourmet/features/recipes/data/recipe.dart';
import 'package:sliceofgourmet/features/recipes/data/recipe_repository.dart';

Recipe fakeRecipe(int i) => Recipe(
      id: '$i',
      title: 'Fake Recipe $i',
      excerpt: 'excerpt $i',
      content: '<p>Body $i</p>',
      imageUrl: '', // no network images in tests
      category: 'Dinner',
      cookTimeMinutes: 10,
      ingredients: const ['salt'],
      instructions: const ['cook'],
    );

/// Records forceRefresh flags; no network.
class FakeRecipeRepository implements RecipeRepository {
  final forceFlags = <String, bool>{};
  Set<String> failingIds = {};

  @override
  Future<Recipe> fetchById(String id, {bool forceRefresh = false}) async {
    if (failingIds.contains(id)) throw Exception('gone');
    return fakeRecipe(int.parse(id));
  }

  @override
  Future<List<RecipeCategory>> fetchCategories(
      {bool forceRefresh = false}) async {
    forceFlags['categories'] = forceRefresh;
    return const [RecipeCategory(id: 1, name: 'Dinner', count: 3)];
  }

  @override
  Future<List<Recipe>> fetchLatest(
      {int page = 1, int pageSize = 20, bool forceRefresh = false}) async {
    forceFlags['latest'] = forceRefresh;
    return List.generate(3, fakeRecipe);
  }

  @override
  Future<List<Recipe>> fetchTrending(
      {int limit = 10, bool forceRefresh = false}) async {
    forceFlags['trending'] = forceRefresh;
    return List.generate(2, fakeRecipe);
  }

  @override
  Future<List<Recipe>> search(String query,
          {int page = 1, int pageSize = 20}) async =>
      [];

  @override
  Future<List<Recipe>> fetchByCategory(int categoryId,
          {int page = 1, int pageSize = 20}) async =>
      [];
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user});
  AppUser? user;

  @override
  Future<AppUser?> getCurrentUser() async => user;

  @override
  Future<AppUser?> signInWithGoogle() async => user;

  @override
  Future<void> signOut() async => user = null;
}
