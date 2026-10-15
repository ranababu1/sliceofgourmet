import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../recipes/providers.dart';
import '../../../core/widgets/recipe_small_card.dart';
import '../../../core/widgets/state_views.dart';
import 'paged_recipes.dart';
import 'search_delegate.dart';

/// Paged "Latest Recipes" grid (not currently routed).
class RecipeListScreen extends ConsumerStatefulWidget {
  const RecipeListScreen({super.key});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  final _scrollController = ScrollController();
  late final PagedRecipes _paged;
  bool _forceNext = false;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(recipeRepositoryProvider);
    _paged = PagedRecipes((page, size) => repo.fetchLatest(
        page: page, pageSize: size, forceRefresh: _forceNext))
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _paged.loadMore();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
            _scrollController.position.maxScrollExtent - 300 &&
        _paged.error == null) {
      _paged.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _paged.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookmarks = ref.watch(bookmarksProvider);

    return RefreshIndicator(
      onRefresh: () async {
        _forceNext = true;
        await _paged.refresh();
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.medium(
            pinned: false,
            floating: true,
            title: const Text('Latest Recipes'),
            actions: [
              IconButton(
                onPressed: () => showSearch<String?>(
                    context: context, delegate: RecipeSearchDelegate()),
                icon: const Icon(Icons.search),
                tooltip: 'Search',
              ),
            ],
          ),
          if (_paged.items.isEmpty && _paged.error != null)
            SliverFillRemaining(
              child: MessageView(
                  message: kOfflineMessage,
                  icon: Icons.cloud_off_rounded,
                  onRetry: _paged.refresh),
            )
          else if (_paged.isEmpty)
            const SliverFillRemaining(
                child: MessageView(message: 'No recipes yet.'))
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: .78,
                ),
                itemCount: _paged.items.length,
                itemBuilder: (context, index) {
                  final r = _paged.items[index];
                  return Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: RecipeSmallCard(
                      recipe: r,
                      saved: bookmarks.contains(r.id),
                      onToggleSave: () => ref
                          .read(bookmarkIdsNotifierProvider.notifier)
                          .toggle(r.id),
                      height: 220,
                      width: double.infinity,
                    ),
                  );
                },
              ),
            ),
          if (_paged.loading)
            const SliverToBoxAdapter(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator())))
          else if (_paged.error != null && _paged.items.isNotEmpty)
            SliverToBoxAdapter(
                child: MessageView(
                    message: 'Could not load more recipes.',
                    onRetry: _paged.loadMore)),
        ],
      ),
    );
  }
}
