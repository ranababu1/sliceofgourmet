import 'package:flutter_test/flutter_test.dart';
import 'package:sliceofgourmet/core/router.dart';
import 'package:sliceofgourmet/features/recipes/data/category.dart';
import 'package:sliceofgourmet/features/recipes/data/recipe.dart';
import 'package:sliceofgourmet/features/recipes/data/wordpress_repository.dart';
import 'package:sliceofgourmet/features/recipes/presentation/recipe_detail_screen.dart';

import 'fixture.dart';

void main() {
  group('Recipe card (sog/v1 list)', () {
    final items =
        fixtureList('recipes_list.json').map(Recipe.fromJson).toList();

    test('parses the complete Paya card', () {
      expect(items, hasLength(3));
      final r = items.first;
      expect(r.id, '3574');
      expect(r.postId, 3574);
      expect(r.title, 'Paya Instant Pot Recipe');
      expect(r.slug, 'paya-instant-pot-recipe');
      expect(r.link,
          'https://sliceofgourmet.com/side-dish/soups/paya-instant-pot-recipe/');
      expect(r.categories.map((c) => c.slug), ['side-dish', 'soups']);
      expect(r.category, 'Side Dish');
      expect(r.prepMin, 15);
      expect(r.cookMin, 50);
      expect(r.totalMin, 65);
      expect(r.displayMinutes, 65);
      expect(r.servingsLabel, '4 servings');
      expect(r.difficultyLabel, 'Medium');
      expect(r.cuisine, ['Pakistani']);
      expect(r.ingredientCount, 17);
      expect(r.stepCount, 8);
      expect(r.imageUrl, startsWith('https://'));
      expect(r.image!.thumbUrl, contains('mutton-paya'));
      expect(r.dateGmt, DateTime.utc(2026, 11, 7, 14, 31, 27));
    });

    test('hides empty fields on sparse recipes', () {
      final sparse = {
        for (final r in fixtureList('recipes_sparse.json').map(Recipe.fromJson))
          r.id: r
      };
      final noPhoto = sparse['1931']!;
      expect(noPhoto.image, isNull);
      expect(noPhoto.imageUrl, isEmpty);
      expect(noPhoto.excerpt, isEmpty);

      final noCook = sparse['2623']!;
      expect(noCook.cookMin, 0);
      expect(noCook.displayMinutes, 20);

      final yieldOnly = sparse['1127']!;
      expect(yieldOnly.servings, 0);
      expect(yieldOnly.servingsLabel, 'about 2 cups');

      for (final r in sparse.values) {
        expect(r.caloriesLabel, isNull, reason: 'calories are 0 on the site');
      }
    });

    test('round trips through the cache shape', () {
      for (final r in items) {
        final back = Recipe.fromJson(r.toJson());
        expect(back.id, r.id);
        expect(back.title, r.title);
        expect(back.link, r.link);
        expect(back.imageUrl, r.imageUrl);
        expect(back.totalMin, r.totalMin);
        expect(back.categories.map((c) => c.name),
            r.categories.map((c) => c.name));
        expect(back.dateGmt, r.dateGmt);
      }
    });

    test('featured list parses', () {
      final f = fixtureList('recipes_featured.json').map(Recipe.fromJson);
      expect(f, isNotEmpty);
      expect(f.every((r) => r.id.isNotEmpty && r.title.isNotEmpty), isTrue);
    });
  });

  group('RecipeDetail (sog/v1 full)', () {
    RecipeDetail load(int id) =>
        RecipeDetail.fromJson(fixtureMap('recipe_$id.json'));

    test('parses a complete recipe', () {
      final r = load(3574);
      expect(r.id, '3574');
      expect(r.title, 'Paya Instant Pot Recipe');
      expect(r.cookName, 'Sammy');
      expect(r.summary, startsWith('This recipe is my moms originally.'));
      expect(r.summary, isNot(contains('<p>')));
      expect(r.intro, r.summary);
      expect(r.image!.heroUrl, contains('720'));
      expect(r.ingredientGroups, hasLength(1));
      expect(r.ingredientGroups.single.items, hasLength(17));
      expect(
          r.ingredientGroups.single.items.first.display, '2.5 lbs mutton paya');
      expect(r.instructionGroups.single.steps, hasLength(8));
      expect(r.instructionGroups.single.steps.first.text,
          startsWith('Sauté the mutton paya'));
      expect(r.notes, isNot(contains('<')));
      expect(r.printUrl, endsWith('/print/'));
      expect(recipeTimes(r), [
        ('Prep', '15 min'),
        ('Cook', '50 min'),
        ('Total', '1 hr 5 min'),
      ]);
      expect(r.caloriesLabel, isNull);
      expect(recipeShareText(r),
          'Paya Instant Pot Recipe\nhttps://sliceofgourmet.com/side-dish/soups/paya-instant-pot-recipe/');
    });

    test('ingredient groups and notes', () {
      final r = load(2640);
      expect(r.ingredientGroups.map((g) => g.title),
          ['For the paratha', 'For the filling']);
      final aataa = r.ingredientGroups.first.items.first;
      expect(aataa.notes, 'whole wheat chapatti flour');
      expect(aataa.display, '2 cups aataa, whole wheat chapatti flour');
    });

    test('step photos', () {
      final r = load(2072);
      final withImage = r.instructionGroups
          .expand((g) => g.steps)
          .where((s) => s.image != null);
      expect(withImage, isNotEmpty);
      expect(withImage.first.image!.heroUrl, startsWith('https://'));
    });

    test('decodes entities', () {
      final r = load(2310);
      final names =
          r.ingredientGroups.expand((g) => g.items).map((i) => i.display);
      expect(names, contains('Cilantro & lemon for garnish'));
    });

    test('recipe without photo or summary', () {
      final r = load(1931);
      expect(r.image, isNull);
      expect(r.imageUrl, isEmpty);
      expect(r.summary, isEmpty);
      expect(r.intro, isEmpty);
      expect(r.cookName, 'Sammy');
    });

    test('cook time 0 is not shown', () {
      final r = load(2623);
      expect(recipeTimes(r).map((t) => t.$1), ['Prep', 'Total']);
      expect(recipeTimes(r).any((t) => t.$2.startsWith('0')), isFalse);
    });

    test('missing cook name falls back to Sammy', () {
      final j = fixtureMap('recipe_3574.json');
      (j['recipe'] as Map)['author_name'] = '';
      expect(RecipeDetail.fromJson(j).cookName, 'Sammy');
      (j['recipe'] as Map)['author_name'] = 'Imran';
      expect(RecipeDetail.fromJson(j).cookName, 'Imran');
    });

    test('round trips through the cache shape', () {
      for (final id in [3574, 2640, 2072, 2310, 1931, 2623, 1127]) {
        final r = load(id);
        final back = RecipeDetail.fromJson(r.toJson());
        expect(back.title, r.title);
        expect(back.cookName, r.cookName);
        expect(back.summary, r.summary);
        expect(back.notes, r.notes);
        expect(back.link, r.link);
        expect(back.imageUrl, r.imageUrl);
        expect(back.servingsLabel, r.servingsLabel);
        expect(back.cuisine, r.cuisine);
        expect(
            back.ingredientGroups.expand((g) => g.items).map((i) => i.display),
            r.ingredientGroups.expand((g) => g.items).map((i) => i.display));
        expect(back.instructionGroups.expand((g) => g.steps).map((s) => s.text),
            r.instructionGroups.expand((g) => g.steps).map((s) => s.text));
        expect(
            back.instructionGroups
                .expand((g) => g.steps)
                .map((s) => s.image?.heroUrl),
            r.instructionGroups
                .expand((g) => g.steps)
                .map((s) => s.image?.heroUrl));
      }
    });

    test('tolerates junk and missing fields', () {
      final r = RecipeDetail.fromJson({'id': 5, 'title': 'X', 'recipe': null});
      expect(r.id, '5');
      expect(r.hasIngredients, isFalse);
      expect(r.hasInstructions, isFalse);
      expect(r.cookName, 'Sammy');
      final c = Recipe.fromJson({
        'id': '7',
        'recipe_card': {'total_min': '12', 'servings': null, 'image': false}
      });
      expect(c.totalMin, 12);
      expect(c.servingsLabel, isNull);
      expect(c.image, isNull);
    });
  });

  test('categories decode entities and keep parents', () {
    final cats = fixtureList('categories.json').map(RecipeCategory.fromJson);
    expect(cats.every((c) => c.count > 0), isTrue);
    final soups = cats.firstWhere((c) => c.slug == 'soups');
    expect(soups.parent, 42);
    expect(cats.any((c) => c.name.contains('&amp;')), isFalse);
  });

  group('formatMinutes', () {
    test('never shows 0', () {
      expect(formatMinutes(0), isNull);
      expect(formatMinutes(-5), isNull);
      expect(formatMinutesShort(0), isNull);
    });
    test('formats', () {
      expect(formatMinutes(45), '45 min');
      expect(formatMinutes(60), '1 hr');
      expect(formatMinutes(65), '1 hr 5 min');
      expect(formatMinutesShort(65), '1h 5m');
      expect(formatMinutesShort(30), '30m');
    });
  });

  group('deep links', () {
    test('slug from category based permalinks', () {
      expect(
          recipeSlugFromLink(Uri.parse(
              'https://sliceofgourmet.com/main-course/chapli-kabab/')),
          'chapli-kabab');
      expect(
          recipeSlugFromLink(Uri.parse(
              'https://www.sliceofgourmet.com/side-dish/soups/paya-instant-pot-recipe/print/')),
          'paya-instant-pot-recipe');
      expect(
          recipeSlugFromLink(
              Uri.parse('https://sliceofgourmet.com/contact-me/')),
          isNull);
      expect(
          recipeSlugFromLink(
              Uri.parse('https://sliceofgourmet.com/category/dessert/')),
          isNull);
      expect(recipeSlugFromLink(Uri.parse('https://example.com/a/b/')), isNull);
    });

    test('router redirect', () {
      expect(deepLinkRedirect(Uri.parse('/')), isNull);
      expect(deepLinkRedirect(Uri.parse('/recipe/3574')), isNull);
      expect(deepLinkRedirect(Uri.parse('/category/48?name=Main')), isNull);
      expect(deepLinkRedirect(Uri.parse('/main-course/chapli-kabab/')),
          '/open?url=https%3A%2F%2Fsliceofgourmet.com%2Fmain-course%2Fchapli-kabab%2F');
      expect(deepLinkRedirect(Uri.parse('/faq/')), '/');
    });
  });
}
