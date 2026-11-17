import 'recipe.dart' show plainText;

class RecipeCategory {
  final int id;
  final String name;
  final String slug;
  final int count;
  final int parent;

  const RecipeCategory({
    required this.id,
    required this.name,
    required this.count,
    this.slug = '',
    this.parent = 0,
  });

  factory RecipeCategory.fromJson(Map<String, dynamic> j) => RecipeCategory(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: plainText((j['name'] ?? '').toString()),
        slug: (j['slug'] ?? '').toString(),
        count: (j['count'] as num?)?.toInt() ?? 0,
        parent: (j['parent'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'slug': slug, 'count': count, 'parent': parent};
}
