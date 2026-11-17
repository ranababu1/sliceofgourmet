import 'package:sliceofgourmet/core/auth/app_user.dart';
import 'package:sliceofgourmet/core/auth/auth_repository.dart';
import 'package:sliceofgourmet/features/recipes/data/category.dart';
import 'package:sliceofgourmet/features/recipes/data/recipe.dart';
import 'package:sliceofgourmet/features/recipes/data/recipe_repository.dart';
import 'package:sliceofgourmet/features/recipes/data/wordpress_api.dart';

RecipeDetail fakeRecipe(int i) => RecipeDetail(
      id: '$i',
      title: 'Fake Recipe $i',
      excerpt: 'excerpt $i',
      link: 'https://sliceofgourmet.com/dinner/fake-recipe-$i/',
      // no image: no network images in tests
      categories: const [RecipeTerm(id: 1, name: 'Dinner', slug: 'dinner')],
      cookMin: 10,
      ingredientGroups: const [
        IngredientGroup(items: [Ingredient(name: 'salt')])
      ],
      instructionGroups: const [
        InstructionGroup(steps: [InstructionStep(text: 'cook')])
      ],
    );

/// Records forceRefresh flags; no network.
class FakeRecipeRepository implements RecipeRepository {
  final forceFlags = <String, bool>{};
  Set<String> failingIds = {};
  Set<String> goneIds = {};

  @override
  Future<RecipeDetail> fetchById(String id, {bool forceRefresh = false}) async {
    if (goneIds.contains(id)) throw RecipeNotFoundException(id);
    if (failingIds.contains(id)) throw Exception('offline');
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

  @override
  Future<String?> resolveLink(Uri link) async =>
      link.path.contains('fake-recipe-')
          ? link.pathSegments.where((s) => s.isNotEmpty).last.split('-').last
          : null;
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
