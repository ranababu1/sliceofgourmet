import 'recipe.dart';
import 'category.dart';

abstract class RecipeRepository {
  Future<List<Recipe>> fetchLatest({int page = 1, int pageSize = 20});
  Future<List<Recipe>> fetchTrending({int limit = 10});
  Future<Recipe> fetchById(String id);
  Future<List<RecipeCategory>> fetchCategories();
  Future<List<Recipe>> search(String query, {int page = 1, int pageSize = 20});
  Future<List<Recipe>> fetchByCategory(int categoryId,
      {int page = 1, int pageSize = 20});
}

/// Simple in memory mock for tests and previews
class MockRecipeRepository implements RecipeRepository {
  final List<Recipe> _items = List.generate(
    10,
    (i) => Recipe(
      id: '$i',
      title: 'Sample Recipe $i',
      excerpt: 'Tasty sample $i',
      content: '<p>Mock content</p>',
      imageUrl: 'https://picsum.photos/seed/mock$i/800/600',
      category: i.isEven ? 'Dinner' : 'Lunch',
      cookTimeMinutes: 20 + i,
      ingredients: const ['1 cup flour', '2 eggs', 'Salt to taste'],
      instructions: const ['Mix ingredients', 'Cook until done', 'Serve hot'],
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
  Future<Recipe> fetchById(String id) async {
    return _items.firstWhere((e) => e.id == id, orElse: () => _items.first);
  }

  @override
  Future<List<Recipe>> fetchLatest({int page = 1, int pageSize = 20}) async {
    return _items;
  }

  @override
  Future<List<Recipe>> fetchTrending({int limit = 10}) async {
    return _items.take(limit).toList();
  }

  @override
  Future<List<RecipeCategory>> fetchCategories() async {
    return _cats..sort((a, b) => b.count.compareTo(a.count));
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
    // mock maps odd ids to Lunch, even to Dinner
    final name = categoryId.isEven ? 'Dinner' : 'Lunch';
    return _items.where((e) => e.category == name).toList();
  }
}
