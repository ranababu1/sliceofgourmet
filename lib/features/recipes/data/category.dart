class RecipeCategory {
  final int id;
  final String name;
  final int count;

  const RecipeCategory({
    required this.id,
    required this.name,
    required this.count,
  });

  factory RecipeCategory.fromJson(Map<String, dynamic> j) => RecipeCategory(
    id: (j['id'] ?? 0) as int,
    name: (j['name'] ?? '').toString(),
    count: (j['count'] ?? 0) as int,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'count': count};
}
