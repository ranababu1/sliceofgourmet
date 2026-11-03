import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../recipes/providers.dart';
import '../../../core/widgets/recipe_small_card.dart';
import '../../../core/widgets/state_views.dart';
import 'paged_recipes.dart';

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
  late final PagedRecipes _paged;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(recipeRepositoryProvider);
    _paged = PagedRecipes((page, size) =>
        repo.fetchByCategory(widget.categoryId, page: page, pageSize: size))
      ..addListener(_onChanged);
    _paged.loadMore();
    _scroll.addListener(_onScroll);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300 &&
        _paged.error == null) {
      _paged.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _paged.dispose();
    super.dispose();
  }

  Widget _body() {
    final bookmarks = ref.watch(bookmarksProvider);
    if (_paged.isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_paged.items.isEmpty && _paged.error != null) {
      return ListView(children: [
        const SizedBox(height: 120),
        MessageView(
            message: kOfflineMessage,
            icon: Icons.cloud_off_rounded,
            onRetry: _paged.refresh),
      ]);
    }
    if (_paged.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 120),
        MessageView(
            message: 'No recipes in this category yet.',
            icon: Icons.restaurant_menu_rounded),
      ]);
    }
    final footer = _paged.loading || _paged.error != null;
    return CustomScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: .78,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _paged.items.length,
            itemBuilder: (context, index) {
              final r = _paged.items[index];
              return RecipeSmallCard(
                recipe: r,
                saved: bookmarks.contains(r.id),
                onToggleSave: () =>
                    ref.read(bookmarkIdsNotifierProvider.notifier).toggle(r.id),
                height: 220,
                width: double.infinity,
              );
            },
          ),
        ),
        if (footer)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _paged.loading
                  ? const Center(child: CircularProgressIndicator())
                  : MessageView(
                      message: 'Could not load more recipes.',
                      onRetry: _paged.loadMore),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName ?? 'Category')),
      body: RefreshIndicator(onRefresh: _paged.refresh, child: _body()),
    );
  }
}
