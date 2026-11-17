import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/recipe.dart';
import '../data/wordpress_api.dart' show RecipeNotFoundException;
import '../providers.dart';
import '../../../core/widgets/network_image.dart';
import '../../../core/widgets/state_views.dart';

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

class RecipeDetailScreen extends ConsumerWidget {
  final String recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recipeByIdProvider(recipeId));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Recipe')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        appBar: AppBar(title: const Text('Recipe')),
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
      data: (recipe) => _RecipeDetailBody(recipe: recipe),
    );
  }
}

class _RecipeDetailBody extends ConsumerWidget {
  const _RecipeDetailBody({required this.recipe});
  final RecipeDetail recipe;

  static const _hand = TextStyle(fontFamily: 'Caveat', fontSize: 20);

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
  Widget build(BuildContext context, WidgetRef ref) {
    final isBookmarked = ref.watch(bookmarksProvider).contains(recipe.id);
    final text = Theme.of(context).textTheme;
    final times = recipeTimes(recipe);
    final heroUrl = recipe.image?.heroUrl ?? '';

    final chips = <Widget>[
      if (recipe.category != null)
        Chip(
          label: Text(recipe.category!),
          avatar: const Icon(Icons.category, size: 18),
        ),
      if (formatMinutes(recipe.displayMinutes) case final t?)
        Chip(
          label: Text(t),
          avatar: const Icon(Icons.timer_outlined, size: 18),
        ),
      if (recipe.servingsLabel case final s?)
        Chip(
          label: Text(s),
          avatar: const Icon(Icons.people_outline, size: 18),
        ),
      if (recipe.difficultyLabel case final d?)
        Chip(
          label: Text(d),
          avatar: const Icon(Icons.signal_cellular_alt_rounded, size: 18),
        ),
      if (recipe.caloriesLabel case final c?)
        Chip(
          label: Text(c),
          avatar: const Icon(Icons.local_fire_department_outlined, size: 18),
        ),
      for (final c in [...recipe.cuisine, ...recipe.diet])
        Chip(label: Text(c), avatar: const Icon(Icons.public, size: 18)),
    ];

    var stepNo = 0;

    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: kToolbarHeight - 16,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(recipe.title, softWrap: false),
            ),
          ),
        ),
        actions: [
          if (recipe.link.isNotEmpty)
            Builder(
              builder: (context) => IconButton(
                onPressed: () => _share(context),
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share',
              ),
            ),
          IconButton(
            onPressed: () => ref
                .read(bookmarkIdsNotifierProvider.notifier)
                .toggle(recipe.id),
            icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_outline),
            tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await ref
                .read(recipeRepositoryProvider)
                .fetchById(recipe.id, forceRefresh: true);
            ref.invalidate(recipeByIdProvider(recipe.id));
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Could not refresh, showing saved copy')));
            }
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (heroUrl.isNotEmpty) ...[
              AppNetworkImage(
                url: heroUrl,
                height: 220,
                width: double.infinity,
                borderRadius: BorderRadius.circular(18),
              ),
              const SizedBox(height: 12),
            ],
            Text('By ${recipe.cookName}',
                style: text.titleMedium
                    ?.copyWith(fontFamily: 'Caveat', fontSize: 22)),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: chips),
            ],
            if (times.length > 1) ...[
              const SizedBox(height: 12),
              _TimesRow(times: times),
            ],
            if (recipe.intro.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                recipe.intro,
                style: text.bodyLarge
                    ?.copyWith(fontFamily: 'Caveat', fontSize: 20),
              ),
            ],
            const SizedBox(height: 16),
            Text('Ingredients',
                style: text.titleLarge
                    ?.copyWith(fontFamily: 'Caveat', fontSize: 26)),
            const SizedBox(height: 8),
            if (!recipe.hasIngredients)
              const Text('Ingredients not provided yet'),
            for (final g in recipe.ingredientGroups) ...[
              if (g.title.isNotEmpty) _GroupTitle(g.title),
              for (final i in g.items)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(i.display, style: _hand),
                ),
            ],
            const SizedBox(height: 16),
            Text('Instructions',
                style: text.titleLarge
                    ?.copyWith(fontFamily: 'Caveat', fontSize: 26)),
            const SizedBox(height: 8),
            if (!recipe.hasInstructions)
              const Text('Instructions not provided yet'),
            for (final g in recipe.instructionGroups) ...[
              if (g.title.isNotEmpty) _GroupTitle(g.title),
              for (final s in g.steps) ...[
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 12,
                    child: Text('${++stepNo}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                  title: Text(s.text, style: _hand),
                ),
                if (s.image != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 8),
                    child: AppNetworkImage(
                      url: s.image!.heroUrl,
                      height: 180,
                      width: double.infinity,
                    ),
                  ),
              ],
            ],
            if (recipe.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Notes',
                  style: text.titleLarge
                      ?.copyWith(fontFamily: 'Caveat', fontSize: 26)),
              const SizedBox(height: 8),
              Text(recipe.notes, style: _hand),
            ],
            if (recipe.link.isNotEmpty) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _openOnSite,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Read the full post'),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _TimesRow extends StatelessWidget {
  const _TimesRow({required this.times});
  final List<(String, String)> times;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (final t in times)
          Column(
            children: [
              Text(t.$1, style: text.labelMedium),
              const SizedBox(height: 2),
              Text(t.$2,
                  style:
                      text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
      ],
    );
  }
}
