import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../recipes/providers.dart';
import '../../recipes/data/recipe.dart';
import '../../../core/widgets/network_image.dart';
import 'search_delegate.dart';
import 'categories_screen.dart';
import 'bookmarks_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;
  final _controller = PageController(viewportFraction: 0.85);

  final _pages = const [
    _HomeTab(),
    CategoriesScreen(),
    BookmarksScreen(),
    SettingsScreen(),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // custom floating pill nav to match the reference UI
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // active page
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _pages[_index],
          ),

          // floating nav
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: _BottomPillNav(
                index: _index,
                onChanged: (i) => setState(() => _index = i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomPillNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _BottomPillNav({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavIcon(
            selected: index == 0,
            icon: Icons.home_rounded,
            onTap: () => onChanged(0),
          ),
          _NavIcon(
            selected: index == 1,
            icon: Icons.grid_view_rounded,
            onTap: () => onChanged(1),
          ),
          _NavIcon(
            selected: index == 2,
            icon: Icons.favorite_rounded,
            onTap: () => onChanged(2),
          ),
          _NavIcon(
            selected: index == 3,
            icon: Icons.settings_rounded,
            onTap: () => onChanged(3),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  const _NavIcon({
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withOpacity(0.15) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 22,
          color: selected ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Actual "Home" tab content, built to mirror the screenshot
class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // top bar with avatar and bell
          Row(
            children: [
              const _Avatar(),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '{user_name}',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () {},
                tooltip: 'Notifications',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // big greeting
          Text(
            "What do you want to cook today?",
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0E3B2E),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // search field that opens our delegate
          GestureDetector(
            onTap: () async {
              await showSearch<String?>(
                context: context,
                delegate: RecipeSearchDelegate(ref),
              );
            },
            child: AbsorbPointer(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search here',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // category grid
          _CategoryGrid(),
          const SizedBox(height: 18),

          // trending header
          Text(
            'Trending Recipe',
            style: text.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0E3B2E),
            ),
          ),
          const SizedBox(height: 12),

          // trending carousel using first page of latest recipes
          _TrendingCarousel(),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.primary.withOpacity(0.15);
    return CircleAvatar(
      radius: 18,
      backgroundColor: bg,
      child: const Text('S', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _CategoryGrid extends ConsumerWidget {
  const _CategoryGrid();

  final List<_Cat> cats = const [
    _Cat('Breakfast', Icons.free_breakfast_outlined),
    _Cat('Lunch', Icons.lunch_dining_rounded),
    _Cat('Dinner', Icons.dinner_dining_rounded),
    _Cat('Snack', Icons.emoji_food_beverage_outlined),
    _Cat('Cuisine', Icons.restaurant_menu_rounded),
    _Cat('Smoothies', Icons.blender_outlined),
    _Cat('Dessert', Icons.icecream_outlined),
    _Cat('More', Icons.grid_view_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final tileW = (width - 3 * 10) / 4;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cats.map((e) {
            return SizedBox(
              width: tileW,
              child: Material(
                color: e.title == 'More'
                    ? cs.primary.withOpacity(0.15)
                    : cs.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () {
                    if (e.title == 'More') {
                      // open Categories tab
                      final scaffold = context
                          .findAncestorStateOfType<_HomeScreenState>();
                      scaffold?.setState(() => scaffold._index = 1);
                      return;
                    }
                    // push into filtered list later, for now go to full list
                    context.pushNamed('home'); // keeps us in app, no-op for now
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(e.icon, color: const Color(0xFF2F855A)),
                        const SizedBox(height: 8),
                        Text(
                          e.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _Cat {
  final String title;
  final IconData icon;
  const _Cat(this.title, this.icon);
}

class _TrendingCarousel extends ConsumerWidget {
  const _TrendingCarousel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final page = ref.watch(latestRecipesProvider(1));
    final bookmarks = ref.watch(bookmarksProvider);

    return page.when(
      loading: () => const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => const SizedBox(
        height: 60,
        child: Center(child: Text('Could not load trending')),
      ),
      data: (items) {
        return SizedBox(
          height: 260,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.85),
            itemCount: items.length.clamp(0, 10),
            itemBuilder: (context, index) {
              final r = items[index];
              final saved = bookmarks.contains(r.id);
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _TrendingCard(
                  recipe: r,
                  saved: saved,
                  onToggleSave: () => ref
                      .read(bookmarkIdsNotifierProvider.notifier)
                      .toggle(r.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final Recipe recipe;
  final bool saved;
  final VoidCallback onToggleSave;

  const _TrendingCard({
    required this.recipe,
    required this.saved,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => context.push('/recipe/${recipe.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // image
            Positioned.fill(
              child: AppNetworkImage(url: recipe.imageUrl, fit: BoxFit.cover),
            ),
            // gradient overlay bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 40, 14, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.25),
                      Colors.black.withOpacity(0.55),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.cookTimeMinutes}m',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // heart button
            Positioned(
              top: 12,
              right: 12,
              child: InkWell(
                onTap: onToggleSave,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.surface.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    saved
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: saved ? cs.primary : cs.onSurface,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
