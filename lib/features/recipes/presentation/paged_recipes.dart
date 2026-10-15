import 'package:flutter/foundation.dart';
import '../data/recipe.dart';

/// Pagination state machine shared by paged grids.
/// End of list is reached when a page comes back empty (WordPress returns
/// 400 rest_post_invalid_page_number past the last page, mapped to empty by
/// WordPressApi) or shorter than [pageSize].
class PagedRecipes extends ChangeNotifier {
  PagedRecipes(this.fetchPage, {this.pageSize = 20});

  final Future<List<Recipe>> Function(int page, int pageSize) fetchPage;
  final int pageSize;

  final List<Recipe> items = <Recipe>[];
  int _nextPage = 1;
  bool loading = false;
  bool endReached = false;
  Object? error;

  bool get isInitialLoad => items.isEmpty && loading;
  bool get isEmpty => items.isEmpty && endReached && error == null;

  Future<void> loadMore() async {
    if (loading || endReached) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await fetchPage(_nextPage, pageSize);
      items.addAll(page);
      _nextPage += 1;
      if (page.length < pageSize) endReached = true;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    items.clear();
    _nextPage = 1;
    endReached = false;
    error = null;
    loading = false;
    await loadMore();
  }
}
