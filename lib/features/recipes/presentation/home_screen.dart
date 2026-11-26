import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../recipes/providers.dart';
import '../../recipes/data/category.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/data_sync/sync_controller.dart';
import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/recipe_card.dart';
import '../../../core/widgets/skeletons.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/login_sheet.dart';
import 'search_delegate.dart';
import 'categories_screen.dart';
import 'bookmarks_screen.dart';
import 'settings_screen.dart';

/// Opens the sign-in sheet; [onOk] runs right away when already signed in.
Future<void> requireSignIn(
    BuildContext context, WidgetRef ref, VoidCallback onOk) async {
  if (ref.read(isSignedInProvider)) {
    onOk();
    return;
  }
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const LoginSheet(),
  );
}

/// Runs a rate limited refresh and tells the user how it went.
Future<void> refreshAndReport(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final out = await ref.read(syncControllerProvider.notifier).refresh();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(refreshMessage(out))));
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _index = 0;

  static const _pages = [
    _HomeTab(),
    CategoriesScreen(),
    BookmarksScreen(),
    SettingsScreen(),
  ];

  Future<void> _selectTab(int i) async {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    if (i != 0) {
      await requireSignIn(context, ref, () => setState(() => _index = i));
      return;
    }
    setState(() => _index = i);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(syncControllerProvider.notifier).autoSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // a cheap, throttled check when the app comes back
    if (state == AppLifecycleState.resumed) {
      ref.read(syncControllerProvider.notifier).autoSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    // after sign out, leave the auth-gated tabs
    ref.listen(authControllerProvider, (prev, next) {
      if (next == null && _index != 0) setState(() => _index = 0);
    });
    final still = reduceMotion(context);

    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: still ? 0 : 280),
        switchInCurve: kEase,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.015), end: Offset.zero)
                .animate(a),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(_index), child: _pages[_index]),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: _PillNav(index: _index, onChanged: _selectTab),
      ),
    );
  }
}

class _PillNav extends StatelessWidget {
  const _PillNav({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.grid_view_rounded, Icons.grid_view_outlined, 'Browse'),
    (Icons.favorite_rounded, Icons.favorite_border_rounded, 'Saved'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: dark ? Brand.darkCream : Brand.ink,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < _items.length; i++)
            _PillNavItem(
              selected: i == index,
              icon: i == index ? _items[i].$1 : _items[i].$2,
              label: _items[i].$3,
              color: cs.primary,
              onTap: () => onChanged(i),
            ),
        ],
      ),
    );
  }
}

class _PillNavItem extends StatelessWidget {
  const _PillNavItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final bool selected;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = Duration(milliseconds: reduceMotion(context) ? 0 : 260);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: d,
          curve: kEase,
          padding: EdgeInsets.symmetric(
              horizontal: selected ? 16 : 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 22,
                  color: selected ? Colors.white : Colors.white70),
              AnimatedSize(
                duration: d,
                curve: kEase,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _greeting(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    if (!sync.hasCatalog) return FirstRunView(state: sync);

    final user = ref.watch(authControllerProvider);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      color: cs.primary,
      onRefresh: () => refreshAndReport(context, ref),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user == null
                                ? _greeting(DateTime.now())
                                : '${_greeting(DateTime.now())}, ${user.firstName}',
                            style: text.labelLarge
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Text('What are we\ncooking today?',
                              style: text.headlineMedium),
                        ],
                      ),
                    ),
                    RefreshButton(syncing: sync.syncing),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _SearchPill()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
          const SliverToBoxAdapter(child: _CategoryChips()),
          const SliverToBoxAdapter(child: SizedBox(height: 22)),
          const _SectionTitle('Trending now'),
          const SliverToBoxAdapter(child: _TrendingCarousel()),
          const SliverToBoxAdapter(child: SizedBox(height: 26)),
          const _SectionTitle('Fresh from the kitchen'),
          const _LatestGrid(),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

/// Spins while a sync runs. Tapping it is rate limited.
class RefreshButton extends ConsumerStatefulWidget {
  const RefreshButton({super.key, required this.syncing});
  final bool syncing;

