import 'package:html/parser.dart' as html_parser;

/// Typed models for the sog/v1 REST API served by the sog-recipes plugin.
///
/// [Recipe] is the light list item (`recipe_card`), [RecipeDetail] the full
/// recipe from `GET /wp-json/sog/v1/recipes/{id}`. Both serialise back to the
/// exact server shape, so the local cache is parsed by the same code as the
/// network response.

int _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? 0;
  return 0;
}

String _str(Object? v) => v == null ? '' : '$v';

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];

/// Decodes entities and strips tags from short API strings.
String plainText(String s) {
  if (s.isEmpty || !(s.contains('<') || s.contains('&'))) return s.trim();
  return (html_parser.parseFragment(s).text ?? '')
      .replaceAll('\u00a0', ' ')
      .trim();
}

/// "1 hr 5 min", or null when the value is missing or zero.
String? formatMinutes(int minutes) {
  if (minutes <= 0) return null;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h hr';
  return '$h hr $m min';
}

/// Compact form for small badges: "45m", "1h 5m", or null.
String? formatMinutesShort(int minutes) {
  if (minutes <= 0) return null;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

class RecipeTerm {
  const RecipeTerm({required this.id, required this.name, required this.slug});
  final int id;
  final String name;
  final String slug;

  factory RecipeTerm.fromJson(Map<String, dynamic> j) => RecipeTerm(
        id: _int(j['id']),
        name: plainText(_str(j['name'])),
        slug: _str(j['slug']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'slug': slug};
}

class RecipeImageSize {
  const RecipeImageSize(this.url, this.width, this.height);
  final String url;
  final int width;
  final int height;
}

class RecipeImage {
  const RecipeImage({
    required this.id,
    required this.url,
    this.width = 0,
    this.height = 0,
    this.thumbUrl = '',
    this.alt = '',
    this.sizes = const {},
  });

  final int id;
  final String url;
  final int width;
  final int height;
  final String thumbUrl;
  final String alt;
  final Map<String, RecipeImageSize> sizes;

  /// Null when the API sent no usable image.
  static RecipeImage? tryParse(Object? v) {
    final j = _map(v);
    final url = _str(j['url']);
    if (url.isEmpty) return null;
    final sizes = <String, RecipeImageSize>{};
    _map(j['sizes']).forEach((k, s) {
      final m = _map(s);
      final u = _str(m['url']);
      if (u.isNotEmpty) {
        sizes[k] = RecipeImageSize(u, _int(m['width']), _int(m['height']));
      }
    });
    return RecipeImage(
      id: _int(j['id']),
      url: url,
      width: _int(j['width']),
      height: _int(j['height']),
      thumbUrl: _str(j['thumb_url']),
      alt: _str(j['alt']),
      sizes: sizes,
    );
  }

  /// Best URL for a list thumbnail.
  String get smallUrl {
    if (thumbUrl.isNotEmpty) return thumbUrl;
    return sizes['medium_large']?.url ?? sizes['medium']?.url ?? url;
  }

  /// Best URL for a full width hero, avoiding multi-megapixel originals.
  String get heroUrl =>
      sizes['large']?.url ?? sizes['medium_large']?.url ?? url;

  /// URL at least [px] physical pixels wide. Images are served by the
  /// Jetpack Photon CDN (i0.wp.com), which resizes on its edge, so the WP
  /// server never sees image traffic. Widths snap to a few buckets so
  /// every device asks for the same cached files.
  String urlFor(double px) => photonResize(url, _bucket(px));

  static int _bucket(double px) {
    for (final b in const [320, 480, 720, 1080]) {
      if (px <= b) return b;
    }
    return 1440;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'width': width,
        'height': height,
        if (thumbUrl.isNotEmpty) 'thumb_url': thumbUrl,
        if (alt.isNotEmpty) 'alt': alt,
        if (sizes.isNotEmpty)
          'sizes': sizes.map((k, s) => MapEntry(
              k, {'url': s.url, 'width': s.width, 'height': s.height})),
      };
}

/// Photon URL resized to [width] px wide; other URLs are returned as is.
String photonResize(String url, int width) {
  final u = Uri.tryParse(url);
  if (u == null || !RegExp(r'^i[0-3]\.wp\.com$').hasMatch(u.host)) return url;
  final q = Map<String, String>.from(u.queryParameters)
    ..remove('fit')
    ..remove('resize')
    ..remove('h')
    ..['w'] = '$width';
  return u.replace(queryParameters: q).toString();
}

/// List item: post fields plus the light `recipe_card`.
class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    this.slug = '',
    this.link = '',
    this.excerpt = '',
    this.dateGmt,
    this.modifiedGmt,
    this.categories = const [],
    this.image,
    this.prepMin = 0,
    this.cookMin = 0,
    this.totalMin = 0,
    this.servings = 0,
    this.servingsUnit = '',
    this.yieldText = '',
    this.difficulty = '',
    this.calories = 0,
    this.cuisine = const [],
    this.diet = const [],
    this.ingredientCount = 0,
    this.stepCount = 0,
  });

  /// WordPress post ID as a string (route param and bookmark key).
  final String id;
  final String title;
  final String slug;

  /// Canonical, category based permalink. Use for share and deep links.
  final String link;
  final String excerpt;
  final DateTime? dateGmt;
  final DateTime? modifiedGmt;
  final List<RecipeTerm> categories;
  final RecipeImage? image;
  final int prepMin;
  final int cookMin;
  final int totalMin;
  final int servings;
  final String servingsUnit;
  final String yieldText;
  final String difficulty;
  final int calories;
  final List<String> cuisine;
  final List<String> diet;
  final int ingredientCount;
  final int stepCount;

  int get postId => int.tryParse(id) ?? 0;

  /// Card sized image URL, empty when the recipe has no photo.
  String get imageUrl => image?.heroUrl ?? '';

  /// Image URL for a box [logicalWidth] wide on a [dpr] screen.
  String imageFor(double logicalWidth, double dpr) =>
      image?.urlFor(logicalWidth * dpr) ?? '';

  /// First category name for chips, skipping the "Featured" bucket.
  String? get category {
    final usable =
        categories.where((c) => c.slug != 'featured' && c.name.isNotEmpty);
    return usable.isEmpty ? null : usable.first.name;
  }

  /// Total time if known, else cook time, else 0 (unknown).
  int get displayMinutes => totalMin > 0 ? totalMin : cookMin;

  /// "4 servings", "4 people", "about 2 cups", or null.
  String? get servingsLabel {
    if (servings > 0) {
      final unit = servingsUnit.trim().isNotEmpty
          ? servingsUnit.trim()
          : (servings == 1 ? 'serving' : 'servings');
      return '$servings $unit';
    }
    return yieldText.trim().isEmpty ? null : yieldText.trim();
  }

  String? get caloriesLabel => calories > 0 ? '$calories kcal' : null;

  String? get difficultyLabel => difficulty.isEmpty
      ? null
      : difficulty[0].toUpperCase() + difficulty.substring(1);

  factory Recipe.fromJson(Map<String, dynamic> j) {
    final c = _map(j['recipe_card']);
    return Recipe(
      id: _str(j['id']),
      title: plainText(_str(j['title'])),
      slug: _str(j['slug']),
      link: _str(j['link']),
      excerpt: plainText(_str(j['excerpt'])),
      dateGmt: _date(j['date_gmt']),
      modifiedGmt: _date(j['modified_gmt']),
      categories: _maps(j['categories']).map(RecipeTerm.fromJson).toList(),
      image: RecipeImage.tryParse(c['image']),
      prepMin: _int(c['prep_min']),
      cookMin: _int(c['cook_min']),
      totalMin: _int(c['total_min']),
      servings: _int(c['servings']),
      servingsUnit: _str(c['servings_unit']),
      yieldText: _str(c['yield']),
      difficulty: _str(c['difficulty']),
      calories: _int(c['calories']),
      cuisine: _names(c['cuisine']),
      diet: _names(c['diet']),
      ingredientCount: _int(c['ingredient_count']),
      stepCount: _int(c['step_count']),
    );
  }

  Map<String, dynamic> toJson() => {
        ..._postJson(),
        'recipe_card': {
          'has_recipe': true,
          'prep_min': prepMin,
          'cook_min': cookMin,
          'total_min': totalMin,
          'servings': servings,
          'servings_unit': servingsUnit,
          'yield': yieldText,
          'difficulty': difficulty,
          'calories': calories,
          'cuisine': cuisine,
          'diet': diet,
          'ingredient_count': ingredientCount,
          'step_count': stepCount,
          'image': image?.toJson(),
        },
      };

  Map<String, dynamic> _postJson() => {
        'id': postId,
        'title': title,
        'slug': slug,
        'link': link,
        'date_gmt': dateGmt == null ? null : _fmtDate(dateGmt!),
        'modified_gmt': modifiedGmt == null ? null : _fmtDate(modifiedGmt!),
        'excerpt': excerpt,
        'categories': categories.map((e) => e.toJson()).toList(),
      };

  static DateTime? _date(Object? v) {
    final s = _str(v);
    if (s.isEmpty) return null;
    // API sends GMT without an offset.
    return DateTime.tryParse(s.endsWith('Z') || s.contains('+') ? s : '${s}Z');
  }

  static String _fmtDate(DateTime d) =>
      d.toUtc().toIso8601String().split('.').first;

  static List<String> _names(Object? v) {
    if (v is! List) return const [];
    return v
        .map((e) => e is Map ? _str(e['name']) : _str(e))
        .map(plainText)
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

class Ingredient {
  const Ingredient({
    this.amount = '',
    this.unit = '',
    this.name = '',
    this.notes = '',
    this.text = '',
  });

  final String amount;
  final String unit;
  final String name;
  final String notes;
  final String text;

  /// Display line, e.g. "2 cups aataa, whole wheat chapatti flour".
  String get display {
    final t = plainText(text);
    if (t.isNotEmpty) return t;
    final main = [amount, unit, name]
        .map((e) => plainText(e))
        .where((e) => e.isNotEmpty)
        .join(' ');
    final n = plainText(notes);
    return n.isEmpty ? main : '$main, $n';
  }

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        amount: _str(j['amount']),
        unit: _str(j['unit']),
        name: _str(j['name']),
        notes: _str(j['notes']),
        text: _str(j['text']),
      );

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'unit': unit,
        'name': name,
        'notes': notes,
        'text': text,
      };
}

