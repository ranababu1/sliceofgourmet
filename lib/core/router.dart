import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/recipes/data/wordpress_repository.dart'
    show recipeSlugFromLink;
import '../features/recipes/presentation/home_screen.dart';
import '../features/recipes/presentation/recipe_detail_screen.dart';
import '../features/recipes/presentation/categories_screen.dart';
import '../features/recipes/presentation/category_recipes_screen.dart';
import '../features/recipes/presentation/open_link_screen.dart';

const _appPaths = ['/recipe/', '/categories', '/category/', '/open'];

/// Maps incoming site links (`https://sliceofgourmet.com/<category>/<slug>/`)
/// to the in-app resolver; unknown paths go home.
String? deepLinkRedirect(Uri uri) {
  final path = uri.path;
  if (path.isEmpty || path == '/') return null;
  if (_appPaths.any(path.startsWith)) return null;
  if (recipeSlugFromLink(uri) != null) {
    final link = Uri.https('sliceofgourmet.com', path);
    return Uri(path: '/open', queryParameters: {'url': '$link'}).toString();
  }
  return '/';
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) => deepLinkRedirect(state.uri),
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: HomeScreen()),
        routes: [
          GoRoute(
            path: 'recipe/:id',
            name: 'recipeDetail',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return MaterialPage(
                child: RecipeDetailScreen(
                  recipeId: id,
                  heroScope: state.uri.queryParameters['h'] ?? 'none',
                ),
              );
            },
          ),
          GoRoute(
            path: 'open',
            name: 'openLink',
            pageBuilder: (context, state) => MaterialPage(
              child:
                  OpenLinkScreen(url: state.uri.queryParameters['url'] ?? ''),
            ),
          ),
          GoRoute(
            path: 'categories',
            name: 'categories',
            pageBuilder: (context, state) =>
                const MaterialPage(child: CategoriesScreen()),
          ),
          GoRoute(
            path: 'category/:id',
            name: 'category',
            pageBuilder: (context, state) {
              final id = int.tryParse(state.pathParameters['id']!) ?? 0;
              final name = state.uri.queryParameters['name'];
              return MaterialPage(
                child: CategoryRecipesScreen(
                  categoryId: id,
                  categoryName: name,
                ),
              );
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
        body: Center(child: Text('Something went wrong. Please go back.'))),
  );
}