  @override
  ConsumerState<RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends ConsumerState<RefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(RefreshButton old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    if (widget.syncing && !reduceMotion(context)) {
      if (!_spin.isAnimating) _spin.repeat();
    } else if (_spin.isAnimating) {
      _spin.forward(from: _spin.value).then((_) => _spin.reset());
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      tooltip: 'Refresh recipes',
      onPressed: widget.syncing ? null : () => refreshAndReport(context, ref),
      icon: RotationTransition(
        turns: _spin,
        child: Icon(Icons.refresh_rounded, color: cs.primary),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      sliver: SliverToBoxAdapter(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Pressable(
      semanticLabel: 'Search recipes',
      onTap: () =>
          showSearch<String?>(context: context, delegate: RecipeSearchDelegate()),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(27),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(children: [
          Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Search recipes, ingredients, cuisines',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        ]),
      ),
    );
  }
}

IconData categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('dessert')) return Icons.icecream_outlined;
  if (n.contains('soup')) return Icons.ramen_dining_outlined;
  if (n.contains('salad')) return Icons.eco_outlined;
  if (n.contains('bread')) return Icons.bakery_dining_outlined;
  if (n.contains('brunch')) return Icons.brunch_dining_outlined;
  if (n.contains('breakfast')) return Icons.free_breakfast_outlined;
  if (n.contains('instant')) return Icons.soup_kitchen_outlined;
  if (n.contains('appetizer') || n.contains('snack')) {
    return Icons.tapas_outlined;
  }
  if (n.contains('condiment')) return Icons.local_dining_outlined;
  if (n.contains('tea')) return Icons.emoji_food_beverage_outlined;
  if (n.contains('lunch') || n.contains('dinner')) {
    return Icons.dinner_dining_outlined;
  }
  if (n.contains('side')) return Icons.rice_bowl_outlined;
  if (n.contains('diet') || n.contains('keto') || n.contains('gluten')) {
    return Icons.spa_outlined;
  }
  if (n.contains('main')) return Icons.restaurant_outlined;
  return Icons.restaurant_menu_rounded;
}

void openCategory(BuildContext context, RecipeCategory c) =>
    context.push('/category/${c.id}?name=${Uri.encodeComponent(c.name)}');

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider).valueOrNull;
    final cs = Theme.of(context).colorScheme;
    if (cats == null || cats.isEmpty) return const SizedBox(height: 44);
    final top = cats.take(8).toList();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: top.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == top.length) {
            return FadeSlideIn(
              index: i,
              child: ActionChip(
                avatar: Icon(Icons.arrow_forward_rounded,
                    size: 18, color: cs.primary),
                label: const Text('All'),
                onPressed: () => requireSignIn(
                    context, ref, () => context.push('/categories')),
              ),
            );
          }
          final c = top[i];
          return FadeSlideIn(
            index: i,
            child: Pressable(
              child: ActionChip(
                avatar: Icon(categoryIcon(c.name), size: 18, color: cs.primary),
                label: Text(c.name),
                onPressed: () =>
                    requireSignIn(context, ref, () => openCategory(context, c)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrendingCarousel extends ConsumerStatefulWidget {
  const _TrendingCarousel();

  @override
  ConsumerState<_TrendingCarousel> createState() => _TrendingCarouselState();
}

class _TrendingCarouselState extends ConsumerState<_TrendingCarousel> {
  final _controller = PageController(viewportFraction: 0.84);
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.hasClients) {
        setState(() => _page = _controller.page ?? 0);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(trendingRecipesProvider);
    final saved = ref.watch(bookmarksProvider);
    final still = reduceMotion(context);
    const height = 340.0;

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(height: height, child: ShimmerCardLarge()),
      ),
      error: (e, st) => const SizedBox(
          height: 80, child: MessageView(message: 'Could not load trending')),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(children: [
          SizedBox(
            height: height,
            child: PageView.builder(
              controller: _controller,
              padEnds: false,
              itemCount: items.length,
              itemBuilder: (context, i) {
                final r = items[i];
                final delta = (i - _page).abs().clamp(0.0, 1.0);
                final scale = still ? 1.0 : 1 - delta * 0.06;
                return Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 20 : 6, right: 6),
                  child: Transform.scale(
                    scale: scale,
                    child: FadeSlideIn(
                      index: i,
                      child: FeatureCard(
                        recipe: r,
                        heroScope: 'trending',
                        saved: saved.contains(r.id),
                        onToggleSave: () => ref
                            .read(bookmarkIdsNotifierProvider.notifier)
                            .toggle(r.id),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _Dots(count: items.length, page: _page),
        ]);
      },
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.page});
  final int count;
  final double page;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Builder(builder: (_) {
              final double t = 1 - math.min(1.0, (i - page).abs()).toDouble();
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: 6 + 14 * t,
                decoration: BoxDecoration(
                  color: Color.lerp(cs.outlineVariant, cs.primary, t),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _LatestGrid extends ConsumerWidget {
  const _LatestGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(latestRecipesProvider);
    final saved = ref.watch(bookmarksProvider);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: async.when(
        loading: () => const ShimmerRecipeGrid(count: 4),
        error: (e, st) => const SliverToBoxAdapter(
            child: MessageView(message: 'Could not load recipes')),
        data: (items) => items.isEmpty
            ? const SliverToBoxAdapter(
                child: MessageView(
                    message: 'No recipes yet. Pull down to check again.',
                    icon: Icons.menu_book_outlined))
            : RecipeSliverGrid(
          items: items,
          saved: saved,
          heroScope: 'latest',
          onToggleSave: (id) =>
              ref.read(bookmarkIdsNotifierProvider.notifier).toggle(id),
        ),
      ),
    );
  }
}

/// First launch: download the catalog with a progress bar, or explain
/// what went wrong.
class FirstRunView extends ConsumerWidget {
  const FirstRunView({super.key, required this.state});
  final SyncState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final failed = state.phase == SyncPhase.failed;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: failed
                ? Column(
                    key: const ValueKey('failed'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 56, color: cs.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text('You are offline', style: text.headlineSmall),
                      const SizedBox(height: 8),
                      const Text(
                        'Connect to the internet once to download the recipes. '
                        'After that they work offline.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => ref
                            .read(syncControllerProvider.notifier)
                            .retryFirstRun(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('loading'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            shape: BoxShape.circle),
                        child: Icon(Icons.restaurant_menu_rounded,
                            size: 40, color: cs.primary),
                      ),
                      const SizedBox(height: 20),
                      Text('Setting the table', style: text.headlineSmall),
                      const SizedBox(height: 8),
                      Text(
                        state.total > 0
                            ? 'Getting recipes ready: ${state.done} of ${state.total}'
                            : 'Getting recipes ready',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 220,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: state.progress ?? 0),
                            duration: const Duration(milliseconds: 400),
                            builder: (_, v, __) => LinearProgressIndicator(
                                minHeight: 6,
                                value: state.progress == null ? null : v),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
