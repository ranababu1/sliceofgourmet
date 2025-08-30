import 'dart:convert';

class Recipe {
  final String id;
  final String title;
  final String excerpt;
  final String content; // can be HTML
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'excerpt': excerpt,
    'content': content,
    'imageUrl': imageUrl,
    'category': category,
    'cookTimeMinutes': cookTimeMinutes,
    'ingredients': ingredients,
    'instructions': instructions,
  };

  static Recipe fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: '${json['id']}',
      title: (json['title'] ?? '') as String,
      excerpt: (json['excerpt'] ?? '') as String,
      content: (json['content'] ?? '') as String,
      imageUrl: (json['imageUrl'] ?? '') as String,
      category: json['category'] == null ? null : json['category'] as String,
      cookTimeMinutes: (json['cookTimeMinutes'] ?? 0) as int,
      ingredients:
          (json['ingredients'] as List?)?.map((e) => '$e').toList() ?? const [],
      instructions:
          (json['instructions'] as List?)?.map((e) => '$e').toList() ??
          const [],
    );
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();
  }

  /// Build from WordPress post json with `_embed=1`
  static Recipe fromWpJson(Map<String, dynamic> j) {
    final embedded = j['_embedded'] as Map<String, dynamic>?;
    String image = '';
    String? catName;

    if (embedded != null) {
      final media = embedded['wp:featuredmedia'];
      if (media is List && media.isNotEmpty) {
        final first = media.first;
        if (first is Map) {
          image = (first['source_url'] ?? '').toString();
        }
      }
      final terms = embedded['wp:term'];
      if (terms is List && terms.isNotEmpty) {
        for (final group in terms) {
          if (group is List && group.isNotEmpty) {
            final first = group.first;
            if (first is Map && (first['taxonomy']?.toString() == 'category')) {
              catName = first['name']?.toString();
              break;
            }
          }
        }
      }
    }

    final title = j['title']?['rendered']?.toString() ?? '';
    final excerptHtml = j['excerpt']?['rendered']?.toString() ?? '';
    final contentHtml = j['content']?['rendered']?.toString() ?? '';

    return Recipe(
      id: '${j['id']}',
      title: _stripHtml(title),
      excerpt: _stripHtml(excerptHtml),
      content: contentHtml,
      imageUrl: image,
      category: catName,
      // if you add ACF for cook time later, map it here
      cookTimeMinutes: 20,
      // if you store ingredients and steps in ACF, map them later
      ingredients: const [],
      instructions: const [],
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
