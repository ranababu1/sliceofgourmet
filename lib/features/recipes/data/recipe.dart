class Recipe {
  final String id; // we will use WP post id as string
  final String title;
  final String excerpt;
  final String content; // HTML or plaintext
  final String imageUrl;
  final String? category;
  final int cookTimeMinutes;
  final List<String> ingredients;
  final List<String> instructions;

  Recipe({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.imageUrl,
    this.category,
    required this.cookTimeMinutes,
    required this.ingredients,
    required this.instructions,
  });

  // When we wire WordPress, we will add fromWpJson factory
}