class IngredientGroup {
  const IngredientGroup({this.title = '', this.items = const []});
  final String title;
  final List<Ingredient> items;

  factory IngredientGroup.fromJson(Map<String, dynamic> j) => IngredientGroup(
        title: plainText(_str(j['title'])),
        items: _maps(j['items'])
            .map(Ingredient.fromJson)
            .where((i) => i.display.isNotEmpty)
            .toList(),
      );

  Map<String, dynamic> toJson() =>
      {'title': title, 'items': items.map((e) => e.toJson()).toList()};
}

class InstructionStep {
  const InstructionStep({required this.text, this.image});
  final String text;
  final RecipeImage? image;

  factory InstructionStep.fromJson(Map<String, dynamic> j) {
    final plain = _str(j['text_plain']);
    return InstructionStep(
      text: plain.isNotEmpty ? plain.trim() : plainText(_str(j['text'])),
      image: RecipeImage.tryParse(j['image']),
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'text_plain': text,
        'image_id': image?.id ?? 0,
        'image': image?.toJson(),
      };
}

class InstructionGroup {
  const InstructionGroup({this.title = '', this.steps = const []});
  final String title;
  final List<InstructionStep> steps;

  factory InstructionGroup.fromJson(Map<String, dynamic> j) => InstructionGroup(
        title: plainText(_str(j['title'])),
        steps: _maps(j['steps'])
            .map(InstructionStep.fromJson)
            .where((s) => s.text.isNotEmpty || s.image != null)
            .toList(),
      );

