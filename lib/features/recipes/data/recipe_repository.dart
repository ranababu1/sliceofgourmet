import 'recipe.dart';
import 'category.dart';

/// Pass `forceRefresh: true` to bypass the local cache and hit the network
/// (cache is updated only on success).
abstract class RecipeRepository {
  Future<List<Recipe>> fetchLatest(
      {int page = 1, int pageSize = 20, bool forceRefresh = false});
  Future<List<Recipe>> fetchTrending(
      {int limit = 10, bool forceRefresh = false});

  /// Full recipe. Throws `RecipeNotFoundException` when it no longer exists.
  Future<RecipeDetail> fetchById(String id, {bool forceRefresh = false});
  Future<List<RecipeCategory>> fetchCategories({bool forceRefresh = false});
  Future<List<Recipe>> search(String query, {int page = 1, int pageSize = 20});
  Future<List<Recipe>> fetchByCategory(int categoryId,
      {int page = 1, int pageSize = 20});

  /// Post id for a sliceofgourmet.com permalink, or null.
  Future<String?> resolveLink(Uri link);
}

/// Simple in memory mock for tests and previews
class MockRecipeRepository implements RecipeRepository {
  final List<RecipeDetail> _items = List.generate(
    10,
    (i) => RecipeDetail(
      id: '$i',
      title: 'Sample Recipe $i',
      slug: 'sample-recipe-$i',
      link: 'https://sliceofgourmet.com/main-course/sample-recipe-$i/',
      excerpt: 'Tasty sample $i',
      categories: [
        i.isEven
            ? const RecipeTerm(id: 3, name: 'Dinner', slug: 'dinner')
            : const RecipeTerm(id: 2, name: 'Lunch', slug: 'lunch'),
      ],
      image:
          RecipeImage(id: i, url: 'https://picsum.photos/seed/mock$i/800/600'),
      cookMin: 20 + i,
      totalMin: 30 + i,
      servings: 4,
      ingredientGroups: const [
        IngredientGroup(items: [
          Ingredient(text: '1 cup flour'),
          Ingredient(text: '2 eggs'),
          Ingredient(text: 'Salt to taste'),
        ]),
      ],
      instructionGroups: const [
        InstructionGroup(steps: [
          InstructionStep(text: 'Mix ingredients'),
          InstructionStep(text: 'Cook until done'),
          InstructionStep(text: 'Serve hot'),
        ]),
      ],
    ),
  );

  final List<RecipeCategory> _cats = const [
    RecipeCategory(id: 1, name: 'Breakfast', count: 12),
    RecipeCategory(id: 2, name: 'Lunch', count: 20),
    RecipeCategory(id: 3, name: 'Dinner', count: 34),
    RecipeCategory(id: 4, name: 'Dessert', count: 18),
    RecipeCategory(id: 5, name: 'Snacks', count: 9),
  ];

  @override
  Future<RecipeDetail> fetchById(String id, {bool forceRefresh = false}) async {
    return _items.firstWhere((e) => e.id == id, orElse: () => _items.first);
  }

  @override
  Future<List<Recipe>> fetchLatest(
      {int page = 1, int pageSize = 20, bool forceRefresh = false}) async {
    return _items;
  }

  @override
  Future<List<Recipe>> fetchTrending(
      {int limit = 10, bool forceRefresh = false}) async {
    return _items.take(limit).toList();
  }

  @override
  Future<List<RecipeCategory>> fetchCategories(
      {bool forceRefresh = false}) async {
    return [..._cats]..sort((a, b) => b.count.compareTo(a.count));
  }

  @override
  Future<List<Recipe>> search(String query,
      {int page = 1, int pageSize = 20}) async {
    final q = query.toLowerCase();
    return _items.where((e) => e.title.toLowerCase().contains(q)).toList();
  }

  @override
  Future<List<Recipe>> fetchByCategory(int categoryId,
      {int page = 1, int pageSize = 20}) async {
    return _items
        .where((e) => e.categories.any((c) => c.id == categoryId))
        .toList();
  }

  @override
  Future<String?> resolveLink(Uri link) async {
    final slug = link.pathSegments.where((s) => s.isNotEmpty).lastOrNull;
    return _items.where((e) => e.slug == slug).firstOrNull?.id;
  }
}
