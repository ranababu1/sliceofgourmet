import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/recipes/presentation/home_screen.dart';
import '../features/recipes/presentation/recipe_detail_screen.dart';
import '../features/recipes/presentation/categories_screen.dart';
import '../features/recipes/presentation/category_recipes_screen.dart';

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
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
              return MaterialPage(child: RecipeDetailScreen(recipeId: id));
            },
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
              final id = int.parse(state.pathParameters['id']!);
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
    errorBuilder: (context, state) =>
        const Scaffold(body: Center(child: Text('Oops, something went wrong'))),
  );
}
