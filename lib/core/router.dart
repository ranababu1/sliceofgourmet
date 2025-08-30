import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/recipes/presentation/home_screen.dart';
import '../features/recipes/presentation/recipe_detail_screen.dart';

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
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Oops, something went wrong'))),
  );
}
