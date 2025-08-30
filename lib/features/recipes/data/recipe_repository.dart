import 'recipe.dart';

abstract class RecipeRepository {
  Future<List<Recipe>> fetchLatest({int page = 1, int pageSize = 20});
  Future<List<Recipe>> fetchTrending({int limit = 10});
  Future<Recipe> fetchById(String id);
  Future<List<String>> fetchCategories();
  Future<List<Recipe>> search(String query, {int page = 1, int pageSize = 20});
  Future<List<Recipe>> fetchByCategory(
    String category, {
    int page = 1,
    int pageSize = 20,
  });
}

/// Mock repository remains useful for tests.
class MockRecipeRepository implements RecipeRepository {
  final List<Recipe> _items = List.generate(24, (i) {
    final id = (i + 1).toString();
    final cats = ['Breakfast', 'Lunch', 'Dinner', 'Dessert', 'Snacks'];
    final cat = cats[i % cats.length];
    return Recipe(
      id: id,
      title: 'Delicious $cat Recipe $id',
      excerpt:
          'A short teaser for ${cat.toLowerCase()} recipe $id, quick and tasty.',
      content:
          'Step by step details for recipe $id. Replace with WP content later.',
      imageUrl: 'https://picsum.photos/seed/recipe_$id/800/500',
      category: cat,
      cookTimeMinutes: 10 + (i % 5) * 5,
      ingredients: ['Ingredient A', 'Ingredient B', 'Ingredient C'],
      instructions: ['Prep ingredients', 'Cook properly', 'Serve hot'],
    );
  });

  @override
  Future<List<Recipe>> fetchLatest({int page = 1, int pageSize = 20}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final start = (page - 1) * pageSize;
    final end = (start + pageSize) > _items.length
        ? _items.length
        : (start + pageSize);
    if (start >= _items.length) return [];
    return _items.sublist(start, end);
  }

  @override
  Future<List<Recipe>> fetchTrending({int limit = 10}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _items.take(limit).toList();
  }

  @override
  Future<Recipe> fetchById(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _items.firstWhere((e) => e.id == id);
  }

  @override
  Future<List<String>> fetchCategories() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return ['Breakfast', 'Lunch', 'Dinner', 'Dessert', 'Snacks'];
  }

  @override
  Future<List<Recipe>> search(
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final q = query.toLowerCase();
    final filtered = _items
        .where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              (e.category ?? '').toLowerCase().contains(q),
        )
        .toList();
    final start = (page - 1) * pageSize;
    final end = (start + pageSize) > filtered.length
        ? filtered.length
        : (start + pageSize);
    if (start >= filtered.length) return [];
    return filtered.sublist(start, end);
  }

  @override
  Future<List<Recipe>> fetchByCategory(
    String category, {
    int page = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final filtered = _items.where((e) => e.category == category).toList();
    final start = (page - 1) * pageSize;
    final end = (start + pageSize) > filtered.length
        ? filtered.length
        : (start + pageSize);
    if (start >= filtered.length) return [];
    return filtered.sublist(start, end);
  }
}
