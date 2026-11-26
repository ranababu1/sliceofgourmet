import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/recipe.dart';
import '../data/wordpress_api.dart' show RecipeNotFoundException;
import '../providers.dart';
import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/recipe_card.dart';
import '../../../core/widgets/skeletons.dart';
import '../../../core/widgets/state_views.dart';
import 'home_screen.dart' show refreshAndReport;

/// Share text for a recipe: title plus its canonical permalink.
String recipeShareText(Recipe recipe) =>
    recipe.link.isEmpty ? recipe.title : '${recipe.title}\n${recipe.link}';

/// Non-empty time rows, e.g. [('Prep', '15 min'), ('Total', '1 hr 5 min')].
List<(String, String)> recipeTimes(RecipeDetail r) => [
      ('Prep', formatMinutes(r.prepMin)),
      ('Cook', formatMinutes(r.cookMin)),
      ('Rest', formatMinutes(r.restMin)),
      ('Total', formatMinutes(r.totalMin)),
    ].where((e) => e.$2 != null).map((e) => (e.$1, e.$2!)).toList();

/// The list card for [id] from the local catalog, used to show the photo
/// and title while the full recipe loads.
final _cardProvider = Provider.family<Recipe?, String>((ref, id) {
  final j = ref.read(localStoreProvider).readCard(id);
  return j == null ? null : Recipe.fromJson(j);
});

class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen(
      {super.key, required this.recipeId, this.heroScope = 'none'});
  final String recipeId;
  final String heroScope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recipeByIdProvider(recipeId));
    return async.when(
      loading: () => _LoadingDetail(
          card: ref.watch(_cardProvider(recipeId)), heroScope: heroScope),
      error: (e, st) => Scaffold(
        appBar: AppBar(),
        body: e is RecipeNotFoundException
            ? const MessageView(
                message: 'This recipe is no longer available.',
                icon: Icons.search_off_rounded,
              )
            : MessageView(
                message: kOfflineMessage,
                icon: Icons.cloud_off_rounded,
                onRetry: () => ref.invalidate(recipeByIdProvider(recipeId)),
              ),
      ),
      data: (recipe) => _RecipeDetailBody(recipe: recipe, heroScope: heroScope),
    );
  }
}

const _headerHeight = 380.0;

class _LoadingDetail extends StatelessWidget {
  const _LoadingDetail({required this.card, required this.heroScope});
  final Recipe? card;
  final String heroScope;

