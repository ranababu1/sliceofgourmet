import 'recipe.dart';
import 'category.dart';

/// Read side of the recipe data. The WordPress implementation answers from
/// the on-device catalog that `RecipeSync` keeps fresh, so these calls do
/// not touch the network once the first sync has run (except opening a
/// full recipe the first time, or after it changed on the site).
abstract class RecipeRepository {
  Future<List<Recipe>> fetchLatest({int limit = 20});
  Future<List<Recipe>> fetchTrending({int limit = 10});

  /// Full recipe. Throws `RecipeNotFoundException` when it no longer exists.
  Future<RecipeDetail> fetchById(String id);
  Future<List<RecipeCategory>> fetchCategories();
  Future<List<Recipe>> search(String query);
  Future<List<Recipe>> fetchByCategory(int categoryId);

  /// Post id for a sliceofgourmet.com permalink, or null.
  Future<String?> resolveLink(Uri link);
}

/// Simple in memory mock for previews.
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
    RecipeCategory(id: 2, name: 'Lunch', count: 5),
    RecipeCategory(id: 3, name: 'Dinner', count: 5),
  ];

  @override
  Future<RecipeDetail> fetchById(String id) async =>
      _items.firstWhere((e) => e.id == id, orElse: () => _items.first);

  @override
  Future<List<Recipe>> fetchLatest({int limit = 20}) async =>
      _items.take(limit).toList();

  @override
  Future<List<Recipe>> fetchTrending({int limit = 10}) async =>
      _items.take(limit).toList();

  @override
  Future<List<RecipeCategory>> fetchCategories() async => _cats;

  @override
  Future<List<Recipe>> search(String query) async {
    final q = query.toLowerCase();
    return _items.where((e) => e.title.toLowerCase().contains(q)).toList();
  }

  @override
  Future<List<Recipe>> fetchByCategory(int categoryId) async => _items
      .where((e) => e.categories.any((c) => c.id == categoryId))
      .toList();

  @override
  Future<String?> resolveLink(Uri link) async {
    final slug = link.pathSegments.where((s) => s.isNotEmpty).lastOrNull;
    return _items.where((e) => e.slug == slug).firstOrNull?.id;
  }
}