  Map<String, dynamic> toJson() =>
      {'title': title, 'steps': steps.map((e) => e.toJson()).toList()};
}

/// Full recipe from `GET sog/v1/recipes/{id}` (the `recipe` object).
class RecipeDetail extends Recipe {
  const RecipeDetail({
    required super.id,
    required super.title,
    super.slug,
    super.link,
    super.excerpt,
    super.dateGmt,
    super.modifiedGmt,
    super.categories,
    super.image,
    super.prepMin,
    super.cookMin,
    super.totalMin,
    super.servings,
    super.servingsUnit,
    super.yieldText,
    super.difficulty,
    super.calories,
    super.cuisine,
    super.diet,
    super.ingredientCount,
    super.stepCount,
    this.summary = '',
    this.cookName = defaultCookName,
    this.restMin = 0,
    this.ingredientGroups = const [],
    this.instructionGroups = const [],
    this.notes = '',
    this.videoUrl = '',
    this.printUrl = '',
  });

  static const defaultCookName = 'Sammy';

  /// Plain text summary (may be empty).
  final String summary;

  /// Byline. The site's cook name, never the WordPress author.
  final String cookName;
  final int restMin;
  final List<IngredientGroup> ingredientGroups;
  final List<InstructionGroup> instructionGroups;

  /// Plain text recipe notes (may be empty).
  final String notes;
  final String videoUrl;
  final String printUrl;