  @override
  Widget build(BuildContext context) {
    final c = card;
    return Scaffold(
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: c?.image != null ? _headerHeight : null,
            pinned: true,
            flexibleSpace: c?.image == null
                ? null
                : FlexibleSpaceBar(
                    background: Hero(
                      tag: recipeHeroTag(c!.id, heroScope),
                      child: RecipePhoto(recipe: c),
                    ),
                  ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList.list(children: [
              if (c != null)
                Text(c.title,
                    style: Theme.of(context).textTheme.headlineMedium)
              else
                const ShimmerBox(height: 28, width: 240),
              const SizedBox(height: 16),
              const ShimmerBox(height: 70, width: double.infinity),
              const SizedBox(height: 16),
              for (var i = 0; i < 5; i++) ...[
                const ShimmerBox(height: 16, width: double.infinity),
                const SizedBox(height: 10),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _RecipeDetailBody extends ConsumerStatefulWidget {
  const _RecipeDetailBody({required this.recipe, required this.heroScope});
  final RecipeDetail recipe;
  final String heroScope;

  @override
  ConsumerState<_RecipeDetailBody> createState() => _RecipeDetailBodyState();
}

class _RecipeDetailBodyState extends ConsumerState<_RecipeDetailBody> {
  final _checked = <String>{};

  RecipeDetail get recipe => widget.recipe;

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: recipeShareText(recipe),
      subject: recipe.title,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  Future<void> _openOnSite() async {
    final uri = Uri.tryParse(recipe.link);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(bookmarksProvider).contains(recipe.id);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final times = recipeTimes(recipe);
    final hasPhoto = recipe.image != null;

    final stats = <(IconData, String, String)>[
      if (times.length <= 1)
        if (formatMinutes(recipe.displayMinutes) case final t?)
          (Icons.schedule_rounded, 'Time', t),
      if (recipe.servingsLabel case final s?) (Icons.people_alt_outlined, 'Serves', s),
      if (recipe.difficultyLabel case final d?)
        (Icons.signal_cellular_alt_rounded, 'Level', d),
      if (recipe.caloriesLabel case final c?)
        (Icons.local_fire_department_outlined, 'Energy', c),
    ];
    final tags = [
      if (recipe.category != null) recipe.category!,
      ...recipe.cuisine,
      ...recipe.diet,
    ];

    var stepNo = 0;
    var section = 0;
    Widget reveal(Widget child) => FadeSlideIn(index: section++, child: child);

    final actions = [
      if (recipe.link.isNotEmpty)
        Builder(
          builder: (context) => _CircleAction(
            hasPhoto: hasPhoto,
            child: IconButton(
              onPressed: () => _share(context),
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: 'Share',
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(right: 12, left: 4),
        child: HeartButton(
          saved: saved,
          filledBackground: hasPhoto,
          onPressed: () {
            HapticFeedback.lightImpact();
            ref.read(bookmarkIdsNotifierProvider.notifier).toggle(recipe.id);
          },
        ),
      ),
    ];

    return Scaffold(
      body: RefreshIndicator(
        edgeOffset: hasPhoto ? _headerHeight * 0.4 : 0,
        onRefresh: () async {
          await refreshAndReport(context, ref);
          ref.invalidate(recipeByIdProvider(recipe.id));
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: hasPhoto ? _headerHeight : null,
              leading: _CircleAction(
                  hasPhoto: hasPhoto, child: const BackButton()),
              actions: actions,
              title: hasPhoto ? null : Text(recipe.title, maxLines: 1),
              flexibleSpace: hasPhoto
                  ? FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      stretchModes: const [StretchMode.zoomBackground],
                      background: Stack(fit: StackFit.expand, children: [
                        Hero(
                          tag: recipeHeroTag(recipe.id, widget.heroScope),
                          child: RecipePhoto(recipe: recipe),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0, 0.3, 0.75, 1],
                              colors: [
                                Color(0x66000000),
                                Colors.transparent,
                                Colors.transparent,
                                Color(0x33000000),
                              ],
                            ),
                          ),
                        ),
                        // rounded lip the content appears to slide out of
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: -1,
                          height: 28,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(28)),
                            ),
                          ),
                        ),
                      ]),
                    )
                  : null,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, hasPhoto ? 4 : 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    reveal(Text(recipe.title, style: text.headlineMedium)),
                    const SizedBox(height: 6),
                    reveal(Text('By ${recipe.cookName}',
                        style: TextStyle(
                            fontFamily: 'Caveat',
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: cs.primary))),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      reveal(Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final t in tags)
                          Chip(
                            label: Text(t),
                            visualDensity: VisualDensity.compact,
                          ),
                      ])),
                    ],
                    if (stats.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      reveal(_StatsRow(stats: stats)),
                    ],
                    if (times.length > 1) ...[
                      const SizedBox(height: 14),
                      reveal(_TimesRow(times: times)),
                    ],
                    if (recipe.intro.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      reveal(Text(recipe.intro,
                          style: text.bodyLarge?.copyWith(height: 1.55))),
                    ],
                    const SizedBox(height: 26),
                    _SectionHeading(
                        'Ingredients',
                        recipe.ingredientCount > 0
                            ? '${recipe.ingredientCount} items'
                            : null),
                    const SizedBox(height: 8),
                    if (!recipe.hasIngredients)
                      const Text('Ingredients not provided yet'),
                    for (final g in recipe.ingredientGroups) ...[
                      if (g.title.isNotEmpty) _GroupTitle(g.title),
                      for (final i in g.items)
                        _IngredientTile(
                          text: i.display,
                          checked: _checked.contains('${g.title}|${i.display}'),
                          onTap: () => setState(() {
                            final k = '${g.title}|${i.display}';
                            _checked.contains(k)
                                ? _checked.remove(k)
                                : _checked.add(k);
                          }),
                        ),
                    ],
                    const SizedBox(height: 26),
                    const _SectionHeading('Instructions', null),
                    const SizedBox(height: 8),
                    if (!recipe.hasInstructions)
                      const Text('Instructions not provided yet'),
                    for (final g in recipe.instructionGroups) ...[
                      if (g.title.isNotEmpty) _GroupTitle(g.title),
                      for (final s in g.steps)
                        _StepTile(number: ++stepNo, step: s),
                    ],
                    if (recipe.notes.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.lightbulb_outline_rounded,
                                  color: cs.primary, size: 20),
                              const SizedBox(width: 8),
                              Text('Notes', style: text.titleMedium),
                            ]),
                            const SizedBox(height: 8),
                            Text(recipe.notes,
                                style: text.bodyMedium?.copyWith(height: 1.5)),
                          ],
                        ),
                      ),
                    ],
                    if (recipe.link.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: _openOnSite,
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Read the full post'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White disc behind app bar buttons while they sit on the photo.
class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.hasPhoto, required this.child});
  final bool hasPhoto;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!hasPhoto) return child;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
        ),
        child: IconTheme(
            data: const IconThemeData(color: Brand.ink), child: child),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title, this.trailing);
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: Text(title, style: text.headlineSmall)),
        if (trailing != null)
          Text(trailing!,
              style: text.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary)),
      );
}

class _IngredientTile extends StatelessWidget {
  const _IngredientTile(
      {required this.text, required this.checked, required this.onTap});
  final String text;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = Duration(milliseconds: reduceMotion(context) ? 0 : 200);
    return Semantics(
      checked: checked,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: d,
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: checked ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: checked ? cs.primary : cs.outline, width: 1.6),
                ),
                child: checked
                    ? Icon(Icons.check_rounded, size: 16, color: cs.onPrimary)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: d,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        height: 1.35,
                        color: checked ? cs.onSurfaceVariant : cs.onSurface,
                        decoration: checked
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                  child: Text(text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.number, required this.step});
  final int number;
  final InstructionStep step;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration:
                BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
            child: Text('$number',
                style: TextStyle(
                    color: cs.primary, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (step.text.isNotEmpty)
                  Text(step.text,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(height: 1.5)),
                if (step.image != null) ...[
                  const SizedBox(height: 10),
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: LayoutBuilder(builder: (context, c) {
                        final dpr = MediaQuery.devicePixelRatioOf(context);
                        return Image(
                          image: CachedNetworkImageProvider(
                              step.image!.urlFor(c.maxWidth * dpr)),
                          fit: BoxFit.cover,
                        );
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final List<(IconData, String, String)> stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          for (final s in stats)
            Expanded(
              child: Column(children: [
                Icon(s.$1, color: cs.primary, size: 22),
                const SizedBox(height: 6),
                Text(s.$3,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(s.$2,
                    style: text.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _TimesRow extends StatelessWidget {
  const _TimesRow({required this.times});
  final List<(String, String)> times;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (final t in times)
          Column(
            children: [
              Text(t.$1,
                  style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(t.$2,
                  style:
                      text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
      ],
    );
  }
}
