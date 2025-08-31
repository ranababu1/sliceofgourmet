import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

class Recipe {
  final String id;
  final String title;
  final String excerpt;
  final String content; // HTML
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

  static Recipe fromJson(Map<String, dynamic> json) => Recipe(
        id: '${json['id']}',
        title: (json['title'] ?? '') as String,
        excerpt: (json['excerpt'] ?? '') as String,
        content: (json['content'] ?? '') as String,
        imageUrl: (json['imageUrl'] ?? '') as String,
        category: json['category'] == null ? null : json['category'] as String,
        cookTimeMinutes: (json['cookTimeMinutes'] ?? 0) as int,
        ingredients:
            (json['ingredients'] as List?)?.map((e) => '$e').toList() ??
                const [],
        instructions:
            (json['instructions'] as List?)?.map((e) => '$e').toList() ??
                const [],
      );

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();
  }

  static List<String> _extractBySelectors(
      dom.Document doc, List<String> selectors) {
    for (final sel in selectors) {
      final nodes = doc.querySelectorAll(sel);
      if (nodes.isNotEmpty) {
        return nodes
            .map((e) => e.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }

  static int _extractCookTime(dom.Document doc) {
    final candidates = <String>[
      '.wprm-recipe-total_time',
      '.wprm-recipe-cook_time',
      '[itemprop="totalTime"]',
      '[itemprop="cookTime"]',
    ];
    for (final sel in candidates) {
      final el = doc.querySelector(sel);
      if (el != null) {
        final text = el.text.toLowerCase().replaceAll(RegExp(r'[^0-9]'), '');
        if (text.isNotEmpty) {
          final n = int.tryParse(text);
          if (n != null && n > 0) return n;
        }
      }
    }
    return 20;
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

    final doc = html_parser.parse(contentHtml);

    final ingredients = _extractBySelectors(doc, <String>[
      '.wprm-recipe-ingredients-container .wprm-recipe-ingredient',
      '.wprm-recipe-ingredients .wprm-recipe-ingredient',
      '.wprm-recipe-ingredient',
      '.recipe-ingredients li',
      'ul.ingredients li',
    ]);

    final instructions = _extractBySelectors(doc, <String>[
      '.wprm-recipe-instructions-container .wprm-recipe-instruction',
      '.wprm-recipe-instructions .wprm-recipe-instruction',
      '.wprm-recipe-instruction',
      '.recipe-instructions li',
      'ol.instructions li',
      'ol li',
    ]);

    final cookMins = _extractCookTime(doc);

    return Recipe(
      id: '${j['id']}',
      title: _stripHtml(title),
      excerpt: _stripHtml(excerptHtml),
      content: contentHtml,
      imageUrl: image,
      category: catName,
      cookTimeMinutes: cookMins,
      ingredients: ingredients,
      instructions: instructions,
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