  bool get hasIngredients => ingredientGroups.any((g) => g.items.isNotEmpty);
  bool get hasInstructions => instructionGroups.any((g) => g.steps.isNotEmpty);

  /// Summary, or the post excerpt when the recipe has none.
  String get intro => summary.isNotEmpty ? summary : excerpt;

  factory RecipeDetail.fromJson(Map<String, dynamic> j) {
    final r = _map(j['recipe']);
    final ing = _maps(r['ingredients']).map(IngredientGroup.fromJson).toList();
    final ins =
        _maps(r['instructions']).map(InstructionGroup.fromJson).toList();
    final cook = plainText(_str(r['author_name'] ?? r['cook_name']));
    final summaryPlain = _str(r['summary_plain']);
    final title = plainText(_str(j['title']));
    return RecipeDetail(
      id: _str(j['id']),
      title: title.isNotEmpty ? title : plainText(_str(r['name'])),
      slug: _str(j['slug']),
      link: _str(j['link']),
      excerpt: plainText(_str(j['excerpt'])),
      dateGmt: Recipe._date(j['date_gmt']),
      modifiedGmt: Recipe._date(j['modified_gmt']),
      categories: _maps(j['categories']).map(RecipeTerm.fromJson).toList(),
      image: RecipeImage.tryParse(r['image']),
      prepMin: _int(r['prep_min']),
      cookMin: _int(r['cook_min']),
      restMin: _int(r['rest_min']),
      totalMin: _int(r['total_min']),
      servings: _int(r['servings']),
      servingsUnit: _str(r['servings_unit']),
      yieldText: _str(r['yield']),
      difficulty: _str(r['difficulty']),
      calories: _int(r['calories']),
      cuisine: Recipe._names(r['cuisine']),
      diet: Recipe._names(r['diet']),
      ingredientCount: ing.fold(0, (n, g) => n + g.items.length),
      stepCount: ins.fold(0, (n, g) => n + g.steps.length),
      summary: summaryPlain.isNotEmpty
          ? summaryPlain.trim()
          : plainText(_str(r['summary'])),
      cookName: cook.isEmpty ? defaultCookName : cook,
      ingredientGroups: ing.where((g) => g.items.isNotEmpty).toList(),
      instructionGroups: ins.where((g) => g.steps.isNotEmpty).toList(),
      notes: plainText(_str(r['notes'])),
      videoUrl: _str(r['video_url']),
      printUrl: _str(r['print_url']),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ..._postJson(),
        'recipe': {
          'name': title,
          'summary': summary,
          'summary_plain': summary,
          'author_name': cookName,
          'image': image?.toJson(),
          'prep_min': prepMin,
          'cook_min': cookMin,
          'rest_min': restMin,
          'total_min': totalMin,
          'servings': servings,
          'servings_unit': servingsUnit,
          'yield': yieldText,
          'difficulty': difficulty,
          'calories': calories,
          'cuisine': cuisine.map((n) => {'name': n}).toList(),
          'diet': diet.map((n) => {'name': n}).toList(),
          'ingredients': ingredientGroups.map((e) => e.toJson()).toList(),
          'instructions': instructionGroups.map((e) => e.toJson()).toList(),
          'notes': notes,
          'video_url': videoUrl,
          'print_url': printUrl,
        },
      };
}
