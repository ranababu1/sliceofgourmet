import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data_sync/hydrator.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastHydrated = ref.watch(lastHydratedProvider);

    return ListView(
      children: [
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About'),
          subtitle: const Text('Slice Of Gourmet mobile app'),
          onTap: () {},
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.sync_rounded),
          title: const Text('Manual refresh'),
          subtitle: Text(
            lastHydrated == null
                ? 'Never synced'
                : 'Last synced: ${lastHydrated.toLocal()}',
          ),
          onTap: () async {
            final ok = await ref.read(hydratorProvider).hydrate();
            if (ok) {
              ref.read(lastHydratedProvider.notifier).state = DateTime.now();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Refreshed successfully')),
                );
              }
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Refresh failed, cached data kept'),
                  ),
                );
              }
            }
          },
        ),
      ],
    );
  }
}
