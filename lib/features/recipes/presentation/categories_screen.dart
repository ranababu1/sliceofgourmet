import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recipes/providers.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/skeletons.dart';
import '../../../core/widgets/state_views.dart';
import 'home_screen.dart' show categoryIcon, openCategory;

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCats = ref.watch(categoriesProvider);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Browse'),
            automaticallyImplyLeading: canPop,
          ),
          asyncCats.when(
            loading: () => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: List.generate(6, (_) => const ShimmerBox()),
              ),
            ),
            error: (e, st) => SliverFillRemaining(
              child: MessageView(
                message: kOfflineMessage,
                icon: Icons.cloud_off_rounded,
                onRetry: () => ref.invalidate(categoriesProvider),
              ),
            ),
            data: (cats) => SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.45,
                ),
                itemCount: cats.length,
                itemBuilder: (_, i) {
                  final c = cats[i];
                  final tint =
                      i.isEven ? cs.primaryContainer : cs.surfaceContainer;
                  return FadeSlideIn(
                    index: i,
                    child: Pressable(
                      semanticLabel: '${c.name}, ${c.count} recipes',
                      onTap: () => openCategory(context, c),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: tint,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(categoryIcon(c.name),
                                color: cs.primary, size: 28),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700)),
                                Text(
                                    '${c.count} recipe${c.count == 1 ? '' : 's'}',
                                    style: text.labelMedium
                                        ?.copyWith(color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
