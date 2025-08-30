import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../recipes/providers.dart';
import '../../../core/widgets/recipe_card.dart';
import 'search_delegate.dart';
import '../../recipes/data/recipe.dart';

class RecipeListScreen extends ConsumerStatefulWidget {
  const RecipeListScreen({super.key});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  final _scrollController = ScrollController();
  int _page = 1;
  final List<Recipe> recipes = <Recipe>[];
  bool _loadingMore = false;
  bool _endReached = false;

  @override
  void initState() {
    super.initState();
    _loadPage();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
            _scrollController.position.maxScrollExtent - 300 &&
        !_loadingMore &&
        !_endReached) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    setState(() {
      _loadingMore = true;
    });
    final result = await ref.read(latestRecipesProvider(_page).future);
    if (!mounted) return;
    setState(() {
      recipes.addAll(result);
      _loadingMore = false;
      if (result.isEmpty) _endReached = true;
      _page += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookmarks = ref.watch(bookmarksProvider);
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          recipes.clear();
          _page = 1;
          _endReached = false;
        });
        await _loadPage();
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar.medium(
            pinned: false,
            floating: true,
            title: const Text('Latest Recipes'),
            actions: [
              IconButton(
                onPressed: () async {
                  await showSearch<String?>(
                    context: context,
                    delegate: RecipeSearchDelegate(ref),
                  );
                },
                icon: const Icon(Icons.search),
                tooltip: 'Search',
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: .72,
              ),
              itemCount: recipes.length + (_loadingMore ? 2 : 0),
              itemBuilder: (context, index) {
                if (index >= recipes.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final r = recipes[index];
                final isBookmarked = bookmarks.contains(r.id);
                return RecipeCard(
                  recipe: r,
                  isBookmarked: isBookmarked,
                  onBookmarkToggle: () => ref
                      .read(bookmarkIdsNotifierProvider.notifier)
                      .toggle(r.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
