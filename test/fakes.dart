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

/// No network.
class FakeRecipeRepository implements RecipeRepository {
  Set<String> failingIds = {};
  Set<String> goneIds = {};

  @override
  Future<RecipeDetail> fetchById(String id) async {
    if (goneIds.contains(id)) throw RecipeNotFoundException(id);
    if (failingIds.contains(id)) throw Exception('offline');
    return fakeRecipe(int.parse(id));
  }

  @override
  Future<List<RecipeCategory>> fetchCategories() async =>
      const [RecipeCategory(id: 1, name: 'Dinner', count: 3)];

  @override
  Future<List<Recipe>> fetchLatest({int limit = 20}) async =>
      List.generate(3, fakeRecipe);

  @override
  Future<List<Recipe>> fetchTrending({int limit = 10}) async =>
      List.generate(2, fakeRecipe);

  @override
  Future<List<Recipe>> search(String query) async => [];

  @override
  Future<List<Recipe>> fetchByCategory(int categoryId) async => [];

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
