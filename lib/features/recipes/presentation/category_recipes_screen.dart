import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../recipes/providers.dart';
import '../../recipes/data/recipe.dart';
import '../../../core/widgets/recipe_small_card.dart';

class CategoryRecipesScreen extends ConsumerStatefulWidget {
  final int categoryId;
  final String? categoryName;
  const CategoryRecipesScreen({
    super.key,
    required this.categoryId,
    this.categoryName,
  });

  @override
  ConsumerState<CategoryRecipesScreen> createState() =>
      _CategoryRecipesScreenState();
}

class _CategoryRecipesScreenState extends ConsumerState<CategoryRecipesScreen> {
  final _scroll = ScrollController();
  int _page = 1;
  bool _loadingMore = false;
  bool _endReached = false;
  final List<Recipe> _items = <Recipe>[];

  @override
  void initState() {
    super.initState();
    _loadPage();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300 &&
        !_loadingMore &&
        !_endReached) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    setState(() => _loadingMore = true);
    final repo = ref.read(recipeRepositoryProvider);
    final page = await repo.fetchByCategory(
      widget.categoryId,
      page: _page,
      pageSize: 20,
    );
    if (!mounted) return;
    setState(() {
      _items.addAll(page);
      _loadingMore = false;
      if (page.isEmpty) _endReached = true;
      _page += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookmarks = ref.watch(bookmarksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName ?? 'Category')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _page = 1;
            _endReached = false;
            _items.clear();
          });
          await _loadPage();
        },
        child: GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: .78,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _items.length + (_loadingMore ? 2 : 0),
          itemBuilder: (context, index) {
            if (index >= _items.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final r = _items[index];
            final saved = bookmarks.contains(r.id);
            return RecipeSmallCard(
              recipe: r,
              saved: saved,
              onToggleSave: () =>
                  ref.read(bookmarkIdsNotifierProvider.notifier).toggle(r.id),
              height: 220,
              width: double.infinity,
            );
          },
        ),
      ),
    );
  }
}
